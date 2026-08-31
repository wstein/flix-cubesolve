///
/// CFOP, end to end.
///
/// The steps are tested individually elsewhere: the cross and two-layer
/// searches in their own tests, OLL and PLL against their case tables. What is
/// left here is that they compose -- each step handed what the last produced,
/// the whole thing replaying to a solved cube -- and that the method reaches the
/// first two layers in one searched step where the beginner method takes two.
///
mod TestCfopSolution {

    use CubeSolve.Solve.IdaStar

    use CubeSolve.Method.Beginner
    use CubeSolve.Method.Cfop
    use CubeSolve.Method.Plan
    use CubeSolve.Method.Profile.Profile.SourceFirst
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Holding
    use CubeSolve.Solve.TwoLayers

    ///
    /// The same scramble the beginner test uses, as a canonical token.
    ///
    /// Deliberately the same one: the two methods reach the same place by
    /// different routes, and comparing them on the same cube is the only way
    /// that comparison means anything.
    ///
    def scramble(): String = "AJmiz2F3jagE"

    ///
    /// Everything the orchestration must satisfy, on one set of tables.
    ///
    /// One test for the reason `TestBeginnerSolution` gives: the tables take
    /// about eighty seconds to build and nothing shares them across `@Test`
    /// functions.
    ///
    @Test
    def cfopKeepsItsPromises(): Unit \ Assert + IO =
        if (Slow.skip("TestCfopSolution.cfopKeepsItsPromises",
                "builds the first-two-layer tables and solves whole cubes"))
            ()
        else {
            match (Cfop.build(), Holding.ofToken(3, scramble())) {
                case (Err(e), _) =>
                    Assert.assertEqWithMsg(expected = "", e, "the tables should build")
                case (_, Err(e)) =>
                    Assert.assertEqWithMsg(expected = "", e, "the scramble should decode")
                case (Ok(t), Ok(c)) =>
                    fourStagesComposeAndSolveTheCube(t, c);
                    f2lReachesTheSameRungTheBeginnerMethodDoes(t, c)
            }
        }

    ///
    /// Cross, F2L, OLL, PLL -- and a cube that is solved at the end of them.
    ///
    def fourStagesComposeAndSolveTheCube(
        t: TwoLayers.Tables,
        c: Cube.Cube
    ): Unit \ Assert =
        match Cfop.solution(t, SourceFirst, c, IdaStar.unbounded()) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "token ${scramble()}")
            case Ok(p)  =>
                let labels = p#steps |> List.map(s -> s#label);
                Assert.assertEqWithMsg(expected = 4, List.length(labels),
                    "cross, F2L, OLL, PLL: ${labels}");
                Assert.assertTrueWithMsg(
                    List.take(2, labels) == "Cross" :: "F2L" :: Nil,
                    "the searched stages come first: ${labels}");
                match Cube.applyNotation(Plan.sequenceOf(p), c) {
                    case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "replaying")
                    case Ok(after) =>
                        Assert.assertTrueWithMsg(Cube.isSolved(after),
                            "${scramble()}: the plan did not solve the cube");
                        Assert.assertTrueWithMsg(Plan.layerTurns(p) > 0,
                            "${scramble()}: a plan that spends no moves solved nothing")
                }
        }

    ///
    /// After cross and F2L the cube is at `TwoLayers` on the beginner ladder.
    ///
    /// The point of the check is that the two methods agree about where the
    /// first two layers end. CFOP gets there in one searched step and the
    /// beginner method in two; if the ladder said one of them had not arrived,
    /// one of the two would be wrong about what it had finished.
    ///
    def f2lReachesTheSameRungTheBeginnerMethodDoes(
        t: TwoLayers.Tables,
        c: Cube.Cube
    ): Unit \ Assert =
        match Cfop.solution(t, SourceFirst, c, IdaStar.unbounded()) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "token ${scramble()}")
            case Ok(p)  =>
                let searched = p#steps |> List.take(2) |> List.map(s -> s#sequence);
                match Cube.applyNotation(String.intercalate(" ", searched), c) {
                    case Err(e)      => Assert.assertEqWithMsg(expected = "", e, "replaying")
                    case Ok(afterF2l) =>
                        Assert.assertTrueWithMsg(
                            Beginner.isComplete(Beginner.Stage.TwoLayers, afterF2l),
                            "cross and F2L left the cube at "
                                + "${Beginner.reached(afterF2l)}, not TwoLayers")
                }
        }
}
