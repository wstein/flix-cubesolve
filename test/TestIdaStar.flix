mod TestIdaStar {

    use CubeSolve.Model.Cube
    use CubeSolve.Solve.IdaStar
    use CubeSolve.Table
    use CubeSolve.Table.Pocket

    /// Every 2x2x2 table.
    def tables(): Table.Pocket.Tables \ Assert =
        match Table.Pocket.build() {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    /// Checks that the search returns a solution of exactly the oracle's
    /// distance for `state`, and that replaying it really solves the cube.
    def assertOptimal(t: Table.Pocket.Tables, state: Int32): Unit \ Assert =
        let exact = Table.get(state, Table.Pocket.distanceTable(t));
        match CubeSolve.Solve.Pocket.solutionForState(t, state) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "state ${state}")
            case Ok(ms) =>
                Assert.assertEqWithMsg(
                    expected = exact, List.length(ms),
                    "state ${state} has distance ${exact} but the search returned "
                        + "${List.length(ms)} moves");
                let replayed = Table.Pocket.decode(state)
                    |> Result.flatMap(c -> Cube.applyAll(ms, c))
                    |> Result.map(Cube.isSolved);
                Assert.assertEqWithMsg(
                    expected = Ok(true), replayed,
                    "the solution for state ${state} did not replay to solved")
        }

    /// The states at exactly distance 11 -- the deepest, and the worst case for
    /// the search. There are 2,644 of them.
    def deepestStates(t: Table.Pocket.Tables): Vector[Int32] =
        let d = Table.Pocket.distanceTable(t);
        Vector.range(0, Table.Pocket.stateCount())
            |> Vector.filter(i -> Table.get(i, d) == 11)

    // ---------- optimality, stratified by measured cost ----------

    /// Optimality over a stratification chosen from measurement, not taste.
    ///
    /// Verifying optimality exhaustively would run a search per state. Measured
    /// on this implementation the deepest states cost about 226,000 nodes each,
    /// so all 2,644 of them alone would be roughly 6 x 10^8 nodes and some
    /// three minutes -- and the full 3,674,160 would be hours. That is a
    /// nightly job, not a gate, and pretending otherwise would mean a gate
    /// nobody ever lets finish.
    ///
    /// So: exhaustive where the class is small, sampled where it is not, and
    /// the split named rather than left implicit.
    ///
    /// - **Exhaustive** over every state within four moves, all 2,232 of them.
    /// - **A fixed stride** across the whole space, covering every distance
    ///   class in proportion to its size. A stride rather than a random sample
    ///   because it reproduces without carrying a seed, and because the
    ///   coordinate's ordering has nothing to do with distance.
    /// - **The deepest class sampled**, which is where the search works
    ///   hardest.
    ///
    /// Every solution is also replayed through the model, so a length that
    /// matches the oracle but does not actually solve the cube fails here.
    @Test
    def theStratifiedSampleIsSolvedOptimally(): Unit \ Assert =
        let t = tables();
        let d = Table.Pocket.distanceTable(t);
        let shallow = Vector.range(0, Table.Pocket.stateCount())
            |> Vector.filter(i -> Table.get(i, d) <= 4);
        Assert.assertEqWithMsg(expected = 2232, Vector.length(shallow),
            "the classes within four moves should hold 2,232 states");
        shallow |> Vector.forEach(s -> assertOptimal(t, s));

        let stride = 3673;
        Vector.range(0, 600) |> Vector.forEach(step ->
            assertOptimal(t, Int32.modulo(step * stride + 7, Table.Pocket.stateCount())));

        let deepest = deepestStates(t);
        Assert.assertEqWithMsg(expected = 2644, Vector.length(deepest),
            "there should be 2,644 states at distance 11");
        deepest |> Vector.take(60) |> Vector.forEach(s -> assertOptimal(t, s))

    // ---------- what the pruning and the second heuristic are worth ----------

    /// Both of the search's economies cut work without changing an answer.
    ///
    /// That pairing is the point. A pruning rule that dropped a necessary move
    /// would also visit fewer nodes, and a heuristic that overestimated would
    /// too -- while returning a longer solution or none. Neither saving is
    /// worth anything unless the answers are unchanged, so both are asserted
    /// together.
    @Test
    def theSearchsEconomiesCutNodesWithoutChangingAnswers(): Unit \ Assert =
        let t = tables();
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
        deepestStates(t) |> Vector.take(2) |> Vector.forEach(s ->
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
            case _ =>
                Assert.assertTrueWithMsg(false,
                    "both searches should succeed for state ${state}")
        }

    // ---------- the edges ----------

    /// The two ends of the range, and the refusal in between.
    ///
    /// A depth too small to hold any solution is reported as exhaustion naming
    /// the depth -- not a hang, and not a wrong answer. And the solved state
    /// needs no moves, rather than returning a pair that cancels.
    ///
    /// The end-to-end check that a cube scrambled through the model is solved
    /// back through it lives in `TestScramble`, which already works in the
    /// model's terms.
    @Test
    def theEdgesOfTheSearchAreReportedProperly(): Unit \ Assert =
        let t = tables();

        deepestStates(t) |> Vector.take(1) |> Vector.forEach(s ->
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



    ///
    /// A search stops at its node budget and says so.
    ///
    /// This is what keeps a wide search from looking like a hung program. The
    /// budget is a node count rather than a time limit so that the stopping
    /// point is reproducible: the same state and the same budget stop in the
    /// same place on every machine, which a clock could not promise.
    ///
    @Test
    def aSearchStopsAtItsNodeBudgetAndSaysSo(): Unit \ Assert =
        match CubeSolve.Table.Pocket.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "tables")
            case Ok(t)  =>
                // A state far enough out that one node cannot reach it.
                let state = 1234;
                match IdaStar.search(CubeSolve.Solve.Pocket.phaseOf(t), state, 11, 1i64) {
                    case Ok(_) =>
                        Assert.assertTrueWithMsg(false,
                            "a budget of one node should not have solved it")
                    case Err(why) =>
                        Assert.assertTrueWithMsg(String.contains(substr = "exhausted", why),
                            "the failure should name exhaustion, not a depth: ${why}");
                        Assert.assertTrueWithMsg(String.contains(substr = "nodes", why),
                            "and should report the node count: ${why}")
                }
        }

    ///
    /// A budget large enough changes nothing about the answer.
    ///
    /// A safety net must not become a quality constraint: the same search, given
    /// room, returns exactly the solution it returned unbounded.
    ///
    @Test
    def aGenerousBudgetLeavesTheAnswerAlone(): Unit \ Assert =
        match CubeSolve.Table.Pocket.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "tables")
            case Ok(t)  =>
                let phase = CubeSolve.Solve.Pocket.phaseOf(t);
                Vector.range(0, 40) |> Vector.forEach(s ->
                    match (IdaStar.search(phase, s, 11, IdaStar.unbounded()),
                           IdaStar.search(phase, s, 11, 100_000_000i64)) {
                        case (Ok(a), Ok(b)) =>
                            Assert.assertEqWithMsg(expected = IdaStar.moves(a),
                                IdaStar.moves(b),
                                "state ${s} answered differently under a budget")
                        case (Err(_), Err(_)) => ()
                        case _ =>
                            Assert.assertTrueWithMsg(false,
                                "state ${s}: one found a solution and the other did not")
                    })
        }

}
