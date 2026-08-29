mod TestPocketPatterns {

    use CubeSolve.Patterns
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Holding
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
    /// The smallest token over all 24 orientations: a pattern's identity.
    /// Computed by the library rather than copied here, so the recorded
    /// identities below are checked against the code consumers will run.
    def identityOf(c: Cube.Cube): String =
        Patterns.Pocket.identify(c) |> Option.getWithDefault("not a cube")

    /// The words the library re-holds a pocket cube by.
    def reorientations(): Vector[String] =
        Holding.reorientations() |> Vector.map(snd)

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

        let all = Patterns.Pocket.all();
        Assert.assertEqWithMsg(expected = 89, Vector.length(all),
            "the collection should hold 89 distinct patterns");
        let names = all |> Vector.map(Patterns.Pocket.name) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(names), List.length(List.distinct(names)),
            "two patterns share a name");
        let ids = all |> Vector.map(Patterns.Pocket.canonical) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(ids), List.length(List.distinct(ids)),
            "two patterns in the collection are the same pattern");

        all |> Vector.forEach(p -> {
            let name = Patterns.Pocket.name(p);
            Assert.assertTrueWithMsg(
                Patterns.Pocket.url(Patterns.Pocket.source(p)) != "unknown",
                "'${name}' cites an unknown source");
            let published = made(name, Patterns.Pocket.notation(p));
            Assert.assertEqWithMsg(
                expected = Patterns.Pocket.canonical(p), identityOf(published),
                "'${name}' does not reach its recorded pattern");
            Assert.assertEqWithMsg(
                expected = None, Validate.faultOf(published),
                "'${name}' reaches a state turning cannot");
            let shortest = made(name, Patterns.Pocket.optimal(p));
            Assert.assertEqWithMsg(
                expected = Patterns.Pocket.canonical(p), identityOf(shortest),
                "'${name}' shortest form makes a different pattern");
            Assert.assertTrueWithMsg(not Cube.isSolved(shortest),
                "'${name}' is the solved cube, not a pattern")
        })

}
