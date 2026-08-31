mod TestPocketSearchLimits {

    use CubeSolve.Solve.IdaStar
    use CubeSolve.Table

    /// The two ends of the range, and the refusal in between.
    ///
    /// A depth too small to hold any solution is reported as exhaustion naming
    /// the depth -- not a hang, and not a wrong answer. And the solved state
    /// needs no moves, rather than returning a pair that cancels.
    @Test
    def theEdgesOfTheSearchAreReportedProperly(): Unit \ Assert =
        let t = PocketSearchTestSupport.tables();
        PocketSearchTestSupport.deepestStates(t) |> Vector.take(1) |> Vector.forEach(s ->
            match IdaStar.search(CubeSolve.Solve.Pocket.phaseOf(t), s, 5, IdaStar.unbounded()) {
                case Ok(_)  => Assert.assertTrueWithMsg(false, "state ${s} needs 11 moves")
                case Err(e) => Assert.assertTrueWithMsg(
                    String.contains(substr = "5", e),
                    "the refusal should name the depth reached, but said: ${e}")
            });
        match CubeSolve.Solve.Pocket.solutionForState(t, Table.Pocket.solvedIndex()) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved is solvable")
            case Ok(ms) => Assert.assertEq(expected = Nil, ms)
        }

    /// A search stops at its node budget and says so.
    ///
    /// This is what keeps a wide search from looking like a hung program. The
    /// budget is a node count rather than a time limit so that the stopping
    /// point is reproducible: the same state and the same budget stop in the
    /// same place on every machine, which a clock could not promise.
    @Test
    def aSearchStopsAtItsNodeBudgetAndSaysSo(): Unit \ Assert =
        let t = PocketSearchTestSupport.tables();
        let state = 1234;
        match IdaStar.search(CubeSolve.Solve.Pocket.phaseOf(t), state, 11, 1i64) {
            case Ok(_) => Assert.assertTrueWithMsg(false,
                "a budget of one node should not have solved it")
            case Err(why) =>
                Assert.assertTrueWithMsg(String.contains(substr = "exhausted", why),
                    "the failure should name exhaustion, not a depth: ${why}");
                Assert.assertTrueWithMsg(String.contains(substr = "nodes", why),
                    "and should report the node count: ${why}")
        }

    /// A budget large enough changes nothing about the answer.
    ///
    /// A safety net must not become a quality constraint: the same search, given
    /// room, returns exactly the solution it returned unbounded.
    @Test
    def aGenerousBudgetLeavesTheAnswerAlone(): Unit \ Assert =
        let t = PocketSearchTestSupport.tables();
        let phase = CubeSolve.Solve.Pocket.phaseOf(t);
        Vector.range(0, 40) |> Vector.forEach(s ->
            match (IdaStar.search(phase, s, 11, IdaStar.unbounded()),
                   IdaStar.search(phase, s, 11, 100_000_000i64)) {
                case (Ok(a), Ok(b)) =>
                    Assert.assertEqWithMsg(expected = IdaStar.moves(a), IdaStar.moves(b),
                        "state ${s} answered differently under a budget")
                case (Err(_), Err(_)) => ()
                case _ => Assert.assertTrueWithMsg(false,
                    "state ${s}: one found a solution and the other did not")
            })

}
