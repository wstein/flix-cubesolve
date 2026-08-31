///
/// Face turns: what they are, how they are written, and what they do to pieces.
///
/// This module is the single declaration site for the move conventions. Every
/// table, fixture and test in the repository is expressed in terms of the
/// numbering here, so changing it invalidates all of them -- which is why
/// `docs/conventions.md` states it in prose as well, and why every generated
/// table carries it in its header.
///
mod CubeSolve.Model.Move {

    use CubeSolve.Model.Move.Face.{U, R, F, D, L, B}
    use CubeSolve.Model.Move.Move.Turn

    ///
    /// A face turned by a quarter, a half, or three quarters clockwise.
    ///
    /// Clockwise is as seen from outside the cube, looking at the face. There
    /// is no anticlockwise constructor: `U'` is `Turn(U, 3)`, which keeps the
    /// amount arithmetic (`inverse` is `4 - amount`) and keeps the move index
    /// contiguous.
    ///
    pub enum Move with Eq, Order {
        case Turn(Face, Int32)
    }


    ///
    /// The six faces, in Kociemba order.
    ///
    /// The order is not arbitrary and not merely inherited: opposite faces are
    /// three apart, so `axis` and `opposite` are arithmetic rather than lookups,
    /// and the face index doubles as the colour index used by the facelet
    /// interchange.
    ///
    pub enum Face with Eq, Order, ToString {
        case U, case R, case F, case D, case L, case B
    }

    instance ToString[Move] {
        pub def toString(m: Move): String = show(m)
    }

    ///
    /// The index of `f` in `U R F D L B`, which is also its colour index.
    ///
    pub def faceIndex(f: Face): Int32 = match f {
        case U => 0
        case R => 1
        case F => 2
        case D => 3
        case L => 4
        case B => 5
    }

    ///
    /// The face with index `i`, or `None` when `i` names no face.
    ///
    pub def faceOfIndex(i: Int32): Option[Face] = match i {
        case 0 => Some(U)
        case 1 => Some(R)
        case 2 => Some(F)
        case 3 => Some(D)
        case 4 => Some(L)
        case 5 => Some(B)
        case _ => None
    }

    ///
    /// Every face, in index order.
    ///
    pub def faces(): Vector[Face] = Vector#{U, R, F, D, L, B}

    ///
    /// The axis `f` turns about: `0` for U/D, `1` for R/L, `2` for F/B.
    ///
    /// Two faces share an axis exactly when their turns commute, which is what
    /// the search's move ordering rule is built on.
    ///
    pub def axis(f: Face): Int32 = Int32.modulo(faceIndex(f), 3)

    ///
    /// The face opposite `f`.
    ///
    pub def opposite(f: Face): Face =
        faceOfIndex(Int32.modulo(faceIndex(f) + 3, 6)) |> Option.getWithDefault(f)

    ///
    /// Whether turns of `a` and `b` commute.
    ///
    /// True for a face with itself and for a face with its opposite, and false
    /// otherwise. The search uses this to fix an order within each commuting
    /// pair, so that `U D` and `D U` are not both explored.
    ///
    pub def commutes(a: Face, b: Face): Bool = axis(a) == axis(b)

    ///
    /// The face `m` turns.
    ///
    pub def face(m: Move): Face = let Turn(f, _) = m; f

    ///
    /// How many clockwise quarter turns `m` is, in `1..3`.
    ///
    pub def amount(m: Move): Int32 = let Turn(_, k) = m; k

    ///
    /// The index of `m` in the half-turn alphabet: `face * 3 + (amount - 1)`.
    ///
    /// So `U U2 U' R R2 R' ...` are `0 1 2 3 4 5 ...`, and the moves of one
    /// face are contiguous -- which is what lets the successor loop skip a
    /// whole face with a range test rather than six comparisons.
    ///
    pub def index(m: Move): Int32 = faceIndex(face(m)) * 3 + amount(m) - 1

    ///
    /// The move with index `i`, or `None` when `i` names no move.
    ///
    pub def ofIndex(i: Int32): Option[Move] =
        if (i < 0 or i >= 18) None
        else faceOfIndex(i / 3) |> Option.map(f -> Turn(f, Int32.modulo(i, 3) + 1))

    ///
    /// All eighteen half-turn-metric moves, in index order.
    ///
    pub def all(): Vector[Move] =
        Vector.init(i -> ofIndex(i) |> Option.getWithDefault(Turn(U, 1)), 18)

    ///
    /// Whether move `next` may follow move `last` in a half-turn-metric search.
    ///
    /// Both are move indices; `last` is negative at the root, where everything
    /// is allowed. Two rules, and both are sound only for this alphabet:
    ///
    /// - **Never the same face twice.** Over the half-turn alphabet any two
    ///   consecutive turns of one face are a single turn of it, so nothing is
    ///   lost. Over a clockwise-only alphabet this rule is *wrong*: forbidding
    ///   `R` after `R` makes `R2` inexpressible.
    /// - **A fixed order within each commuting pair.** `U D` and `D U` reach
    ///   the same state, so only the lower-numbered face may go first. Because
    ///   opposite faces are three apart, both rules are the one test below.
    ///
    pub def htmPruningAllows(last: Int32, next: Int32): Bool =
        last < 0 or {
            let lastFace = last / 3;
            let nextFace = next / 3;
            not (Int32.modulo(lastFace, 3) == Int32.modulo(nextFace, 3)
                 and lastFace >= nextFace)
        }

    ///
    /// The move that undoes `m`.
    ///
    pub def inverse(m: Move): Move = Turn(face(m), 4 - amount(m))

    ///
    /// The sequence that undoes `ms`: reversed, with every move inverted.
    ///
    pub def inverseOf(ms: List[Move]): List[Move] =
        ms |> List.map(inverse) |> List.reverse

    ///
    /// `m` in the usual notation: `U`, `U2`, `U'`.
    ///
    pub def show(m: Move): String =
        "${face(m)}" + (match amount(m) {
            case 1 => ""
            case 2 => "2"
            case _ => "'"
        })

    ///
    /// `ms` with adjacent turns of one face composed into a single turn.
    ///
    /// Two turns of the same face compose exactly -- they are the same
    /// generator -- so `U U` is `U2`, `U U'` is nothing at all, and `U U U U`
    /// is nothing at all. Nothing else is touched: turns of different faces are
    /// left in the order they were given, even when they commute, because
    /// reordering them would change a sequence a person has to follow.
    ///
    /// **This matters for anything a person reads.** A method answer is built
    /// by joining an orienting turn to an algorithm that begins with one of its
    /// own, and the parser expands `U2` into two quarter turns, so an
    /// uncomposed answer prints `U U U U F ...` -- four quarter turns of one
    /// face, which is to say nothing at all, in front of the move that matters.
    /// It also makes the move count wrong, and a move count is the number
    /// everybody compares.
    ///
    pub def compact(ms: List[Move]): List[Move] =
        ms |> List.foldLeft(compactOnto, Nil) |> List.reverse

    ///
    /// `m` composed onto `acc`, which is in reverse order.
    ///
    def compactOnto(acc: List[Move], m: Move): List[Move] = match acc {
        case last :: rest if face(last) == face(m) =>
            let turns = (amount(last) + amount(m)) `Int32.remainder` 4;
            if (turns == 0) rest else Turn(face(m), turns) :: rest
        case _ => m :: acc
    }

    ///
    /// `ms` in the usual notation, space separated.
    ///
    pub def showAll(ms: List[Move]): String =
        ms |> List.map(show) |> List.join(" ")

    ///
    /// The moves `s` names, or why it names none.
    ///
    /// Whitespace separated; any amount of it, of any kind. The error names the
    /// offending token rather than the position, because a caller that built the
    /// string by concatenation knows its tokens and not its offsets.
    ///
    pub def parse(s: String): Result[String, List[Move]] =
        String.words(s) |> Result.traverse(parseMove)

    ///
    /// The single move `token` names, or why it names none.
    ///
    pub def parseMove(token: String): Result[String, Move] =
        let letter = String.takeLeft(1, token);
        let rest = String.dropLeft(1, token);
        match parseFace(letter) {
            case None =>
                Err("'${token}' does not name a move: '${letter}' is not one "
                    + "of U R F D L B")
            case Some(f) => match rest {
                case ""  => Ok(Turn(f, 1))
                case "2" => Ok(Turn(f, 2))
                case "'" => Ok(Turn(f, 3))
                case _   => Err("'${token}' does not name a move: expected '${letter}', "
                              + "'${letter}2' or '${letter}'' but found the suffix '${rest}'")
            }
        }

    def parseFace(s: String): Option[Face] = match s {
        case "U" => Some(U)
        case "R" => Some(R)
        case "F" => Some(F)
        case "D" => Some(D)
        case "L" => Some(L)
        case "B" => Some(B)
        case _   => None
    }

    // ---------- what a turn does to pieces ----------
    //
    // Four tables per face, for one clockwise quarter turn. They are
    // slot-indexed: entry `i` of a permutation names the slot whose piece moves
    // into slot `i`, so applying a turn to a state `p` is `p'[i] = p[table[i]]`.
    //
    // Corner slots:  URF UFL ULB UBR DFR DLF DBL DRB
    // Edge slots:    UR UF UL UB DR DF DL DB FR FL BL BR
    //
    // U and D leave every orientation alone because a turn about the U/D axis
    // maps U and D facelets onto U and D facelets. R and L likewise leave edge
    // flip alone under this flip convention, but do twist corners. Only F and B
    // flip edges. That asymmetry is a property of the convention, not of the
    // cube -- it is why the convention has to be written down.

    ///
    /// The faces each corner slot touches, from its orientation facelet
    /// clockwise.
    ///
    /// This is the geometry the move tables above encode implicitly, written
    /// out so that it can be computed with. A whole-cube rotation permutes
    /// faces, and knowing which faces a slot touches is what turns a face
    /// permutation into a piece permutation -- without which the solver could
    /// not look at the cube along a different axis.
    ///
    /// The first entry is the orientation facelet, so a piece's twist is how
    /// far its own first face has rotated away from its slot's.
    ///
    pub def cornerFaces(): Vector[Vector[Int32]] = Vector#{
        Vector#{0, 1, 2},
        Vector#{0, 2, 4},
        Vector#{0, 4, 5},
        Vector#{0, 5, 1},
        Vector#{3, 2, 1},
        Vector#{3, 4, 2},
        Vector#{3, 5, 4},
        Vector#{3, 1, 5}
    }

    ///
    /// The faces each edge slot touches, its orientation facelet first.
    ///
    pub def edgeFaces(): Vector[Vector[Int32]] = Vector#{
        Vector#{0, 1},
        Vector#{0, 2},
        Vector#{0, 4},
        Vector#{0, 5},
        Vector#{3, 1},
        Vector#{3, 2},
        Vector#{3, 4},
        Vector#{3, 5},
        Vector#{2, 1},
        Vector#{2, 4},
        Vector#{5, 4},
        Vector#{5, 1}
    }

    ///
    /// Where each corner slot's piece comes from, for one clockwise turn of `f`.
    ///
    pub def cornerPermutation(f: Face): Vector[Int32] = match f {
        case U => Vector#{3, 0, 1, 2, 4, 5, 6, 7}
        case R => Vector#{4, 1, 2, 0, 7, 5, 6, 3}
        case F => Vector#{1, 5, 2, 3, 0, 4, 6, 7}
        case D => Vector#{0, 1, 2, 3, 5, 6, 7, 4}
        case L => Vector#{0, 2, 6, 3, 4, 1, 5, 7}
        case B => Vector#{0, 1, 3, 7, 4, 5, 2, 6}
    }

    ///
    /// The twist each corner slot's piece gains, for one clockwise turn of `f`.
    ///
    pub def cornerTwist(f: Face): Vector[Int32] = match f {
        case U => Vector#{0, 0, 0, 0, 0, 0, 0, 0}
        case R => Vector#{2, 0, 0, 1, 1, 0, 0, 2}
        case F => Vector#{1, 2, 0, 0, 2, 1, 0, 0}
        case D => Vector#{0, 0, 0, 0, 0, 0, 0, 0}
        case L => Vector#{0, 1, 2, 0, 0, 2, 1, 0}
        case B => Vector#{0, 0, 1, 2, 0, 0, 2, 1}
    }

    ///
    /// Where each edge slot's piece comes from, for one clockwise turn of `f`.
    ///
    pub def edgePermutation(f: Face): Vector[Int32] = match f {
        case U => Vector#{3, 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11}
        case R => Vector#{8, 1, 2, 3, 11, 5, 6, 7, 4, 9, 10, 0}
        case F => Vector#{0, 9, 2, 3, 4, 8, 6, 7, 1, 5, 10, 11}
        case D => Vector#{0, 1, 2, 3, 5, 6, 7, 4, 8, 9, 10, 11}
        case L => Vector#{0, 1, 10, 3, 4, 5, 9, 7, 8, 2, 6, 11}
        case B => Vector#{0, 1, 2, 11, 4, 5, 6, 10, 8, 9, 3, 7}
    }

    ///
    /// The flip each edge slot's piece gains, for one clockwise turn of `f`.
    ///
    pub def edgeFlip(f: Face): Vector[Int32] = match f {
        case U => Vector#{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        case R => Vector#{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        case F => Vector#{0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0}
        case D => Vector#{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        case L => Vector#{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        case B => Vector#{0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1}
    }

}
