///
/// Curated published 4x4x4 patterns.
///
pub mod CubeSolve.Patterns.Revenge {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Rotation
    use CubeSolve.Patterns.Revenge.Pattern.Pattern

    ///
    /// A 4x4x4 pattern: its name, canonical identity, source collection, and notation.
    ///
    pub enum Pattern with Eq, ToString {
        case Pattern(String, String, String, String)
    }

    /// The pattern's name.
    pub def name(p: Pattern): String = let Pattern(n, _, _, _) = p; n

    /// The pattern's identity as a state.
    pub def canonical(p: Pattern): String = let Pattern(_, c, _, _) = p; c

    /// Which collection it was taken from.
    pub def source(p: Pattern): String = let Pattern(_, _, s, _) = p; s

    /// The algorithm as written.
    pub def notation(p: Pattern): String = let Pattern(_, _, _, a) = p; a

    /// The URL this pattern's source refers to.
    pub def url(id: String): String = CubeSolve.Patterns.url(id)

    ///
    /// The cube this pattern describes, starting from solved.
    ///
    pub def cube(p: Pattern): Result[String, Cube] =
        Cube.solved(4) |> Result.flatMap(c -> Cube.applyNotation(notation(p), c))

    ///
    /// Every curated 4x4x4 pattern in the collection.
    ///
    pub def all(): Vector[Pattern] =
        Vector.append(curated(), kewbz())

    def curated(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Rings",
                "BgCMFIam7T1WZ0VR9BW3boKGFHQ",
                "ruwix1",
                "B' M2 U2 M2 B F2 R U' R U R2 U R2 F' U F' Uw Lw Uw' Fw2 Dw Rw' Uw Fw Dw2 Rw2"
            ),
            // Speedsolving's 4x4x4 pattern: U and D stay one color and the four
            // side faces are checkerboards. `Rw2 Lw2 U2 D2 Fw2 Bw2` leaves two
            // opposite-color bands on those sides.
            Pattern(
                "Checkerboard",
                "AE28Oe_wDgg9V2kTxRWxil7w2l7",
                "speedsolving",
                "3Rw2 Rw2' R2 3Fw2 2Fw2' F2 3Rw2 Rw2' R2 3Dw2 Dw2' D2"
            ),
            // On a 4x4x4 the parser reads lowercase `r` as the inner slice, the
            // same layer as `2R`, so `r2 l2 u2 d2 f2 b2` and
            // `2R2 2L2 2U2 2D2 2F2 2B2` are one cube: corners and the 2x2 centers
            // keep the face color, and the edge wings take the opposite color.
            // The wide spelling `Rw2 Lw2 Uw2 Dw2 Fw2 Bw2` solves the cube, so
            // those lowercase letters are not a second pattern. One row, and the
            // token is the replay of this algorithm.
            Pattern(
                "Small Checkerboard",
                "AAAAAMa_lfp4E4qBbYb4i5RLLMw",
                "speedsolving",
                "r2 l2 u2 d2 f2 b2"
            ),
            Pattern(
                "Cube in a Cube",
                "BSDCAf3HQFJ6CI4atyT1Y_bbIMo",
                "ruwix1",
                "Fw2 R2 Uw2 R2 Fw2 R2 Uw2 R2 Fw2 R2 Uw2 R2"
            )
        }

    def kewbz(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Kewbz 4x4 pattern 1",
                "AH0K11HYWVLZZpY7kzeGwV_Ontg",
                "kewbz4",
                "U D' R L' F B' U D'"
            ),
            Pattern(
                "Kewbz 4x4 pattern 3",
                "AGcu-YLVSJ0-2-9nILDcO9H-cGA",
                "kewbz4",
                "F L F U' R U F2 L2 U' L' B D' B' L2 U "
                    + "Fw Lw Fw Uw' Rw Uw Fw2 Lw2 Uw' Lw' Bw Dw' Bw' Lw2 Uw"
            ),
            Pattern(
                "Kewbz 4x4 pattern 4",
                "AH0CaBEVHxxxWDTVisruFH_K32A",
                "kewbz4",
                "F L F U' R U F2 L2 U' L' B D' B' L2 U"
            ),
            Pattern(
                "Kewbz 4x4 pattern 5",
                "BgCH2rBjimb-mK3rH2k-0vRbkuQ",
                "kewbz4",
                "F U2 L F L' B L U B' R' L' U R' D' F' B R2"
            ),
            Pattern(
                "Kewbz 4x4 pattern 6",
                "AGcra9Egn_sqqT8uRyYgMXECm40",
                "kewbz4",
                "F R2 E' R2 B E R D2 B M' E' F' R2 U' B2 Uw2 Rw2 U2 R2 Fw2 Rw2 u2"
            ),
            Pattern(
                "Kewbz 4x4 pattern 7",
                "AhYSY5QzT1k5RlLUk-oTMUULw94",
                "kewbz4",
                "Dw M2 Dw2 S2 Dw M2 Bw2 Rw2 B2 f2"
            ),
            Pattern(
                "Kewbz 4x4 pattern 8",
                "AAAAAAAAAAAAAAAAAAAcjcE6clW",
                "kewbz4",
                "E' M u' d2 f' d' u' b u S M'"
            ),
            Pattern(
                "Kewbz 4x4 pattern 9",
                "BgCH2qa_S5InoAPCjtyQyQOaRhw",
                "kewbz4",
                "F2 L2 d b2 Dw f2 Dw' b2 D f2 Dw' L2 f2 Lw2 Uw' Lw' Uw Lw' Fw2 Lw Uw' Lw'"
            )
        }

}
