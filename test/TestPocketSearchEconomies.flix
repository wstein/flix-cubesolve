mod TestPocketSearchEconomies {

    use CubeSolve.Solve.IdaStar
    use CubeSolve.Table

    /// Both of the search's economies cut work without changing an answer.
    ///
    /// That pairing is the point. A pruning rule that dropped a necessary move
    /// would also visit fewer nodes, and a heuristic that overestimated would
    /// too -- while returning a longer solution or none. Neither saving is
    /// worth anything unless the answers are unchanged, so both are asserted
    /// together.
    @Test
    def theSearchsEconomiesCutNodesWithoutChangingAnswers(): Unit \ Assert =
        let t = PocketSearchTestSupport.tables();
        let d = Table.Pocket.distanceTable(t);
        let pruned = CubeSolve.Solve.Pocket.phaseOf(t);

        // Move pruning, against the same phase with the rule switched off.
        // Six moves deep: enough for pruning to matter, shallow enough that the
        // unpruned search finishes at all.
        let unpruned = CubeSolve.Solve.Pocket.unprunedPhaseOf(t);
        Vector.range(0, 400000)
            |> Vector.filter(i -> Table.get(i, d) == 6)
            |> Vector.take(4)
            |> Vector.forEach(s ->
                compareSearches(
                    { better = pruned, worse = unpruned, what = "move pruning" },
                    s, 6, 1i64));

        // The second projection, against orientation alone, on the states where
        // it matters most. Measured at about 226,000 nodes against about
        // 2,500,000; asserted as a factor of four so the test records the
        // finding without tripping on ordinary variation.
        let orientationOnly = CubeSolve.Solve.Pocket.singleProjectionPhaseOf(t, true);
        PocketSearchTestSupport.deepestStates(t) |> Vector.take(2) |> Vector.forEach(s ->
            compareSearches(
                { better = pruned, worse = orientationOnly, what = "the second projection" },
                s, 11, 4i64))

    /// Asserts that `better` finds the same length as `worse` for `state`, and
    /// visits at least `factor` times fewer nodes doing it.
    def compareSearches(
        phases: {
            better = CubeSolve.Solve.IdaStar.Phase[Int32],
            worse = CubeSolve.Solve.IdaStar.Phase[Int32],
            what = String
        },
        state: Int32,
        depth: Int32,
        factor: Int64
    ): Unit \ Assert =
        let what = phases#what;
        match (
            IdaStar.search(phases#better, state, depth, IdaStar.unbounded()),
            IdaStar.search(phases#worse, state, depth, IdaStar.unbounded())
        ) {
            case (Ok(a), Ok(b)) =>
                Assert.assertEqWithMsg(
                    expected = IdaStar.length(b), IdaStar.length(a),
                    "${what} changed the solution length for state ${state}");
                Assert.assertTrueWithMsg(
                    IdaStar.nodes(a) * factor < IdaStar.nodes(b),
                    "${what} should save at least ${factor}x for state ${state}, "
                        + "but visited ${IdaStar.nodes(a)} against ${IdaStar.nodes(b)}")
            case _ => Assert.assertTrueWithMsg(false,
                "both searches should succeed for state ${state}")
        }

}
