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
    pub def all(): Vector[Pattern] = Vector#{
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

}
