mod TestPatterns {

    use CubeSolve.Patterns
    use CubeSolve.Model.Cube
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
    ///
    /// The library's own identity function, not a copy of it.
    ///
    /// The assertions below compare a recorded `canonical` against what this
    /// returns for the algorithm that is supposed to produce it, so they check
    /// the data against the code that consumers will run. A second
    /// implementation here would let the two drift and still pass.
    ///
    def identityOf(c: Cube.Cube): String =
        Patterns.Standard.identify(c) |> Option.getWithDefault("not a cube")

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
        let all = Patterns.Standard.all();
        Assert.assertEqWithMsg(expected = 110, Vector.length(all),
            "the collection should hold 110 distinct patterns");
        let names = all |> Vector.map(Patterns.Standard.name) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(names), List.length(List.distinct(names)),
            "two patterns share a name");
        let ids = all |> Vector.map(Patterns.Standard.canonical) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(ids), List.length(List.distinct(ids)),
            "two patterns in the collection are the same pattern");

        all |> Vector.forEach(p -> {
            let name = Patterns.Standard.name(p);
            Assert.assertTrueWithMsg(
                Patterns.Standard.url(Patterns.Standard.source(p)) != "unknown",
                "'${name}' cites an unknown source '${Patterns.Standard.source(p)}'");

            let published = made(name, Patterns.Standard.notation(p));
            Assert.assertEqWithMsg(
                expected = Patterns.Standard.canonical(p), identityOf(published),
                "'${name}' does not reach its recorded pattern");
            Assert.assertEqWithMsg(
                expected = None, Validate.faultOf(published),
                "'${name}' reaches a state turning cannot");

            match Move.parse(Patterns.Standard.faceTurns(p)) {
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e,
                        "'${name}' half-turn form is not face turns")
                case Ok(ms) =>
                    Assert.assertTrueWithMsg(
                        List.forAll(m -> Vector.memberOf(m, Move.all()), ms),
                        "'${name}' uses something outside the face-turn alphabet")
            };
            let translated = made(name, Patterns.Standard.faceTurns(p));
            Assert.assertEqWithMsg(
                expected = Patterns.Standard.canonical(p), identityOf(translated),
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
        let all = Patterns.Standard.all();
        let named = n -> Vector.findLeft(p -> Patterns.Standard.name(p) == n, all);
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
                let twice = "${Patterns.Standard.faceTurns(p)} ${Patterns.Standard.faceTurns(p)}";
                Assert.assertTrueWithMsg(
                    Cube.isSolved(made("superflip twice", twice)),
                    "the superflip should be its own inverse")
        }

    /// Every 4x4x4 curated pattern algorithm parses and applies to a solved cube.
    @Test
    def fourByFourPatternsApplySoundly(): Unit \ Assert =
        let all = Patterns.Revenge.all();
        Vector.forEach(p -> {
            let res = Patterns.Revenge.cube(p);
            let msg = "4x4 pattern '${Patterns.Revenge.name(p)}' failed to apply";
            Assert.assertTrueWithMsg(Result.isOk(res), msg)
        }, all)

    /// Every 5x5x5 curated pattern algorithm parses and applies to a solved cube.
    @Test
    def fiveByFivePatternsApplySoundly(): Unit \ Assert =
        let all = Patterns.Professor.all();
        Vector.forEach(p -> {
            let res = Patterns.Professor.cube(p);
            let msg = "5x5 pattern '${Patterns.Professor.name(p)}' failed to apply";
            Assert.assertTrueWithMsg(Result.isOk(res), msg)
        }, all)

}
