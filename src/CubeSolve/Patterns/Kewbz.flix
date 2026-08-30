///
/// Kewbz's published 3x3x3, 4x4x4, and 5x5x5 pattern variants.
///
/// Unlike the canonical pattern catalogues, this source collection deliberately
/// keeps variants that make a state already represented elsewhere. A variant's
/// `source` therefore says where *its algorithm* came from, rather than making
/// a claim about who first named the state.
///
mod CubeSolve.Patterns.Kewbz {

    use CubeSolve.Model.Cube
    use CubeSolve.Patterns.Kewbz.Pattern.Pattern

    /// A sourced pattern variant: size, displayed name, state token, source, and algorithm.
    pub enum Pattern with Eq, ToString {
        case Pattern(Int32, String, String, String, String)
    }

    /// The size of cube this variant applies to.
    pub def size(p: Pattern): Int32 = let Pattern(n, _, _, _, _) = p; n

    /// The pattern name printed by the source, or a stable ordinal where it prints none.
    pub def name(p: Pattern): String = let Pattern(_, n, _, _, _) = p; n

    /// The state token reached from solved by this variant's algorithm.
    pub def canonical(p: Pattern): String = let Pattern(_, _, c, _, _) = p; c

    /// The page that published this exact algorithm.
    pub def source(p: Pattern): String = let Pattern(_, _, _, s, _) = p; s

    /// The algorithm exactly as recorded from the source, normalized only to ASCII primes.
    pub def notation(p: Pattern): String = let Pattern(_, _, _, _, a) = p; a

    /// The source URL for this variant.
    pub def url(p: Pattern): String = CubeSolve.Patterns.url(source(p))

    /// The cube this variant describes, starting from solved.
    pub def cube(p: Pattern): Result[String, Cube] =
        Cube.solved(size(p)) |> Result.flatMap(c -> Cube.applyNotation(notation(p), c))

    /// Every Kewbz variant, preserving the algorithm and page that supplied it.
    pub def all(): Vector[Pattern] =
        Vector.append(kewbz3(), Vector.append(kewbz4(), kewbz5()))

    def kewbz3(): Vector[Pattern] = Vector#{
        Pattern(3, "Checkerboard", "AAAAAH1cCIAA", "kewbz3", "U2 D2 F2 B2 L2 R2"),
        Pattern(3, "Superflip", "AAAAAAAAAAf_", "kewbz3",
            "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2"),
        Pattern(3, "Cube in a Cube", "AEtd1CzDOflC", "kewbz3",
            "F L F U' R U F2 L2 U' L' B D' B' L2 U"),
        Pattern(3, "Cube in a Cube in a Cube", "AD42uAgInmng", "kewbz3",
            "U' L' U' F' R2 B' R F U B2 U B' L U' F U R F'"),
        Pattern(3, "Cross 1", "Au28qMWIIAAA", "kewbz3", "U F B' L2 U2 L2 F' B U2 L2 U"),
        Pattern(3, "Cross 2", "AD45QY3RYAAA", "kewbz3",
            "R2 L' D F2 R' D' R' L U' D R D B2 R' U D2"),
        Pattern(3, "Anaconda", "AEtgYIATpdQV", "kewbz3",
            "L U B' U' R L' B R' F B' D R D' F'"),
        Pattern(3, "Python", "Au28qSdW8sAF", "kewbz3",
            "F2 R' B' U R' L F' L F' B D' R B L2"),
        Pattern(3, "Black Mamba", "BHJIYMWto45g", "kewbz3",
            "R D L F' R L' D R' U D' B U' R' D'"),
        Pattern(3, "Green Mamba", "BHJIYCui2sLg", "kewbz3",
            "R D R F R' F' B D R' U' B' U D2"),
        Pattern(3, "4 Centers", "AVd4zWoSqIAA", "kewbz3", "F2 B2 U D' R2 L2 U D'"),
        Pattern(3, "6 Centers", "AEtgYICyPB1X", "kewbz3", "U D' R L' F B' U D'"),
        Pattern(3, "Center / Edge / Corner", "AD45Qa3HXB1X", "kewbz3",
            "U' R2 L2 F2 B2 U' R L F B' U F2 D2 R2 L2 F2 U2 F2 U' F2"),
        Pattern(3, "Tetris", "AW622DQhY0VX", "kewbz3", "L R F B U' D' L' R'"),
        Pattern(3, "Facing Checkerboard", "AAAAACfNmbgA", "kewbz3",
            "U2 F2 U2 F2 B2 U2 F2 D2"),
        Pattern(3, "4H", "AAAAACmIqAAA", "kewbz3", "(M2 U2 M2 U2 y)x2"),
        Pattern(3, "4I", "AAAAAAqeNUAA", "kewbz3", "(M2 U2 M2 U2 x)x2")
    }

    def kewbz4(): Vector[Pattern] = Vector#{
        Pattern(4, "Kewbz 4x4 pattern 1", "AH0Hmo16YfPV7lTF3_VGkq_Ontg", "kewbz4",
            "U D' R L' F B' U D'"),
        Pattern(4, "Kewbz 4x4 pattern 2", "BgCQSexUSGwOHTQEkFI-EZqGFHQ", "kewbz4",
            "B' M2 U2 M2 B F2 R U' R U R2 U R2 F' U F' Uw Lw Uw' Fw2 Dw Rw' Uw Fw Dw2 Rw2"),
        Pattern(4, "Kewbz 4x4 pattern 3", "AGcuAOGF5M2KnkIqN7aVx2n-cGA", "kewbz4",
            "F L F U' R U F2 L2 U' L' B D' B' L2 U "
                + "Fw Lw Fw Uw' Rw Uw Fw2 Lw2 Uw' Lw' Bw Dw' Bw' Lw2 Uw"),
        Pattern(4, "Kewbz 4x4 pattern 4", "AH0DYLJkguwlleISc8U0iOfK32A", "kewbz4",
            "F L F U' R U F2 L2 U' L' B D' B' L2 U"),
        Pattern(4, "Kewbz 4x4 pattern 5", "BgCH2rBjimb-mK3rH2k-0vRbkuQ", "kewbz4",
            "F U2 L F L' B L U B' R' L' U R' D' F' B R2"),
        Pattern(4, "Kewbz 4x4 pattern 6", "AGcra9Egn_sqqT8uRyYgMXECm40", "kewbz4",
            "F R2 E' R2 B E R D2 B M' E' F' R2 U' B2 Uw2 Rw2 U2 R2 Fw2 Rw2 u2"),
        Pattern(4, "Kewbz 4x4 pattern 7", "AhYSY5QzT1k5RlLUk-oTMUULw94", "kewbz4",
            "Dw M2 Dw2 S2 Dw M2 Bw2 Rw2 B2 f2"),
        Pattern(4, "Kewbz 4x4 pattern 8", "AAAAAAAAAAAAAAAAAAAcjcE6clW", "kewbz4",
            "E' M u' d2 f' d' u' b u S M'"),
        Pattern(4, "Kewbz 4x4 pattern 9", "BgCH2qa_S5InoAPCjtyQyQOaRhw", "kewbz4",
            "F2 L2 d b2 Dw f2 Dw' b2 D f2 Dw' L2 f2 Lw2 Uw' Lw' Uw Lw' Fw2 Lw Uw' Lw'")
    }

    def kewbz5(): Vector[Pattern] = Vector#{
        Pattern(5, "Checkerboard", "DktI-pArB2Jt1Vvz8NWYrqTZd5EkLFlm_WQfdTSDdu", "kewbz5",
            "Rw2 Lw2 Uw2 D2 Dw2 B2 Bw2 F2 Fw2"),
        Pattern(5, "Tri-Checkerboard", "AAAAApDI7p3NmLKwwTrSByBrnOZqzGfRRyCMxGwx8z", "kewbz5",
            "F B2 R' D2 B R U D' R L' D' F' R2 D F2 B' "
                + "Fw Bw2 Rw' Dw2 Bw Rw Uw Dw' Rw Lw' Dw' Fw' Rw2 Dw Fw2 Bw'"),
        Pattern(5, "Superflip", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACYTqPvFoq", "kewbz5",
            "(m' U)x4 (x y') (m' U)x4 (x y') (m' U)x4 (x y') "
                + "(M' Uw)x4 (x y') (M' Uw)x4 (x y') (M' Uw)x4"),
        Pattern(5, "Square in a Cube", "AUGtEEgNo9EmSZCUbOTgD0uCqBYMiYgE8OBCTp0QoA", "kewbz5",
            "U D' R L' F B' U D'"),
        Pattern(5, "Flipped Edges", "AAAAAIhlX3EwhvbN0pEDLnD-YCzV2zS02eBCTp0QoA", "kewbz5",
            "F B2 R' D2 B R U D' R L' D' F' R2 D F2 B'"),
        Pattern(5, "Flipped Edge Checkerboard",
            "AAAAAn37SR2ZJugJ1xMvmAfiiCvhDHKfdQe7m2jYJu", "kewbz5",
            "F B2 R' D2 B R U D' R L' D' F' R2 D F2 B' "
                + "Lw2 Rw2 Uw2 Dw2 Bw2 Fw2"),
        Pattern(5, "Dot in a Dot", "AQmLk1OwiM9v1JveX4xoVjYb7uLkHbtL96BxZ-41oD", "kewbz5",
            "U D' R L' F B' U D' Uw Dw' Rw Lw' Fw Bw' Uw Dw'"),
        Pattern(5, "Dot in a Crosshair", "AQmLlCGlUJitQ8R2wC36gPhiRlZbzSNQpfzEX3I0wx", "kewbz5",
            "U D' R L' F B' U D' Uw Dw' Rw Lw' Fw Bw' Uw Dw' Lw2 Rw2 Uw2 Dw2 Bw2 Fw2"),
        Pattern(5, "Alternate Checkerboard", "AUGtEj2jjX2O6YHQcWcMeOJm0BUXusXvjAe7m2jYJu", "kewbz5",
            "U D' R L' F B' U D' Lw2 Rw2 Uw2 Dw2 Bw2 Fw2"),
        Pattern(5, "Double Checkerboard", "AUGtEEgNo9EoiJGTjPCwGpyXwQnoL5vQ8n8VhfW49u", "kewbz5",
            "U D' R L' F B' U D' Lw2 Rw2 Uw2 Dw2 Bw2 Fw2 L2 R2 F2 B2 D2 U2")
    }

}
