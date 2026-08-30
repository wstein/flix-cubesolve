///
/// Finishing a last layer in two named steps.
///
/// The steps are tested on their own elsewhere, exhaustively. What is left here
/// is that they compose: that the second is handed what the first produced, that
/// the two together solve, and that a step which is not needed is reported
/// rather than dropped.
///
mod TestMethodLastLayer {

    use CubeSolve.Method
    use CubeSolve.Method.Oll
    use CubeSolve.Method.Pll
    use CubeSolve.Method.Profile.Profile.SourceFirst
    use CubeSolve.Model.Cube

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// A cube needing exactly this OLL case and then this PLL case.
    ///
    /// Built backwards from solved: undo the permutation, then undo the
    /// orientation. Running the two forwards is what the answer has to be.
    ///
    def needing(oll: Oll.Case, pll: Pll.Case): Cube.Cube \ Assert =
        made("(${Pll.algorithm(pll)})' (${Oll.algorithm(oll)})'")

    ///
    /// A sample of case pairs, solved in two stages, each replayed.
    ///
    /// Every fifty-ninth pair of the 57 by 21, which walks both lists out of
    /// step and so covers each OLL case and each PLL case several times without
    /// running all 1,197.
    ///
    @Test
    def bothStepsRunAndTheirAnswerSolves(): Unit \ Assert =
        Vector.range(0, 40) |> Vector.forEach(n -> {
            let oll = Vector.get(Int32.modulo(n * 7, 57), Oll.all());
            let pll = Vector.get(Int32.modulo(n * 5, 21), Pll.all());
            let c = needing(oll, pll);
            match Method.lastLayer(SourceFirst, c) {
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e,
                        "'${Oll.name(oll)}' then '${Pll.name(pll)}'")
                case Ok(answer) =>
                    Assert.assertEqWithMsg(expected = 2, List.length(answer#stages),
                        "an answer has an OLL stage and a PLL stage");
                    match Cube.applyNotation(Method.sequenceOf(answer), c) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "replaying")
                        case Ok(after) =>
                            Assert.assertTrueWithMsg(Cube.isSolved(after),
                                "'${Oll.name(oll)}' then '${Pll.name(pll)}': "
                                    + "'${Method.sequenceOf(answer)}' does not solve it")
                    };
                    let counted = answer#stages
                        |> List.foldLeft((t, s) -> t + s#layerTurns, 0);
                    Assert.assertEqWithMsg(expected = counted, answer#layerTurns,
                        "the total should be what the stages add up to")
            }
        })

    ///
    /// The stages are named, and in the order they are done.
    ///
    @Test
    def theStagesAreNamedOllThenPll(): Unit \ Assert =
        let firstOll = Vector.get(0, Oll.all());
        let firstPll = Vector.get(0, Pll.all());
        let c = needing(firstOll, firstPll);
        match Method.lastLayer(SourceFirst, c) {
            case Err(e)       => Assert.assertEqWithMsg(expected = "", e, "a two-stage cube")
            case Ok(answer)   =>
                Assert.assertEq(expected = "OLL" :: "PLL" :: Nil,
                    answer#stages |> List.map(s -> s#step))
        }

    ///
    /// A step that is not needed is reported as a skip, not dropped.
    ///
    /// Both kinds: a layer that arrives oriented has no OLL case, and a cube
    /// that arrives solved has no PLL case. Reporting fewer stages would leave
    /// a reader counting to work out which one went missing.
    ///
    @Test
    def aStepThatIsNotNeededIsReportedAsASkip(): Unit \ Assert =
        // Oriented already: only PLL is left.
        let pllOnly = made("(${Pll.algorithm(Vector.get(0, Pll.all()))})'");
        match Method.lastLayer(SourceFirst, pllOnly) {
            case Err(e)     => Assert.assertEqWithMsg(expected = "", e, "a PLL-only cube")
            case Ok(answer) =>
                match answer#stages {
                    case first :: second :: Nil =>
                        Assert.assertEqWithMsg(expected = "skip", first#caseName,
                            "OLL should be a skip");
                        Assert.assertTrue(String.isEmpty(first#sequence));
                        Assert.assertTrueWithMsg(
                            String.contains(substr = "arrived oriented", first#note),
                            "the skip should say why: ${first#note}");
                        Assert.assertNeq(unexpected = "skip", second#caseName)
                    case _ => Assert.assertTrueWithMsg(false, "two stages expected")
                }
        };
        // Solved already: both are skips, and the answer costs nothing.
        match Method.lastLayer(SourceFirst, made("")) {
            case Err(e)     => Assert.assertEqWithMsg(expected = "", e, "a solved cube")
            case Ok(answer) =>
                Assert.assertEqWithMsg(expected = 0, answer#layerTurns,
                    "a solved cube needs no moves");
                Assert.assertTrue(String.isEmpty(Method.sequenceOf(answer)));
                answer#stages |> List.forEach(s ->
                    Assert.assertEqWithMsg(expected = "skip", s#caseName,
                        "${s#step} should be a skip"))
        }

    ///
    /// A cube whose first two layers are unsolved is refused, with the reason
    /// the steps themselves would give.
    ///
    @Test
    def anUnfinishedF2lIsRefused(): Unit \ Assert =
        Vector#{"R", "R U R' U' F2 L D B' R2 F"} |> Vector.forEach(alg ->
            match Method.lastLayer(SourceFirst, made(alg)) {
                case Ok(_)    =>
                    Assert.assertTrueWithMsg(false, "'${alg}' has no last layer to finish")
                case Err(why) =>
                    Assert.assertTrueWithMsg(String.contains(substr = "first two layers", why),
                        "'${alg}' should be refused for its F2L, not: ${why}")
            })

}
