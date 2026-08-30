///
/// Curated published 4x4x4 patterns.
///
mod CubeSolve.Patterns.Revenge {

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
    pub def all(): Vector[Pattern] = Vector#{
        Pattern(
            "Rings",
            "BgCQSexUSGwOHTQEkFI-EZqGFHQ",
            "ruwix1",
            "B' M2 U2 M2 B F2 R U' R U R2 U R2 F' U F' Uw Lw Uw' Fw2 Dw Rw' Uw Fw Dw2 Rw2"
        ),
        Pattern(
            "Checkerboard",
            "AAAAAABQAAAAAAAgAAAAAACAAAA",
            "speedsolving",
            "Rw2 Lw2 U2 D2 Fw2 Bw2"
        ),
        Pattern(
            "Small Checkerboard",
            "AAAAAAAgAAAAAABQAAAAAACAAAA",
            "speedsolving",
            "r2 l2 u2 d2 f2 b2"
        ),
        Pattern(
            "Center Spots",
            "AAAAAAAQAAAAAAAgAAAAAAAAAAA",
            "speedsolving",
            "2R2 2L2 2U2 2D2 2F2 2B2"
        ),
        Pattern(
            "Crosses",
            "AAAAAABQAAAAAAAgAAAAAAAAAAA",
            "speedsolving",
            "R2 L2 U2 D2 F2 B2 2R2 2L2 2U2 2D2 2F2 2B2"
        ),
        Pattern(
            "Cube in a Cube",
            "BK0FI5AQ17JMuagtpkNY15TSzNA",
            "ruwix1",
            "Fw2 R2 Uw2 R2 Fw2 R2 Uw2 R2 Fw2 R2 Uw2 R2"
        )
    }

}
