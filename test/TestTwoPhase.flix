mod TestTwoPhase {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard
    use CubeSolve.Solve.Standard.Budget

    /// Both sets of tables. Five breadth-first sweeps between them, so they are
    /// built once and asserted against thoroughly.
    def tables(): (CubeSolve.Table.Standard.Tables, CubeSolve.Table.Domino.Tables) \ Assert =
        match (CubeSolve.Table.Standard.build(), CubeSolve.Table.Domino.build()) {
            case (Ok(a), Ok(b)) => (a, b)
            case _ =>
                Assert.assertTrueWithMsg(false, "expected both sets of tables");
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

    /// The corpus. Fixed, so a regression in solution length is visible.
    def corpus(): List[String] =
        "R" ::
        "R U R' U'" ::
        "F R U' R' U' R U R' F'" ::
        "R U2 F' L D B2 R' U" ::
        "D2 R' U2 B L F2 D R' B2 U'" ::
        "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2" ::
        Nil

    // ---------- solving ----------

    /// Everything the two-phase solver must do, over one build of both sets of
    /// tables.
    ///
    /// These are five separate properties and would read better as five tests.
    /// They share one because the five breadth-first sweeps behind them take
    /// most of a minute, and paying that five times to gain five test names
    /// would turn a gate into a benchmark. Every assertion carries its own
    /// message, so a failure still says which property broke.
    ///
    /// - **Every scramble is solved and the solution replays.** Replaying
    ///   through the model is the check that matters: the search works in
    ///   coordinates and hands phase one's output to phase two through the
    ///   model, so this confirms the whole chain rather than each half.
    /// - **A solved cube needs no moves**, rather than a pair that cancels.
    /// - **An exhausted budget is reported with its numbers** -- not a hang,
    ///   and not a wrong answer.
    /// - **More probes are never worse.** A quality property, and the reason
    ///   `probeMin` exists: the first solution found is rarely the best.
    /// - **The same budget gives the same solution.** Every fixture and every
    ///   reproduction of a reported bug depends on it.
    ///
    /// Termination is by probe count throughout and never by a clock. A time
    /// budget varies with the machine, the JDK, JIT warm-up and collection, so
    /// a gate written against one fails on a slow runner and passes on a fast
    /// one.
    @Test
    def theTwoPhaseSolverSolvesReplaysAndRespectsItsBudget(): Unit \ Assert =
        let (p1, p2) = tables();
        let budget = Standard.defaultBudget();

        corpus() |> List.forEach(alg -> {
            let cube = scrambled(alg);
            match Standard.solution(p1, p2, budget, cube) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'")
                case Ok(ms) =>
                    Assert.assertTrueWithMsg(
                        List.length(ms) <= 25,
                        "'${alg}' took ${List.length(ms)} moves, over the budget");
                    let replayed = Cube.applyAll(ms, Sized.cubeOfStandard(cube))
                        |> Result.map(Cube.isSolved);
                    Assert.assertEqWithMsg(
                        expected = Ok(true), replayed,
                        "the solution for '${alg}' did not solve it: ${Move.showAll(ms)}")
            }
        });

        match Sized.solvedStandard() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved exists")
            case Ok(c)  =>
                Assert.assertEqWithMsg(
                    expected = Ok(Nil), Standard.solution(p1, p2, budget, c),
                    "a solved cube should need no moves")
        };

        let starved = Standard.Budget.Budget({ probeMin = 1, probeMax = 1, maxDepth = 4 });
        let hard = scrambled("U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2");
        match Standard.solution(p1, p2, starved, hard) {
            case Ok(ms) =>
                Assert.assertTrueWithMsg(false,
                    "four moves cannot solve that: ${Move.showAll(ms)}")
            case Err(e) =>
                Assert.assertTrueWithMsg(String.contains(substr = "probes", e),
                    "the refusal should name the probe budget, but said: ${e}")
        };

        let quick = Standard.Budget.Budget({ probeMin = 1, probeMax = 40, maxDepth = 25 });
        let patient = Standard.Budget.Budget({ probeMin = 80, probeMax = 400, maxDepth = 25 });
        corpus() |> List.forEach(alg -> {
            let cube = scrambled(alg);
            match (Standard.solution(p1, p2, quick, cube),
                   Standard.solution(p1, p2, patient, cube)) {
                case (Ok(fast), Ok(slow)) =>
                    Assert.assertTrueWithMsg(
                        List.length(slow) <= List.length(fast),
                        "'${alg}': more probes gave ${List.length(slow)} moves "
                            + "against ${List.length(fast)}")
                case _ =>
                    Assert.assertTrueWithMsg(false, "both budgets should solve '${alg}'")
            }
        });

        let repeatable = scrambled("R U2 F' L D B2 R' U");
        let once = Standard.solution(p1, p2, budget, repeatable) |> Result.map(Move.showAll);
        let twice = Standard.solution(p1, p2, budget, repeatable) |> Result.map(Move.showAll);
        Assert.assertEqWithMsg(
            expected = once, twice, "the same budget should give the same solution")

}
