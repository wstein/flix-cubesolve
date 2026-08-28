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
    use CubeSolve.Model.Notation.Op.{Layer, Frame}

    ///
    /// One step of a written sequence, after expansion.
    ///
    pub enum Op with Eq, ToString {
        /// Turn one layer. The face is named in the frame current at this point.
        case Layer(Move.Move),
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
    pub def parse(n: Int32, s: String): Result[String, List[Op]] =
        String.words(s)
            |> Result.traverse(t -> parseToken(n, t))
            |> Result.map(List.flatten)

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
            case Frame(_) => None
        })

    ///
    /// The steps one written token expands to.
    ///
    def parseToken(n: Int32, token: String): Result[String, List[Op]] =
        let (base, k) = splitAmount(token);
        if (k == 0)
            Err("'${token}' does not name a move: a move is a name, optionally "
                + "followed by '2' or \"'\"")
        else
            match expand(n, base, token) {
                case Err(why)   => Err(why)
                case Ok(oneTurn) => Ok(List.flatten(List.repeat(k, oneTurn)))
            }

    ///
    /// The name and the number of quarter turns `token` asks for, or `0` when
    /// the suffix is not one this notation has.
    ///
    def splitAmount(token: String): (String, Int32) =
        if (String.endsWith(suffix = "2", token)) (String.dropRight(1, token), 2)
        else if (String.endsWith(suffix = "'", token)) (String.dropRight(1, token), 3)
        else (token, 1)

    ///
    /// What one quarter turn of `base` does, as layer turns and a frame rotation.
    ///
    def expand(n: Int32, base: String, token: String): Result[String, List[Op]] =
        match layerOf(base) {
            case Some(f) => Ok(Layer(Turn(f, 1)) :: Nil)
            case None    => expandNonLayer(n, base, token)
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
            case None      => expandWide(n, base, token)
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
    def sliceOf(base: String): Option[List[Op]] = match base {
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
    /// A move that needs a middle layer to turn, which only odd cubes have.
    ///
    /// The expansion given is the 3x3x3's. Larger odd cubes have more than one
    /// inner slice, so `M` alone would not say which, and the refusal names the
    /// size rather than guessing.
    ///
    def middleLayer(n: Int32, token: String, ops: List[Op]): Result[String, List[Op]] =
        if (n == 3) Ok(ops)
        else if (Int32.modulo(n, 2) == 0)
            Err("'${token}' does not name a move on a ${n}x${n}x${n}: a cube with an "
                + "even number of layers has no middle slice")
        else
            Err("'${token}' is ambiguous on a ${n}x${n}x${n}: it has more than one "
                + "inner slice, so the slice has to be named")

    ///
    /// A wide turn: the opposite face's layer, plus a rotation about that axis.
    ///
    /// On a 3x3x3 a wide turn is exactly two layers. On larger cubes it is
    /// still two by default but the outer-layer count can be written, and this
    /// module does not yet read that, so it refuses rather than assume.
    ///
    def wide(
        n: Int32,
        token: String,
        opposite: Face,
        r: Rotation.Rotation
    ): Result[String, List[Op]] =
        if (n == 3)
            Ok(Layer(Turn(opposite, 1)) :: Frame(r) :: Nil)
        else if (n == 2)
            Err("'${token}' does not name a move on a 2x2x2: both of its layers are "
                + "outer layers, so a wide turn would be the whole cube -- write a "
                + "rotation instead")
        else
            Err("'${token}' is not supported on a ${n}x${n}x${n} yet: this engine "
                + "implements wide turns for the 3x3x3 only")

}
