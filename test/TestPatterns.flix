mod TestPatterns {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Move
    use CubeSolve.Model.Rotation
    use CubeSolve.Model.Validate

    /// The cube `alg` makes from solved, failing the test if it does not parse.
    def made(what: String, alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "${what}: '${alg}'");
                unreachable!()
        }

    /// The smallest token over all 24 ways of holding `c`.
    ///
    /// This is a pattern's identity. Two algorithms make the same pattern when
    /// they reach the same state up to how the cube is held, and comparing raw
    /// tokens would call two orientations of one pattern different.
    def identityOf(c: Cube.Cube): String =
        Rotation.all()
            |> Vector.map(r -> Facelets.token(Cube.conjugate(r, c))
                                   |> Result.getWithDefault("~"))
            |> Vector.foldLeft((best, t) -> if (t < best) t else best, "~~~~~~~~~~~~~~")

    /// Everything the 3x3x3 collection must satisfy, in one pass.
    ///
    /// Each pattern is analysed once: working out a pattern's identity means
    /// re-recording it from all 24 orientations, and doing that separately in
    /// six tests cost more than the rest of the suite put together.
    ///
    /// - **The collection is complete and each pattern appears once**, by name,
    ///   by state, and with a source that resolves.
    /// - **Every published algorithm reaches the state recorded for it**, and
    ///   leaves a cube turning can reach.
    /// - **The half-turn form uses face turns only.** A stray `M` here would be
    ///   a transcription that never went through the solver.
    /// - **It makes the same pattern**, and leaves the cube upright, which the
    ///   published algorithm usually does not.
    @Test
    def theCollectionIsSoundCompleteAndTranslated(): Unit \ Assert =
        let all = PatternFixtures.all();
        Assert.assertEqWithMsg(expected = 110, Vector.length(all),
            "the collection should hold 110 distinct patterns");
        let names = all |> Vector.map(PatternFixtures.name) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(names), List.length(List.distinct(names)),
            "two patterns share a name");
        let ids = all |> Vector.map(PatternFixtures.canonical) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(ids), List.length(List.distinct(ids)),
            "two patterns in the collection are the same pattern");

        all |> Vector.forEach(p -> {
            let name = PatternFixtures.name(p);
            Assert.assertTrueWithMsg(
                PatternFixtures.url(PatternFixtures.source(p)) != "unknown",
                "'${name}' cites an unknown source '${PatternFixtures.source(p)}'");

            let published = made(name, PatternFixtures.notation(p));
            Assert.assertEqWithMsg(
                expected = PatternFixtures.canonical(p), identityOf(published),
                "'${name}' does not reach its recorded pattern");
            Assert.assertEqWithMsg(
                expected = None, Validate.faultOf(published),
                "'${name}' reaches a state turning cannot");

            match Move.parse(PatternFixtures.htm(p)) {
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e,
                        "'${name}' half-turn form is not face turns")
                case Ok(ms) =>
                    Assert.assertTrueWithMsg(
                        List.forAll(m -> Vector.memberOf(m, Move.all()), ms),
                        "'${name}' uses something outside the face-turn alphabet")
            };
            let translated = made(name, PatternFixtures.htm(p));
            Assert.assertEqWithMsg(
                expected = PatternFixtures.canonical(p), identityOf(translated),
                "'${name}' half-turn form makes a different pattern");
            Assert.assertEqWithMsg(
                expected = Rotation.identity(), Cube.orientation(translated),
                "'${name}' half-turn form rotated the cube")
        })

    /// A few patterns everyone knows, pinned by the name this collection uses.
    ///
    /// Where a pattern appears in more than one source the speedsolving name is
    /// kept, so the checkerboard is `Pons Asinorum` and not ruwix's `The easy
    /// checkerboard`. Pinning them catches a regeneration that silently changed
    /// which source wins.
    @Test
    def thePatternsEveryoneKnowsAreHereUnderTheirSpeedsolvingNames(): Unit \ Assert =
        let all = PatternFixtures.all();
        let named = n -> Vector.findLeft(p -> PatternFixtures.name(p) == n, all);
        List.forEach(n ->
            Assert.assertTrueWithMsg(Option.nonEmpty(named(n)),
                "the collection is missing '${n}'"),
            "Superflip" :: "Pons Asinorum" :: "6-Spot" :: "4-Spot"
                :: "Two-face checkerboard" :: "Cube in the cube" :: "Tetris"
                :: "4 crosses" :: "4 crosses (second list)" :: Nil);
        List.forEach(n ->
            Assert.assertTrueWithMsg(Option.isEmpty(named(n)),
                "'${n}' is a ruwix name for a pattern speedsolving already names"),
            "The Superflip" :: "The easy checkerboard" :: "Six spots"
                :: "Four spots" :: "Facing checkerboards" :: Nil);
        match named("Superflip") {
            case None    => Assert.assertTrueWithMsg(false, "no superflip")
            case Some(p) =>
                let twice = "${PatternFixtures.htm(p)} ${PatternFixtures.htm(p)}";
                Assert.assertTrueWithMsg(
                    Cube.isSolved(made("superflip twice", twice)),
                    "the superflip should be its own inverse")
        }

}
