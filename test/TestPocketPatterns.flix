mod TestPocketPatterns {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Move
    use CubeSolve.Model.Validate

    /// The cube `alg` makes from a solved 2x2x2.
    def made(what: String, alg: String): Cube.Cube \ Assert =
        match Cube.solved(2) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "${what}: '${alg}'");
                unreachable!()
        }

    /// The 24 ways of turning a 2x2x2 in space, as move sequences.
    ///
    /// A 2x2x2 has no centres, so nothing pins the frame: turning it in the hand
    /// moves pieces between slots while the colours stay with the pieces. That
    /// is what a move does and is not what conjugation does, so on this puzzle a
    /// whole-cube rotation really is a pair of moves.
    def reorientations(): Vector[String] = Vector#{
        "",
        "F B'",
        "R L'",
        "U D'",
        "F B' F B'",
        "F B' U D'",
        "R L' F B'",
        "R L' R L'",
        "R L' U D'",
        "U D' R L'",
        "U D' U D'",
        "F B' F B' F B'",
        "R L' F B' F B'",
        "R L' R L' F B'",
        "R L' R L' R L'",
        "R L' R L' U D'",
        "R L' U D' R L'",
        "R L' U D' U D'",
        "U D' R L' R L'",
        "U D' U D' U D'",
        "R L' R L' R L' U D'",
        "R L' R L' U D' R L'",
        "R L' U D' R L' R L'",
        "R L' U D' U D' U D'"
    }

    /// The smallest token over all 24 orientations: a pattern's identity.
    def identityOf(c: Cube.Cube): String =
        reorientations()
            |> Vector.map(w -> match Cube.applyNotation(w, c) {
                case Ok(x)  => Facelets.token(x) |> Result.getWithDefault("~")
                case Err(_) => "~"
            })
            |> Vector.foldLeft((best, t) -> if (t < best) t else best, "~~~~~~~~~~~~~~")

    /// Everything the 2x2x2 collection must satisfy, in one pass.
    ///
    /// Each pattern is analysed once, for the same reason as the 3x3x3's:
    /// establishing a pattern's identity means re-recording it from all 24
    /// orientations, and repeating that per property costs more than the rest
    /// of the suite.
    ///
    /// - **The reorientations really are the 24**, and each leaves the cube
    ///   looking solved while recording differently. If that list were wrong
    ///   every identity below would be computed against the wrong equivalence.
    /// - **The collection is complete and each pattern appears once.**
    /// - **Every published algorithm reaches the recorded pattern.**
    /// - **The recorded sequence makes the same pattern**, and no pattern is
    ///   the solved cube -- a sequence that cancels is not a pattern.
    @Test
    def theCollectionIsSoundCompleteAndDistinct(): Unit \ Assert =
        Assert.assertEq(expected = 24, Vector.length(reorientations()));
        let held = reorientations()
            |> Vector.map(w -> Facelets.token(made("reorientation", w))
                                   |> Result.getWithDefault("?"))
            |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = 24, List.length(List.distinct(held)),
            "the 24 reorientations should be distinct recordings of a solved cube");

        let all = PocketPatternFixtures.all();
        Assert.assertEqWithMsg(expected = 89, Vector.length(all),
            "the collection should hold 89 distinct patterns");
        let names = all |> Vector.map(PocketPatternFixtures.name) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(names), List.length(List.distinct(names)),
            "two patterns share a name");
        let ids = all |> Vector.map(PocketPatternFixtures.canonical) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(ids), List.length(List.distinct(ids)),
            "two patterns in the collection are the same pattern");

        all |> Vector.forEach(p -> {
            let name = PocketPatternFixtures.name(p);
            Assert.assertTrueWithMsg(
                PocketPatternFixtures.url(PocketPatternFixtures.source(p)) != "unknown",
                "'${name}' cites an unknown source");
            let published = made(name, PocketPatternFixtures.notation(p));
            Assert.assertEqWithMsg(
                expected = PocketPatternFixtures.canonical(p), identityOf(published),
                "'${name}' does not reach its recorded pattern");
            Assert.assertEqWithMsg(
                expected = None, Validate.faultOf(published),
                "'${name}' reaches a state turning cannot");
            let shortest = made(name, PocketPatternFixtures.optimal(p));
            Assert.assertEqWithMsg(
                expected = PocketPatternFixtures.canonical(p), identityOf(shortest),
                "'${name}' shortest form makes a different pattern");
            Assert.assertTrueWithMsg(not Cube.isSolved(shortest),
                "'${name}' is the solved cube, not a pattern")
        })

}
