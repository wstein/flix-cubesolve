///
/// Curated published 5x5x5 patterns.
///
mod CubeSolve.Patterns.Professor {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Rotation
    use CubeSolve.Patterns.Professor.Pattern.Pattern

    ///
    /// A 5x5x5 pattern: its name, canonical identity, source collection, and notation.
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
        Cube.solved(5) |> Result.flatMap(c -> Cube.applyNotation(notation(p), c))

    ///
    /// Every curated 5x5x5 pattern in the collection.
    ///
    pub def all(): Vector[Pattern] =
        Vector.append(curated(), kewbz())

    def curated(): Vector[Pattern] = Vector#{
        Pattern(
            "Nested Squares",
            "FAMMxrnAODxtJQkle0CmnHZ3c8_Wiv8A78pj8T9iIN",
            "ruwix1",
            "2-4Fw' 2-4Rw2 2F2 2-4Rw2 2-4Dw2 2-3Fw2 2-4Dw S2 2-4Dw "
                + "2-3Fw L 2B' 2R2 2B L' 2B' Rw2 S' 2L2 S R2 S' 2L2 S"
        ),
        Pattern(
            "Center Dots",
            "AAAAAAAQAAAAAAAgAAAAAAAAAAA",
            "speedsolving",
            "M E M' E'"
        ),
        Pattern(
            "Checkerboard",
            "AAAAAABQAAAAAAAgAAAAAACAAAA",
            "speedsolving",
            "2R2 2L2 2U2 2D2 2F2 2B2 M2 E2 S2 R2 L2 U2 D2 F2 B2"
        ),
        Pattern(
            "Crosses",
            "AAAAAAAQAAAAAAAgAAAAAACAAAA",
            "speedsolving",
            "2R2 2L2 2U2 2D2 2F2 2B2 M2 E2 S2"
        ),
        Pattern(
            "Diagonal Stripes",
            "AAAAAABQAAAAAAAgAAAAAAAAAAA",
            "speedsolving",
            "2R2 2L2 2U2 2D2 2F2 2B2"
        )
    }

    def kewbz(): Vector[Pattern] =
        Vector.append(kewbz1(), kewbz2())

    def kewbz1(): Vector[Pattern] = Vector#{
        Pattern(
            "Kewbz Checkerboard",
            "DktI-pArB2Jt1Vvz8NWYrqTZd5EkLFlm_WQfdTSDdu",
            "kewbz5",
            "Rw2 Lw2 Uw2 D2 Dw2 B2 Bw2 F2 Fw2"
        ),
        Pattern(
            "Tri-Checkerboard",
            "AAAAApDI7p3NmLKwwTrSByBrnOZqzGfRRyCMxGwx8z",
            "kewbz5",
            "F B2 R' D2 B R U D' R L' D' F' R2 D F2 B' "
                + "Fw Bw2 Rw' Dw2 Bw Rw Uw Dw' Rw Lw' Dw' Fw' Rw2 Dw Fw2 Bw'"
        ),
        Pattern(
            "Kewbz Superflip",
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACYTqPvFoq",
            "kewbz5",
            "(m' U)x4 (x y') (m' U)x4 (x y') (m' U)x4 (x y') "
                + "(M' Uw)x4 (x y') (M' Uw)x4 (x y') (M' Uw)x4"
        ),
        Pattern(
            "Square in a Cube",
            "AUGtEEgNo9EmSZCUbOTgD0uCqBYMiYgE8OBCTp0QoA",
            "kewbz5",
            "U D' R L' F B' U D'"
        ),
        Pattern(
            "Flipped Edges",
            "AAAAAIhlX3EwhvbN0pEDLnD-YCzV2zS02eBCTp0QoA",
            "kewbz5",
            "F B2 R' D2 B R U D' R L' D' F' R2 D F2 B'"
        )
    }

    def kewbz2(): Vector[Pattern] = Vector#{
        Pattern(
            "Flipped Edge Checkerboard",
            "AAAAAn37SR2ZJugJ1xMvmAfiiCvhDHKfdQe7m2jYJu",
            "kewbz5",
            "F B2 R' D2 B R U D' R L' D' F' R2 D F2 B' Lw2 Rw2 Uw2 Dw2 Bw2 Fw2"
        ),
        Pattern(
            "Dot in a Dot",
            "AQmLk1OwiM9v1JveX4xoVjYb7uLkHbtL96BxZ-41oD",
            "kewbz5",
            "U D' R L' F B' U D' Uw Dw' Rw Lw' Fw Bw' Uw Dw'"
        ),
        Pattern(
            "Dot in a Crosshair",
            "AQmLlCGlUJitQ8R2wC36gPhiRlZbzSNQpfzEX3I0wx",
            "kewbz5",
            "U D' R L' F B' U D' Uw Dw' Rw Lw' Fw Bw' Uw Dw' Lw2 Rw2 Uw2 Dw2 Bw2 Fw2"
        ),
        Pattern(
            "Alternate Checkerboard",
            "AUGtEj2jjX2O6YHQcWcMeOJm0BUXusXvjAe7m2jYJu",
            "kewbz5",
            "U D' R L' F B' U D' Lw2 Rw2 Uw2 Dw2 Bw2 Fw2"
        ),
        Pattern(
            "Double Checkerboard",
            "AUGtEEgNo9EoiJGTjPCwGpyXwQnoL5vQ8n8VhfW49u",
            "kewbz5",
            "U D' R L' F B' U D' Lw2 Rw2 Uw2 Dw2 Bw2 Fw2 L2 R2 F2 B2 D2 U2"
        )
    }

}
