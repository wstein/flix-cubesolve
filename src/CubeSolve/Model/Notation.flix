///
/// The move alphabet people actually write, and what it means to the model.
///
/// `CubeSolve.Model.Move` covers the eighteen face turns and nothing else,
/// because that is the alphabet a search works in. Humans write more than that:
/// slice moves `M`, `E`, `S`, whole-cube rotations `x`, `y`, `z`, and the wide
/// turns that WCA scrambles are stated in. This module is the boundary that
/// turns the second alphabet into the first.
///
/// Everything reduces to two kinds of step:
///
/// - a **layer turn**, which moves pieces, and
/// - a **frame rotation**, which moves no piece relative to any other and only
///   changes which physical face is currently called `U`.
///
/// A slice move is both. `M` turns the middle layer, which is the same as
/// turning the whole cube and then putting the outer two layers back:
///
/// ```
/// x = R M' L'      so      M = L' R  together with the frame rotation x'
/// ```
///
/// The layer turns in an expansion are named in the *current* frame and are
/// resolved through it when applied, which is why `y R y'` comes out as `B`
/// rather than as `R`.
///
mod CubeSolve.Model.Notation {

    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face
    use CubeSolve.Model.Move.Face.{U, R, F, D, L, B}
    use CubeSolve.Model.Move.Move.Turn
    use CubeSolve.Model.Rotation
    use CubeSolve.Model.Notation.Op.{Layer, Inner, Frame}

    ///
    /// One step of a written sequence, after expansion.
    ///
    pub enum Op with Eq, ToString {
        /// Turn one layer. The face is named in the frame current at this point.
        case Layer(Move.Move),
        /// Turn an inner layer `depth` in from the named face.
        case Inner(Move.Move, Int32),
        /// Rotate the whole cube. No piece moves relative to any other.
        case Frame(Rotation.Rotation)
    }

    ///
    /// The steps `s` names for an `n x n x n`, or why it names none.
    ///
    /// `n` is needed because a slice or wide turn does not mean the same thing
    /// at every size, and at some sizes means nothing at all: a 2x2x2 has no
    /// middle layer for `M` to turn.
    ///
    /// **Groups are grammar, not decoration.** Published algorithms are written
    /// with brackets, and a bracket sometimes carries a repeat count: `(M z)4`
    /// is four of `M z`, while `(R U R' U')` is one and the brackets only show
    /// where the fingers go. Stripping brackets would silently turn the first
    /// into the second, so they are parsed rather than removed. Groups nest, and
    /// take the same suffixes a move does.
    ///
    pub def parse(n: Int32, s: String): Result[String, List[Op]] =
        forM (
            lexemes <- lex(s);
            parsed <- sequence(n, lexemes, Nil);
            ops <- endsCleanly(parsed)
        ) yield ops

    ///
    /// A parsed sequence and whatever was left after it.
    ///
    type alias Parsed = { ops = List[Op], rest = List[Lexeme] }

    ///
    /// The result of a top-level parse, if nothing was left over.
    ///
    def endsCleanly(p: Parsed): Result[String, List[Op]] =
        if (List.isEmpty(p#rest))
            Ok(p#ops)
        else
            Err("unmatched ')': there is a closing bracket with no opening one")

    ///
    /// One written symbol.
    ///
    enum Lexeme with Eq, ToString {
        case Open
        case Close
        case Word(String)
        case Count(Int32)
        case Prime
    }

    ///
    /// `s` as symbols, or why it is not written in this notation.
    ///
    def lex(s: String): Result[String, List[Lexeme]] =
        lexFrom(String.toList(s), Nil)

    ///
    /// Symbols from a list of characters.
    ///
    def lexFrom(cs: List[Char], acc: List[Lexeme]): Result[String, List[Lexeme]] =
        match cs {
            case Nil       => Ok(List.reverse(acc))
            case c :: rest => lexOne(c, rest, cs, acc)
        }

    ///
    /// One character, which is either skipped, a symbol on its own, or the
    /// start of a run.
    ///
    def lexOne(
        c: Char,
        rest: List[Char],
        all: List[Char],
        acc: List[Lexeme]
    ): Result[String, List[Lexeme]] =
        if (Char.isWhitespace(c))
            lexFrom(rest, acc)
        else
            match onItsOwn(c) {
                case Some(l) => lexFrom(rest, l :: acc)
                case None    => lexRun(c, all, acc)
            }

    ///
    /// The symbols that are one character each.
    ///
    /// The curly apostrophe and prime characters are supported for pasting from editors.
    /// Square brackets are accepted for grouping.
    ///
    def onItsOwn(c: Char): Option[Lexeme] =
        if (c == '(' or c == '[') Some(Lexeme.Open)
        else if (c == ')' or c == ']') Some(Lexeme.Close)
        else if (c == '\'' or c == '\u2019' or c == '\u2018' or c == '\u2032') Some(Lexeme.Prime)
        else None

    ///
    /// A run of digits or of letters, or a character this notation has no use
    /// for.
    ///
    def lexRun(
        c: Char,
        all: List[Char],
        acc: List[Lexeme]
    ): Result[String, List[Lexeme]] =
        if (Char.isDigit(c))
            lexCount(all, acc)
        else if (Char.isLetter(c))
            lexWord(all, acc)
        else
            Err("'${c}' has no meaning in this notation")

    ///
    /// A run of letters as a move name.
    ///
    def lexWord(all: List[Char], acc: List[Lexeme]): Result[String, List[Lexeme]] =
        let (word, after) = spanOf(Char.isLetter, all);
        lexFrom(after, Lexeme.Word(word) :: acc)

    ///
    /// A run of digits as a repeat count, or as a layer / range prefix for a move.
    ///
    def lexCount(all: List[Char], acc: List[Lexeme]): Result[String, List[Lexeme]] =
        let (digits, after) = spanOf(Char.isDigit, all);
        match after {
            case '-' :: next :: _ if Char.isDigit(next) =>
                lexRange(digits, List.drop(1, after), acc)
            case next :: _ if Char.isLetter(next) =>
                lexPrefixedWord(digits, after, acc)
            case _ =>
                lexRepeatCount(digits, after, acc)
        }

    def lexRange(
        digits: String,
        afterHyphen: List[Char],
        acc: List[Lexeme]
    ): Result[String, List[Lexeme]] = {
        let (digits2, afterDigits2) = spanOf(Char.isDigit, afterHyphen);
        let (letters, afterWord) = spanOf(Char.isLetter, afterDigits2);
        let fullWord = digits + "-" + digits2 + letters;
        let token = Lexeme.Word(fullWord);
        lexFrom(afterWord, token :: acc)
    }

    def lexPrefixedWord(
        digits: String,
        after: List[Char],
        acc: List[Lexeme]
    ): Result[String, List[Lexeme]] = {
        let (letters, afterWord) = spanOf(Char.isLetter, after);
        let token = Lexeme.Word(digits + letters);
        lexFrom(afterWord, token :: acc)
    }

    def lexRepeatCount(
        digits: String,
        after: List[Char],
        acc: List[Lexeme]
    ): Result[String, List[Lexeme]] =
        match Int32.fromString(digits) {
            case Some(k) =>
                let token = Lexeme.Count(k);
                lexFrom(after, token :: acc)
            case None =>
                Err("'${digits}' is not a number this notation can use")
        }

    ///
    /// The longest prefix of `cs` satisfying `p`, as a string, and the rest.
    ///
    def spanOf(p: Char -> Bool, cs: List[Char]): (String, List[Char]) =
        let taken = List.takeWhile(p, cs);
        (taken |> List.map(Char.toString) |> List.join(""), List.dropWhile(p, cs))

    ///
    /// Items until a closing bracket or the end of the input.
    ///
    def sequence(n: Int32, lexemes: List[Lexeme], acc: List[Op]): Result[String, Parsed] =
        match lexemes {
            case Nil                  => Ok({ ops = List.reverse(acc), rest = Nil })
            case Lexeme.Close :: _    => Ok({ ops = List.reverse(acc), rest = lexemes })
            case _                    =>
                forM (
                    item <- item(n, lexemes);
                    done <- sequence(n, item#rest, List.append(List.reverse(item#ops), acc))
                ) yield done
        }

    ///
    /// One move or one bracketed group, with its suffix applied.
    ///
    def item(n: Int32, lexemes: List[Lexeme]): Result[String, Parsed] =
        match lexemes {
            case Lexeme.Word(w) :: rest =>
                forM (
                    base <- expand(n, w, w);
                    out <- suffixed(base, rest, w)
                ) yield out
            case Lexeme.Open :: rest    => group(n, rest)
            case Lexeme.Count(k) :: _   =>
                Err("'${k}' stands on its own: a repeat count has to follow a move "
                    + "or a bracketed group")
            case Lexeme.Prime :: _      =>
                Err("\"'\" stands on its own: an inverse has to follow a move or a "
                    + "bracketed group")
            case _                      => Err("nothing to read here")
        }

    ///
    /// A bracketed group: its contents, its closing bracket, and its suffix.
    ///
    def group(n: Int32, lexemes: List[Lexeme]): Result[String, Parsed] =
        forM (
            inner <- sequence(n, lexemes, Nil);
            closed <- closing(inner);
            out <- suffixed(inner#ops, closed, "( ... )")
        ) yield out

    ///
    /// What follows a group's closing bracket, or why there is none.
    ///
    def closing(inner: Parsed): Result[String, List[Lexeme]] =
        match inner#rest {
            case Lexeme.Close :: after =>
                if (List.isEmpty(inner#ops))
                    Err("'()' is empty: a group has to contain at least one move")
                else
                    Ok(after)
            case _ => Err("unmatched '(': there is an opening bracket with no closing one")
        }

    ///
    /// `ops` with any repeat count and inverse that follow applied.
    ///
    /// A count repeats and a prime inverts, and the two compose in either
    /// written order because inverting a repetition and repeating an inverse
    /// come to the same sequence.
    ///
    def suffixed(
        ops: List[Op],
        lexemes: List[Lexeme],
        what: String
    ): Result[String, Parsed] =
        forM (
            read <- readSuffix(lexemes, None, false, what)
        ) yield {
            ops = applySuffix(ops, read#count |> Option.getWithDefault(1), read#inverted),
            rest = read#rest
        }

    ///
    /// A suffix, which is at most one count and at most one prime.
    ///
    def readSuffix(
        lexemes: List[Lexeme],
        count: Option[Int32],
        inverted: Bool,
        what: String
    ): Result[String, { count = Option[Int32], inverted = Bool, rest = List[Lexeme] }] =
        match lexemes {
            case Lexeme.Count(k) :: rest =>
                if (Option.isEmpty(count))
                    if (k < 1)
                        Err("a repeat count has to be at least 1, and '${what}' has ${k}")
                    else if (k > repeatCeiling())
                        Err("a repeat count of ${k} on '${what}' is beyond the "
                            + "${repeatCeiling()} this notation will expand")
                    else
                        readSuffix(rest, Some(k), inverted, what)
                else
                    Err("'${what}' has two repeat counts, and one is the most a move "
                        + "or group can take")
            case Lexeme.Prime :: rest =>
                if (inverted)
                    Err("'${what}' is inverted twice, which says nothing the plain "
                        + "form does not")
                else
                    readSuffix(rest, count, true, what)
            case _ => Ok({ count = count, inverted = inverted, rest = lexemes })
        }

    ///
    /// The largest repetition this notation will write out.
    ///
    /// Published algorithms repeat a group a handful of times at most, so a
    /// larger number is a typo rather than an intention, and expanding it would
    /// spend memory on a mistake.
    ///
    def repeatCeiling(): Int32 = 64

    ///
    /// `ops` repeated `k` times, inverted if asked.
    ///
    def applySuffix(ops: List[Op], k: Int32, inverted: Bool): List[Op] =
        let repeated = List.flatten(List.repeat(k, ops));
        if (inverted) invert(repeated) else repeated

    ///
    /// The sequence that undoes `ops`.
    ///
    /// Reversed, with every step inverted. A frame rotation inverts to its own
    /// inverse and a layer turn to its opposite amount; a layer turn is named in
    /// whatever frame is current when it runs, and reversing the sequence
    /// restores that frame before the turn is undone, so the names still mean
    /// what they meant.
    ///
    def invert(ops: List[Op]): List[Op] =
        ops |> List.reverse |> List.map(op -> match op {
            case Layer(m) => Layer(Move.inverse(m))
            case Inner(m, d) => Inner(Move.inverse(m), d)
            case Frame(r) => Frame(Rotation.inverse(r))
        })

    ///
    /// Only the layer turns of `ops`, in order.
    ///
    /// Useful to a caller that wants the piece-moving part of a sequence, for
    /// instance to compare it with a solver's output. The frame rotations are
    /// dropped, so this is not equivalent to the original sequence unless the
    /// frame happens to end where it started.
    ///
    pub def layersOnly(ops: List[Op]): List[Move.Move] =
        ops |> List.filterMap(op -> match op {
            case Layer(m) => Some(m)
            case Inner(m, _) => Some(m)
            case Frame(_) => None
        })

    ///
    /// What one quarter turn of `base` does, as layer turns and a frame rotation.
    ///
    def expand(n: Int32, base: String, token: String): Result[String, List[Op]] =
        match expandLayerPrefix(n, base, token) {
            case Some(res) => res
            case None      => match layerOf(base) {
                case Some(f) => Ok(Layer(Turn(f, 1)) :: Nil)
                case None    => expandNonLayer(n, base, token)
            }
        }

    ///
    /// Parse numbered slice, range or wide moves like 2U, 2R, 2Rw, 2-4Fw, 3L.
    ///
    def expandLayerPrefix(
        n: Int32,
        base: String,
        token: String
    ): Option[Result[String, List[Op]]] = {
        if (String.contains(substr = "-", base))
            Some(expandRangeLayer(n, token, base))
        else {
            let (digitsStr, restChars) = spanOf(Char.isDigit, String.toList(base));
            if (digitsStr == "")
                None
            else {
                let rest = restChars |> List.map(Char.toString) |> List.join("");
                match Int32.fromString(digitsStr) {
                    case Some(layerNum) if layerNum >= 1 and layerNum < n =>
                        Some(expandNumberedLayer(n, token, layerNum, rest))
                    case Some(layerNum) =>
                        let msg = "'${token}' specifies layer ${layerNum}, "
                            + "which is out of range for a ${n}x${n}x${n}";
                        Some(Err(msg))
                    case None =>
                        Some(Err("'${token}' has an invalid layer number"))
                }
            }
        }
    }

    ///
    /// Expand a multi-layer range move like 2-4Fw into outer and inner slice operations.
    ///
    def expandRangeLayer(n: Int32, token: String, base: String): Result[String, List[Op]] = {
        let (firstDigits, afterHyphen) = spanOf(Char.isDigit, String.toList(base));
        let afterHyphenChars = List.drop(1, afterHyphen);
        let (secondDigits, letterChars) = spanOf(Char.isDigit, afterHyphenChars);
        let letters = letterChars |> List.map(Char.toString) |> List.join("");
        let baseFace = if (String.endsWith(suffix = "w", letters))
            String.dropRight(1, letters)
        else
            letters;
        let faceStr = String.toUpperCase(baseFace);
        let p1 = Int32.fromString(firstDigits);
        let p2 = Int32.fromString(secondDigits);
        let pf = layerOf(faceStr);
        match (p1, p2, pf) {
            case (Some(startL), Some(endL), Some(f))
                if startL >= 1 and endL < n and startL <= endL =>
                let ops = List.range(startL, endL + 1)
                    |> List.flatMap(l -> expandSingleLayer(n, f, l));
                Ok(ops)
            case _ => Err(unknownToken(token))
        }
    }

    ///
    /// Expand a valid layer number and face into outer and inner slice operations.
    ///
    def expandNumberedLayer(
        n: Int32,
        token: String,
        layerNum: Int32,
        rest: String
    ): Result[String, List[Op]] = {
        let isWide = String.endsWith(suffix = "w", rest);
        let faceStr = String.toUpperCase(if (isWide) String.dropRight(1, rest) else rest);
        match layerOf(faceStr) {
            case Some(f) if isWide =>
                let ops = List.range(1, layerNum + 1)
                    |> List.flatMap(l -> expandSingleLayer(n, f, l));
                Ok(ops)
            case Some(f) =>
                Ok(expandSingleLayer(n, f, layerNum))
            case None => Err(unknownToken(token))
        }
    }

    ///
    /// Expand a single 1-based layer index on a cube of size n into operations.
    ///
    def expandSingleLayer(n: Int32, f: Face, l: Int32): List[Op] = {
        let mid = (n + 1) / 2;
        if (l == 1)
            Layer(Turn(f, 1)) :: Nil
        else if (Int32.modulo(n, 2) == 1 and l == mid)
            oddSliceForFace(n, f)
        else if (l < mid or (Int32.modulo(n, 2) == 0 and l <= n / 2))
            Inner(Turn(f, 1), l - 1) :: Nil
        else
            Inner(Turn(Move.opposite(f), 3), n - l) :: Nil
    }

    ///
    /// Central slice operations for an odd cube along any face axis.
    ///
    def oddSliceForFace(n: Int32, f: Face): List[Op] = match f {
        case L => oddSliceOps(n, L, R, back(Rotation.x()))
        case R => oddSliceOps(n, R, L, Rotation.x())
        case D => oddSliceOps(n, D, U, back(Rotation.y()))
        case U => oddSliceOps(n, U, D, Rotation.y())
        case F => oddSliceOps(n, F, B, Rotation.z())
        case B => oddSliceOps(n, B, F, back(Rotation.z()))
    }

    ///
    /// Everything that is not a plain face turn.
    ///
    def expandNonLayer(n: Int32, base: String, token: String): Result[String, List[Op]] =
        match rotationOf(base) {
            case Some(r) => Ok(Frame(r) :: Nil)
            case None    => expandInner(n, base, token)
        }

    ///
    /// Slice and wide turns: the ones whose meaning depends on the size.
    ///
    def expandInner(n: Int32, base: String, token: String): Result[String, List[Op]] =
        match sliceOf(base) {
            case Some(ops) => middleLayer(n, token, ops)
            case None      => if (n == 3) expandWide(n, base, token) else match innerFaceOf(base) {
                case Some(f) => innerLayer(n, token, f)
                case None    => expandWide(n, base, token)
            }
        }

    ///
    /// Wide turns, or the refusal for a token that names nothing.
    ///
    def expandWide(n: Int32, base: String, token: String): Result[String, List[Op]] =
        match wideOf(base) {
            case Some((opposite, r)) => wide(n, token, opposite, r)
            case None                => Err(unknownToken(token))
        }

    ///
    /// What to say about a token this notation does not have.
    ///
    def unknownToken(token: String): String =
        "'${token}' does not name a move: expected a face (U R F D L B), a "
            + "slice (M E S), a rotation (x y z) or a wide turn "
            + "(r l u d f b, or Rw Lw Uw Dw Fw Bw)"

    ///
    /// The face a plain layer turn names.
    ///
    def layerOf(base: String): Option[Face] = match base {
        case "U" => Some(U)
        case "R" => Some(R)
        case "F" => Some(F)
        case "D" => Some(D)
        case "L" => Some(L)
        case "B" => Some(B)
        case _   => None
    }

    ///
    /// The whole-cube rotation a token names.
    ///
    def rotationOf(base: String): Option[Rotation.Rotation] = match base {
        case "x" => Some(Rotation.x())
        case "y" => Some(Rotation.y())
        case "z" => Some(Rotation.z())
        case _   => None
    }

    ///
    /// The slice move a token names, expanded for a 3x3x3.
    ///
    /// From `x = R M' L'`: turning the middle slice is the same as turning both
    /// outer layers the other way and rotating the whole cube. `E` and `S`
    /// follow from the same identity about their own axes.
    ///
    def sliceOf(base: String): Option[List[Op]] = match String.toUpperCase(base) {
        case "M" => Some(slice(L, R, back(Rotation.x())))
        case "E" => Some(slice(D, U, back(Rotation.y())))
        case "S" => Some(slice(F, B, Rotation.z()))
        case _   => None
    }

    ///
    /// A slice turn: the two outer layers the other way, and a frame rotation.
    ///
    def slice(a: Face, b: Face, r: Rotation.Rotation): List[Op] =
        Layer(Turn(a, 3)) :: Layer(Turn(b, 1)) :: Frame(r) :: Nil

    ///
    /// The face left behind by a wide turn, and the rotation that goes with it.
    ///
    /// Turning every layer but one is the same as turning the whole cube and
    /// putting that one layer back, so a wide turn is the *opposite* face's
    /// layer turn together with a rotation about that axis.
    ///
    def wideOf(base: String): Option[(Face, Rotation.Rotation)] = match plainSpelling(base) {
        case "r" => Some((L, Rotation.x()))
        case "l" => Some((R, back(Rotation.x())))
        case "u" => Some((D, Rotation.y()))
        case "d" => Some((U, back(Rotation.y())))
        case "f" => Some((B, Rotation.z()))
        case "b" => Some((F, back(Rotation.z())))
        case _   => None
    }

    ///
    /// `Rw` and `r` are the same move; this reduces the first spelling to the
    /// second so the table below is written once.
    ///
    def plainSpelling(base: String): String =
        if (String.endsWith(suffix = "w", base))
            String.toLowerCase(String.dropRight(1, base))
        else
            base

    ///
    /// The rotation that undoes `r`, named for brevity in the tables above.
    ///
    def back(r: Rotation.Rotation): Rotation.Rotation = Rotation.inverse(r)

    ///
    /// A move that needs inner layers to turn, which cubes of size 3 and larger have.
    ///
    /// The expansion is `L' R x'` (or the corresponding axis), which turns all
    /// inner slices while leaving the outer faces in place.
    ///
    def middleLayer(n: Int32, token: String, ops: List[Op]): Result[String, List[Op]] =
        if (n == 3) Ok(ops)
        else if (n > 3) Ok(middleSlices(n, baseOf(token)))
        else
            Err("'${token}' does not name a move on a 2x2x2: a cube with only two layers "
                + "has no inner slice to turn")

    ///
    /// A wide turn on a 3x3x3 is the whole cube less its opposite face. On a
    /// bigger cube it is the outer layer plus the adjacent inner one.
    ///
    /// On an n x n x n (n >= 3) a wide turn turns all layers except the opposite face.
    ///
    def wide(
        n: Int32,
        token: String,
        opposite: Face,
        r: Rotation.Rotation
    ): Result[String, List[Op]] =
        if (n == 3)
            Ok(Layer(Turn(opposite, 1)) :: Frame(r) :: Nil)
        else if (n > 3)
            let face = Move.opposite(opposite);
            Ok(Layer(Turn(face, 1)) :: Inner(Turn(face, 1), 1) :: Nil)
        else
            Err("'${token}' does not name a move on a 2x2x2: both of its layers are "
                + "outer layers, so a wide turn would be the whole cube -- write a "
                + "rotation instead")

    /// The face named by a lower-case inner-slice spelling on a big cube.
    def innerFaceOf(base: String): Option[Face] = match base {
        case "r" => Some(R)
        case "l" => Some(L)
        case "u" => Some(U)
        case "d" => Some(D)
        case "f" => Some(F)
        case "b" => Some(B)
        case _   => None
    }

    /// One inner slice immediately below the named outer face.
    def innerLayer(n: Int32, token: String, f: Face): Result[String, List[Op]] =
        if (n > 3) Ok(Inner(Turn(f, 1), 1) :: Nil)
        else Err("'${token}' does not name an inner slice on a ${n}x${n}x${n}")

    /// The M, E and S middle slice(s), following L, D and F respectively.
    def middleSlices(n: Int32, base: String): List[Op] =
        if (Int32.modulo(n, 2) == 1)
            oddMiddleSlice(n, base)
        else
            evenMiddleSlice(n, base)

    /// Odd cubes turn the center slice without displacing fixed center references in orbits.
    def oddMiddleSlice(n: Int32, base: String): List[Op] =
        match String.toUpperCase(base) {
            case "M" => oddSliceOps(n, L, R, back(Rotation.x()))
            case "E" => oddSliceOps(n, D, U, back(Rotation.y()))
            case "S" => oddSliceOps(n, F, B, Rotation.z())
            case _   => Nil
        }

    /// Operations for an odd-cube central slice move.
    def oddSliceOps(n: Int32, a: Face, b: Face, r: Rotation.Rotation): List[Op] = {
        let maxDepth = n / 2 - 1;
        let innersA = List.range(1, maxDepth + 1)
            |> List.map(d -> Inner(Turn(a, 3), d));
        let innersB = List.range(1, maxDepth + 1)
            |> List.map(d -> Inner(Turn(b, 1), d));
        let sideA = Layer(Turn(a, 3)) :: innersA;
        let sideB = Layer(Turn(b, 1)) :: innersB;
        List.append(sideA, List.append(sideB, Frame(r) :: Nil))
    }

    /// Even cubes turn the two middle slices symmetrically.
    def evenMiddleSlice(n: Int32, base: String): List[Op] =
        match sliceAxis(base) {
            case Some(f) =>
                let depth = n / 2 - 1;
                Inner(Turn(f, 1), depth) :: Inner(Turn(Move.opposite(f), 3), depth) :: Nil
            case None => Nil
        }

    /// Which outer face gives a middle-slice move its direction.
    def sliceAxis(base: String): Option[Face] = match String.toUpperCase(base) {
        case "M" => Some(L)
        case "E" => Some(D)
        case "S" => Some(F)
        case _   => None
    }

    /// The base word, before its count or inverse suffix is handled.
    def baseOf(token: String): String = token

}
