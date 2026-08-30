///
/// The 4x4x4 reduction model and equivalence mapping to a 3x3x3 cube.
///
/// A 4x4x4 cube is reduced when:
/// 1. All 24 center stickers match their respective face colours.
/// 2. All 12 edge wing pairs have matching colors, forming 12 unified edge blocks.
///
/// Once reduced, the 4x4x4 cube maps directly to an equivalent 3x3x3 cube,
/// which can then be solved using the standard two-phase solver.
///
mod CubeSolve.Model.Revenge {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use Orbit64.Coord.Coord.{CornerCoord, WingCoord}

    /// The standard OLL edge-flip parity algorithm.
    pub def ollParity(): String =
        "2R2 B2 U2 2L U2 2R' U2 2R U2 F2 2R F2 2L' B2 2R2"

    /// The standard PLL opposite edge-swap parity algorithm.
    pub def pllParity(): String =
        "2R2 U2 2R2 Uw2 2R2 2u2"

    ///
    /// True if all 4 centers on each face match the face's canonical colour.
    ///
    pub def isCentersSolved(c: Cube.Cube): Bool =
        match Facelets.of(c) {
            case Err(_) => false
            case Ok(fs) =>
                List.range(0, 6) |> List.forAll(f -> {
                    let c0 = Vector.get(f * 16 + 5, fs);
                    let c1 = Vector.get(f * 16 + 6, fs);
                    let c2 = Vector.get(f * 16 + 9, fs);
                    let c3 = Vector.get(f * 16 + 10, fs);
                    c0 == f and c1 == f and c2 == f and c3 == f
                })
        }

    ///
    /// True if all 12 edge pairs on the 4x4x4 cube are paired into matching composite edges.
    ///
    pub def isWingsPaired(c: Cube.Cube): Bool =
        match Facelets.of(c) {
            case Err(_) => false
            case Ok(fs) =>
                edges() |> List.forAll(e -> {
                    let (i1, i2, j1, j2) = e;
                    Vector.get(i1, fs) == Vector.get(i2, fs)
                        and Vector.get(j1, fs) == Vector.get(j2, fs)
                })
        }

    ///
    /// True if the 4x4x4 cube has all centers solved and all 12 edges paired.
    ///
    pub def isReduced(c: Cube.Cube): Bool =
        Cube.size(c) == 4 and isCentersSolved(c) and isWingsPaired(c)

    ///
    /// Check if the 24 wing edges form an odd permutation (OLL edge flip parity).
    ///
    pub def hasWingParity(c: Cube.Cube): Result[String, Bool] =
        if (Cube.size(c) != 4)
            Err("cube is not a 4x4x4")
        else {
            let wings = Cube.orbits(c) |> List.filterMap(o -> match o {
                case WingCoord(p) => Some(p)
                case _ => None
            });
            match wings {
                case wp :: Nil => Ok(parityOf(wp) == 1)
                case _ => Err("expected exactly one wing orbit for 4x4x4")
            }
        }

    ///
    /// Check if the 8 corners form an odd permutation (PLL parity when reduced).
    ///
    pub def hasCornerParity(c: Cube.Cube): Result[String, Bool] =
        if (Cube.size(c) != 4)
            Err("cube is not a 4x4x4")
        else {
            let corners = Cube.orbits(c) |> List.filterMap(o -> match o {
                case CornerCoord(p, _) => Some(p)
                case _ => None
            });
            match corners {
                case cp :: Nil => Ok(parityOf(cp) == 1)
                case _ => Err("expected exactly one corner orbit for 4x4x4")
            }
        }

    ///
    /// Convert a reduced 4x4x4 cube to its equivalent 3x3x3 representation.
    ///
    pub def toStandard(c: Cube.Cube): Result[String, Cube.Cube] =
        if (Cube.size(c) != 4)
            Err("cube is not a 4x4x4")
        else if (not isCentersSolved(c))
            Err("centers are not solved")
        else if (not isWingsPaired(c))
            Err("edges are not all paired")
        else
            Facelets.of(c) |> Result.flatMap(fs4 -> {
                let fs3 = sample3x3Facelets(fs4);
                Facelets.toCube(3, fs3)
            })

    ///
    /// The parity of `p`: `0` when it is an even permutation, `1` when odd.
    ///
    def parityOf(p: Vector[Int32]): Int32 = {
        let n = Vector.length(p);
        let inversions =
            Vector.range(0, n) |> Vector.map(i ->
                Vector.range(i + 1, n)
                    |> Vector.count(j -> Vector.get(i, p) > Vector.get(j, p)))
                |> Vector.sum;
        Int32.modulo(inversions, 2)
    }

    ///
    /// Extract the 54 facelets of a 3x3x3 cube from a reduced 4x4x4 facelet array.
    ///
    def sample3x3Facelets(fs4: Vector[Int32]): Vector[Int32] =
        Vector.range(0, 54) |> Vector.map(i -> {
            let face = i / 9;
            let cell = Int32.modulo(i, 9);
            let pos4 = match cell {
                case 0 => 0
                case 1 => 1
                case 2 => 3
                case 3 => 4
                case 4 => 5
                case 5 => 7
                case 6 => 12
                case 7 => 13
                case 8 => 15
                case _ => 0
            };
            Vector.get(face * 16 + pos4, fs4)
        })

    /// The 12 edge pairs as 4-tuples: (face1_wing1, face1_wing2, face2_wing1, face2_wing2).
    def edges(): List[(Int32, Int32, Int32, Int32)] =
        // UB: U top (1, 2) and B top (2, 1)
        (0 * 16 + 1, 0 * 16 + 2, 5 * 16 + 2, 5 * 16 + 1)
        // UL: U left (4, 8) and L top (1, 2)
        :: (0 * 16 + 4, 0 * 16 + 8, 4 * 16 + 1, 4 * 16 + 2)
        // UR: U right (7, 11) and R top (2, 1)
        :: (0 * 16 + 7, 0 * 16 + 11, 1 * 16 + 2, 1 * 16 + 1)
        // UF: U bottom (13, 14) and F top (1, 2)
        :: (0 * 16 + 13, 0 * 16 + 14, 2 * 16 + 1, 2 * 16 + 2)
        // FL: F left (4, 8) and L right (7, 11)
        :: (2 * 16 + 4, 2 * 16 + 8, 4 * 16 + 7, 4 * 16 + 11)
        // FR: F right (7, 11) and R left (4, 8)
        :: (2 * 16 + 7, 2 * 16 + 11, 1 * 16 + 4, 1 * 16 + 8)
        // BL: B right (7, 11) and L left (4, 8)
        :: (5 * 16 + 7, 5 * 16 + 11, 4 * 16 + 4, 4 * 16 + 8)
        // BR: B left (4, 8) and R right (7, 11)
        :: (5 * 16 + 4, 5 * 16 + 8, 1 * 16 + 7, 1 * 16 + 11)
        // DF: D top (1, 2) and F bottom (13, 14)
        :: (3 * 16 + 1, 3 * 16 + 2, 2 * 16 + 13, 2 * 16 + 14)
        // DL: D left (4, 8) and L bottom (14, 13)
        :: (3 * 16 + 4, 3 * 16 + 8, 4 * 16 + 14, 4 * 16 + 13)
        // DR: D right (7, 11) and R bottom (13, 14)
        :: (3 * 16 + 7, 3 * 16 + 11, 1 * 16 + 13, 1 * 16 + 14)
        // DB: D bottom (13, 14) and B bottom (14, 13)
        :: (3 * 16 + 13, 3 * 16 + 14, 5 * 16 + 14, 5 * 16 + 13)
        :: Nil

}
