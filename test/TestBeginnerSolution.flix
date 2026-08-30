///
/// The beginner method, end to end as far as it goes.
///
/// The steps are tested individually elsewhere. What is left here is that they
/// compose: that each is handed what the last produced, that the whole thing
/// replays, and that a method which stops three rungs up says so rather than
/// returning a plan that quietly does less than its name suggests.
///
mod TestBeginnerSolution {

    use CubeSolve.Method.Beginner
    use CubeSolve.Method.Plan
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Holding

    ///
    /// Two scrambles, given as canonical tokens so the test starts where it
    /// means to without re-deriving them.
    ///
    /// One state, not the whole corpus. This test is about the stages composing
    /// -- each handed what the last produced, every prefix landing on its own
    /// rung -- and that is not more true of a harder cube. What the search costs
    /// on the corpus's worst state is gated in `TestTwoLayers`, against recorded
    /// node ceilings, where it belongs.
    def scrambles(): Vector[String] = Vector#{"AJmiz2F3jagE"}

    ///
    /// The plan runs, in order, and leaves the cube two layers solved.
    ///
    /// Replayed as one sequence, then judged by the ladder -- not by any
    /// solver's own coordinate, which is what the individual steps were steered
    /// by.
    ///
    /// Everything the orchestration must satisfy, on one set of tables.
    ///
    /// One test because the tables take about a hundred seconds to build and
    /// nothing shares them across `@Test` functions; three tests built them
    /// three times and cost the suite six minutes to prove the same things.
    /// Each property is its own function below and names itself when it fails.
    @Test
    def theBeginnerMethodKeepsItsPromises(): Unit \ Assert =
        match Beginner.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "the tables should build")
            case Ok(t)  =>
                stagesComposeAndLeaveTheCubeTwoLayersSolved(t);
                eachStageLeavesTheCubeAtItsOwnRung(t);
                anAlreadySolvedTwoLayersCostsNothing(t)
        }

    def stagesComposeAndLeaveTheCubeTwoLayersSolved(t: Beginner.Tables): Unit \ Assert =
        scrambles() |> Vector.forEach(token ->
            match Holding.ofToken(3, token) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "${token}")
                case Ok(c)  => check(t, token, c)
            })

    ///
    /// One cube: solved in stages, replayed, and judged.
    ///
    def check(t: Beginner.Tables, token: String, c: Cube.Cube): Unit \ Assert =
        match Beginner.solution(t, c) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "token ${token}")
            case Ok(p)  =>
                Assert.assertEq(expected = "Cross" :: "First layer" :: "Middle edges" :: Nil,
                    p#steps |> List.map(s -> s#label));
                match Cube.applyNotation(Plan.sequenceOf(p), c) {
                    case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "replaying")
                    case Ok(after) =>
                        Assert.assertTrueWithMsg(
                            Beginner.isComplete(Beginner.Stage.TwoLayers, after),
                            "${token}: the plan did not reach TwoLayers");
                        Assert.assertTrueWithMsg(Plan.layerTurns(p) > 0,
                            "${token}: a plan that spends no moves solved nothing")
                }
        }

    ///
    /// Each stage leaves the cube at the rung it is named for.
    ///
    /// Not merely "the end is right": a plan whose first step happened to solve
    /// two layers and whose others did nothing would pass the check above and be
    /// a lie about what a person should do. Every prefix is replayed and judged.
    ///
    def eachStageLeavesTheCubeAtItsOwnRung(t: Beginner.Tables): Unit \ Assert =
                match Holding.ofToken(3, "AJmiz2F3jagE") {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e, "decoding")
                    case Ok(c)  => match Beginner.solution(t, c) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solving")
                        case Ok(p)  => walk(c, p#steps,
                            Beginner.Stage.Cross :: Beginner.Stage.FirstLayer
                                :: Beginner.Stage.TwoLayers :: Nil)
                    }
                }

    ///
    /// Replay the steps one at a time, checking the rung after each.
    ///
    def walk(
        c: Cube.Cube,
        steps: List[Plan.Step],
        rungs: List[Beginner.Stage]
    ): Unit \ Assert =
        match (steps, rungs) {
            case (step :: moreSteps, rung :: moreRungs) =>
                match Cube.applyNotation(step#sequence, c) {
                    case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "replaying")
                    case Ok(after) =>
                        Assert.assertTrueWithMsg(Beginner.isComplete(rung, after),
                            "after '${step#label}' the cube should be at ${rung}, "
                                + "and is at ${Beginner.reached(after)}");
                        walk(after, moreSteps, moreRungs)
                }
            case _ => ()
        }

    ///
    /// A cube already two layers solved is answered with empty steps, not
    /// refused.
    ///
    def anAlreadySolvedTwoLayersCostsNothing(t: Beginner.Tables): Unit \ Assert =
                match Cube.solved(3) {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
                    case Ok(c)  => match Beginner.solution(t, c) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solving")
                        case Ok(p)  =>
                            Assert.assertEqWithMsg(expected = 0, Plan.layerTurns(p),
                                "a solved cube needs no moves");
                            Assert.assertEqWithMsg(expected = 3, List.length(p#steps),
                                "and still reports all three stages")
                    }
                }

}
