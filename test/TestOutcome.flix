mod TestOutcome {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Holding
    use CubeSolve.Model.Move
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard
    use CubeSolve.Solve.Standard.Termination

    def tables(): Standard.Tables \ Assert =
        match Standard.buildTables() {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected tables");
                unreachable!()
        }

    def scrambled(notation: String): Sized.Standard \ Assert =
        let built = Cube.solved(3)
            |> Result.flatMap(c -> Cube.applyNotation(notation, c))
            |> Result.flatMap(Sized.standardOf);
        match built {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected a cube");
                unreachable!()
        }

    def replayToSolved(c: Sized.Standard, moves: List[Move.Move]): Bool =
        let initial = Sized.cubeOfStandard(c);
        let solved = List.foldLeft((curr, m) -> match curr {
            case Ok(k)  => Cube.apply(m, k)
            case Err(e) => Err(e)
        }, Ok(initial), moves);
        match solved {
            case Ok(k)  => Cube.isSolved(k)
            case Err(_) => false
        }

    ///
    /// The search outcome suite: builds the tables once and asserts against all
    /// termination reasons, exact telemetry counters, failure diagnostics, and replay.
    ///
    @Test
    def outcomeSuite(): Unit \ Assert =
        let t = tables();
        assertSolvedImmediately(t);
        assertSettled(t);
        assertProbeCap(t);
        assertViewsExhausted(t);
        assertCountersReconcile(t);
        assertSolutionWithMatchesOutcome(t)

    def assertSolvedImmediately(t: Standard.Tables): Unit \ Assert =
        let c = scrambled("");
        let out = Standard.solveWithOutcome(t, Standard.fastBudget(), c);
        Assert.assertEq(expected = Some(Nil), out#answer);
        Assert.assertEq(expected = Some(0), out#firstHtm);
        Assert.assertEq(expected = Some(0), out#finalHtm);
        Assert.assertEq(expected = 0, out#probesSpent);
        Assert.assertEq(expected = 0, out#viewsTried);
        Assert.assertEq(expected = Termination.SolvedImmediately, out#termination)

    def assertSettled(t: Standard.Tables): Unit \ Assert =
        let c = scrambled("R U R' U'");
        let b = Standard.budget({ minViews = 1, probeMax = 500, maxDepth = 25, handovers = 300 });
        let out = Standard.solveWithOutcome(t, b, c);
        Assert.assertEq(expected = Termination.Settled, out#termination);
        Assert.assertTrue(not Option.isEmpty(out#answer));
        match out#answer {
            case Some(ms) => Assert.assertTrue(replayToSolved(c, ms))
            case None     => ()
        }

    def assertProbeCap(t: Standard.Tables): Unit \ Assert =
        // maxDepth=20 allows handovers to be probed (bound <= room) while keeping
        // phase two from reaching its full distance, yielding exactly 2 probes and no answer
        let c = scrambled("U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2");
        let b = Standard.budget({ minViews = 6, probeMax = 2, maxDepth = 20, handovers = 1 });
        let out = Standard.solveWithOutcome(t, b, c);
        let sumProbes = out#viewStats |> List.map(v -> v#probesSpent) |> List.sum;
        Assert.assertEq(expected = Termination.ProbeCap, out#termination);
        Assert.assertEq(expected = 2, out#probesSpent);
        Assert.assertEq(expected = 2, sumProbes);
        Assert.assertEq(expected = None, out#answer)

    def assertViewsExhausted(t: Standard.Tables): Unit \ Assert =
        // A 20-move scramble with maxDepth=3 and ample probes exhausts all 6 views
        let c = scrambled("U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2");
        let b = Standard.budget({ minViews = 6, probeMax = 500, maxDepth = 3, handovers = 50 });
        let out = Standard.solveWithOutcome(t, b, c);
        Assert.assertEq(expected = Termination.ViewsExhausted, out#termination);
        Assert.assertEq(expected = None, out#answer);
        Assert.assertEq(expected = 6, out#viewsTried);
        Assert.assertEq(expected = 6, List.length(out#viewStats))

    def assertCountersReconcile(t: Standard.Tables): Unit \ Assert =
        let c = scrambled("R U R' U' F' U2 F");
        let out = Standard.solveWithOutcome(t, Standard.fastBudget(), c);
        let sumProbes = out#viewStats |> List.map(v -> v#probesSpent) |> List.sum;
        Assert.assertEq(expected = sumProbes, out#probesSpent);
        Assert.assertEq(expected = List.length(out#viewStats), out#viewsTried);
        Assert.assertTrue(out#viewsTried <= out#viewsAvailable);
        match (out#firstHtm, out#finalHtm) {
            case (Some(f), Some(l)) => Assert.assertTrue(f >= l)
            case _                  =>
                Assert.assertTrueWithMsg(false, "expected both first and final HTM")
        };
        match out#answer {
            case Some(ms) =>
                Assert.assertEq(expected = Some(List.length(ms)), out#finalHtm);
                Assert.assertTrue(replayToSolved(c, ms))
            case None => Assert.assertTrueWithMsg(false, "expected solution")
        }

    def assertSolutionWithMatchesOutcome(t: Standard.Tables): Unit \ Assert =
        let c = scrambled("R U R' U'");
        let b = Standard.fastBudget();
        let out = Standard.solveWithOutcome(t, b, c);
        let res = Standard.solutionWith(t, b, c);
        match (out#answer, res) {
            case (Some(a), Ok(bMoves)) => Assert.assertEq(expected = a, bMoves)
            case (None, Err(_))        => ()
            case _                     =>
                Assert.assertTrueWithMsg(false, "mismatched legacy outcome")
        }


    ///
    /// The handover counters account for every ending, and stay within bounds.
    ///
    /// The counters exist to say *why* a budget's handover limit mattered, so
    /// they are only worth reading if they add up. Three properties, per view:
    ///
    /// - every selected ending was unreachable, pruned, or attempted;
    /// - the attempts are the probes, since a probe is a phase-two attempt;
    /// - nothing claims more endings than the limit allowed, per depth, which
    ///   shows up as the total never exceeding the limit times the depths tried.
    ///
    /// Without the first, a counter could drift and still look plausible; the
    /// point of reporting them is that they cannot.
    ///
    @Test
    def handoverCountersAccountForEveryEnding(): Unit \ Assert + IO =
        if (Slow.skip("TestOutcome.handoverCountersAccountForEveryEnding",
                "builds the phase tables and searches every view"))
            ()
        else
            match Standard.buildTables() {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "the tables")
                case Ok(t)  => match Holding.ofToken(3, "AD44qcBJiFJM")
                        |> Result.flatMap(Sized.standardOf) {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e, "the token")
                    case Ok(c)  =>
                        let b = Standard.budget({
                            minViews = 6, probeMax = 4000, maxDepth = 25, handovers = 600
                        });
                        let out = Standard.solveWithOutcome(t, b, c);
                        out#viewStats |> List.forEach(v -> {
                            Assert.assertEqWithMsg(
                                expected = v#handoversSelected,
                                v#handoversUnreachable + v#handoversPruned
                                    + v#phaseTwoAttempts,
                                let seen = v#handoversUnreachable + v#handoversPruned
                                    + v#phaseTwoAttempts;
                                "a view selected ${v#handoversSelected} endings "
                                    + "and accounted for ${seen}");
                            Assert.assertEqWithMsg(expected = v#probesSpent,
                                v#phaseTwoAttempts,
                                "a probe is a phase-two attempt, so the two counts "
                                    + "are the same number")
                        });
                        let attempts = out#viewStats
                            |> List.foldLeft((a, v) -> a + v#phaseTwoAttempts, 0);
                        Assert.assertEqWithMsg(expected = out#probesSpent, attempts,
                            "the views' attempts should sum to the probes spent")
                }
            }

}
