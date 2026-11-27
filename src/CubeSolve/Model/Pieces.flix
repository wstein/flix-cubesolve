///
/// Piece coordinates of a color cube, stored as an Orbit64 V2 state.
///
/// The solver still reads corners, midges, wings, and centers as separate
/// orbits. Those orbits are the fields of `Orbit64.V2.State.Cube`. This module
/// is the view the rest of the engine matches on. Facelet text and tokens go
/// through `Orbit64.V2.Facelets` and `Orbit64.V2.Codec`, color model. Odd cubes
/// use the canonical pose and even cubes the framed pose, so a moved DBL corner
/// stays where the engine put it. The whole-cube orientation stays on
/// `CubeSolve.Model.Cube` and is not written into the token.
///
pub mod CubeSolve.Model.Pieces {

    use orbit64::Orbit64.V2.Codec
    use orbit64::Orbit64.V2.Facelets
    use orbit64::Orbit64.V2.Registry
    use orbit64::Orbit64.V2.Registry.{Model, Pose}
    use orbit64::Orbit64.V2.State

    /// The state of a single orbit. Permutations are slot-wise: entry `i` is
    /// the piece in slot `i`. Orientations use the same order.
    pub enum Coord with Eq, ToString {
        /// Corner permutation and per-corner twist in `0..2`, summing to `0 mod 3`.
        case CornerCoord(Vector[Int32], Vector[Int32]),
        /// Midge permutation and per-edge flip in `0..1`, summing to `0 mod 2`.
        case MidgeCoord(Vector[Int32], Vector[Int32]),
        /// Wing permutation of twenty-four distinguishable pieces.
        case WingCoord(Vector[Int32]),
        /// Center colors in `0..5`, four slots of each color.
        case CenterCoord(Vector[Int32])
    }

    /// The four kinds of orbit, in the order a V2 color cube stores them.
    pub enum Kind with Eq, ToString {
        case Corners,
        case Midges,
        case Wings,
        case Centers
    }

    /// The kind of orbit `c` describes.
    pub def kind(c: Coord): Kind = match c {
        case Coord.CornerCoord(_, _) => Kind.Corners
        case Coord.MidgeCoord(_, _)  => Kind.Midges
        case Coord.WingCoord(_)      => Kind.Wings
        case Coord.CenterCoord(_)    => Kind.Centers
    }

    /// The orbits of an `n x n x n`, in V2 field order. Nothing below 2x2x2
    /// has an orbit. Midges exist only on odd cubes of size at least 3.
    pub def layout(n: Int32): List[Kind] =
        if (n < 2)
            Nil
        else
            let head =
                if (n >= 3 and Int32.modulo(n, 2) == 1)
                    Kind.Corners :: Kind.Midges :: Nil
                else
                    Kind.Corners :: Nil;
            let wings = List.repeat((n - 2) / 2, Kind.Wings);
            let centers = List.repeat(((n - 2) * (n - 2)) / 4, Kind.Centers);
            List.append(head, List.append(wings, centers))

    /// Why `c` is not a state a cube can be in, or nothing when it is one.
    pub def faultOf(c: Coord): Option[String] =
        let checks = match c {
            case Coord.CornerCoord(p, t) =>
                (isPermutation(p, 8), "the corner permutation is not a permutation of 0..7")
                    :: (Vector.length(t) == 8, "there must be exactly 8 corner twists, one per slot")
                    :: (Vector.forAll(x -> x >= 0 and x < 3, t), "every corner twist must be 0, 1 or 2")
                    :: (Int32.modulo(Vector.sum(t), 3) == 0, "the corner twists must sum to 0 mod 3")
                    :: Nil
            case Coord.MidgeCoord(p, f) =>
                (isPermutation(p, 12), "the midge permutation is not a permutation of 0..11")
                    :: (Vector.length(f) == 12, "there must be exactly 12 midge flips, one per slot")
                    :: (Vector.forAll(x -> x >= 0 and x < 2, f), "every midge flip must be 0 or 1")
                    :: (Int32.modulo(Vector.sum(f), 2) == 0, "the midge flips must sum to 0 mod 2")
                    :: Nil
            case Coord.WingCoord(p) =>
                (isPermutation(p, 24), "the wing permutation is not a permutation of 0..23") :: Nil
            case Coord.CenterCoord(cols) =>
                (Vector.length(cols) == 24, "there must be exactly 24 center slots")
                    :: (Vector.forAll(x -> x >= 0 and x < 6, cols), "every center color must be 0..5")
                    :: (
                        List.range(0, 6) |> List.forAll(col -> Vector.count(x -> x == col, cols) == 4),
                        "each of the six center colors must appear exactly four times"
                    )
                    :: Nil
        };
        List.filterMap(match (ok, why) -> if (ok) None else Some(why), checks) |> List.head

    /// The solved color state of an `n x n x n`, as orbits.
    pub def solved(n: Int32): List[Coord] =
        ofV2(State.solved(n, Model.Color))

    /// `orbits` as face-color indices, `face * n^2 + row * n + column`.
    ///
    /// Odd cubes use the canonical pose: fixed centers are the frame. Even
    /// cubes use the framed pose so a moved DBL corner is kept as it stands.
    pub def toFacelets(n: Int32, orbits: List[Coord]): Result[String, Vector[Int32]] =
        forM (
            cube <- toV2(n, orbits);
            text <- Facelets.toFacelets(n, Model.Color, poseOf(n), cube)
        ) yield lettersToIndices(text)

    /// The orbits shown by face-color indices.
    pub def fromFacelets(n: Int32, fs: Vector[Int32]): Result[String, List[Coord]] =
        Facelets.fromFacelets(n, Model.Color, poseOf(n), indicesToLetters(n, fs))
            |> Result.map(ofV2)

    /// A V2 color token for `orbits`, canonical on odd cubes and framed on even cubes.
    pub def encode(n: Int32, orbits: List[Coord]): Result[String, String] =
        match toV2(n, orbits) {
            case Err(why) => Err(why)
            case Ok(cube) =>
                match colorEntry(n, poseOf(n)) {
                    case Err(why) => Err(why)
                    case Ok(id)   => Codec.encode(id, cube)
                }
        }

    /// The orbits of a V2 color token for an `n x n x n` in `poseOf(n)`.
    pub def decode(n: Int32, token: String): Result[String, List[Coord]] =
        match Codec.decode(token) {
            case Err(why) => Err(why)
            case Ok((e, cube)) =>
                if (e#n == n and e#model == Model.Color and e#pose == poseOf(n))
                    Ok(ofV2(cube))
                else
                    Err("token is not a ${n}x${n}x${n} color state in the engine pose")
        }

    /// Canonical for odd `n`, framed for even `n`.
    def poseOf(n: Int32): Pose =
        if (Int32.modulo(n, 2) == 1) Pose.Canonical else Pose.Framed

    /// The V2 color cube `orbits` describes.
    pub def toV2(n: Int32, orbits: List[Coord]): Result[String, State.Cube] =
        if (List.map(kind, orbits) != layout(n))
            Err("a ${n}x${n}x${n} does not have these orbits")
        else
            match List.filterMap(faultOf, orbits) {
                case why :: _ => Err(why)
                case Nil      => Ok(assemble(n, orbits))
            }

    /// Orbits of a V2 color cube. The frame is not part of the list.
    pub def ofV2(cube: State.Cube): List[Coord] =
        let corners = Coord.CornerCoord(cube#cornerPieces, cube#cornerTwists);
        let midges =
            if (Vector.length(cube#midgePieces) == 0)
                Nil
            else
                Coord.MidgeCoord(cube#midgePieces, cube#midgeFlips) :: Nil;
        let wings =
            List.range(0, Vector.length(cube#wings))
                |> List.map(i -> Coord.WingCoord(Vector.get(i, cube#wings)));
        let centers =
            List.range(0, Vector.length(cube#centers))
                |> List.map(i -> Coord.CenterCoord(Vector.get(i, cube#centers)));
        List.append(corners :: midges, List.append(wings, centers))

    def assemble(n: Int32, orbits: List[Coord]): State.Cube =
        let (cp, ct, rest) = match orbits {
            case Coord.CornerCoord(p, t) :: more => (p, t, more)
            case _                               => (Vector.empty(), Vector.empty(), Nil)
        };
        let odd = n >= 3 and Int32.modulo(n, 2) == 1;
        let (mp, mf, rest2) =
            if (odd)
                match rest {
                    case Coord.MidgeCoord(p, f) :: more => (p, f, more)
                    case _                              => (Vector.empty(), Vector.empty(), rest)
                }
            else
                (Vector.empty(), Vector.empty(), rest);
        let (wings, centers) = takeWings(rest2);
        {
            cornerPieces = cp,
            cornerTwists = ct,
            midgePieces  = mp,
            midgeFlips   = mf,
            wings        = List.toVector(wings),
            centers      = List.toVector(centers),
            rotations    = Vector.empty(),
            frame        = 0
        }

    def takeWings(os: List[Coord]): (List[Vector[Int32]], List[Vector[Int32]]) = match os {
        case Coord.WingCoord(p) :: more =>
            let (w, c) = takeWings(more);
            (p :: w, c)
        case _ => (Nil, takeCenters(os))
    }

    def takeCenters(os: List[Coord]): List[Vector[Int32]] = match os {
        case Coord.CenterCoord(cols) :: more => cols :: takeCenters(more)
        case _                               => Nil
    }

    def colorEntry(n: Int32, pose: Pose): Result[String, Int32] =
        match Registry.entries()
            |> List.find(e -> e#n == n and e#model == Model.Color and e#pose == pose) {
            case Some(e) => Ok(e#id)
            case None    => Err("no V2 color entry for the ${n}x${n}x${n}")
        }

    def lettersToIndices(text: String): Vector[Int32] =
        String.toList(text)
            |> List.filter(c -> c != ' ')
            |> List.map(letterFace)
            |> List.toVector

    def indicesToLetters(n: Int32, fs: Vector[Int32]): String =
        List.range(0, 6)
            |> List.map(
                face ->
                    List.range(0, n * n)
                        |> List.map(i -> Char.toString(faceLetter(Vector.get(face * n * n + i, fs))))
                        |> List.toVector
                        |> Vector.join("")
            )
            |> List.toVector
            |> Vector.join(" ")

    def faceLetter(i: Int32): Char = match i {
        case 0 => 'U'
        case 1 => 'R'
        case 2 => 'F'
        case 3 => 'D'
        case 4 => 'L'
        case _ => 'B'
    }

    def letterFace(c: Char): Int32 = match c {
        case 'U' => 0
        case 'R' => 1
        case 'F' => 2
        case 'D' => 3
        case 'L' => 4
        case 'B' => 5
        case _   => 0
    }

    def isPermutation(p: Vector[Int32], n: Int32): Bool =
        Vector.length(p) == n and List.range(0, n) |> List.forAll(i -> Vector.memberOf(i, p))
}
