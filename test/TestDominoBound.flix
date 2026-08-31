mod TestDominoBound {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Random
    use CubeSolve.Solve.Domino
    use CubeSolve.Solve.IdaStar

    /// Phase two's tables.
    def tables(): Domino.Tables \ Assert =
        match Domino.buildTables() {
            case Ok(p)  => p
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the phase-two tables");
                unreachable!()
        }

    /// The phase-two lower bound never overstates, over a wide sample of
    /// domino-group states.
    ///
    /// This is the property that makes the solver's handover pruning sound. A
    /// handover is discarded without a probe when this bound already exceeds the
    /// moves left in the budget, on the grounds that no phase-two solution that
    /// short can exist. If the bound ever overstated, the solver would throw
    /// away handovers that could have won and return a longer answer -- or none
    /// -- and it would do so silently, on some cubes and not others.
    ///
    /// So it is checked against an actual search rather than assumed: for every
    /// sampled state the bound must be no larger than a solution the searcher
    /// really finds, and zero exactly at the goal.
    @Test
    def thePhaseTwoLowerBoundNeverOverstates(): Unit \ Assert =
        let p = tables();

        // the goal itself
        Assert.assertEqWithMsg(expected = 0, Domino.lowerBoundOf(p, 0i64),
            "the bound at the solved state should be zero");

        // states reached by phase-two moves only, so they stay in the group
        let alphabet = Vector#{"U", "U'", "U2", "D", "D'", "D2",
                               "R2", "L2", "F2", "B2"};
        def walk(k, seed, acc) =
            if (k <= 0) acc
            else {
                let (i, next) = CubeSolve.Model.Random.nextBelow(10, seed);
                walk(k - 1, next, "${acc} ${Vector.get(i, alphabet)}")
            };
        List.forEach(len ->
            List.forEach(seed -> {
                let alg = walk(len, Int32.toInt64(seed) * 7919i64 + 13i64, "");
                match Cube.solved(3)
                        |> Result.flatMap(c -> Cube.applyNotation(alg, c))
                        |> Result.flatMap(Domino.coordsOf) {
                    case Err(e) =>
                        Assert.assertEqWithMsg(expected = "", e,
                            "'${alg}' should stay inside the domino group")
                    case Ok((cperm, eperm, mperm)) =>
                        let state = Domino.packPhase2(cperm, eperm, mperm);
                        let bound = Domino.lowerBoundOf(p, state);
                        match IdaStar.search(Domino.phase2Of(p), state,
                                             Domino.maxPhase2Depth(),
                                             IdaStar.unbounded()) {
                            case Err(e) =>
                                Assert.assertEqWithMsg(expected = "", e,
                                    "phase two should solve '${alg}'")
                            case Ok(f) =>
                                let actual = IdaStar.length(f);
                                Assert.assertTrueWithMsg(bound <= actual,
                                    "the bound says at least ${bound} moves for "
                                        + "'${alg}' but a solution of ${actual} "
                                        + "exists -- the bound overstates, and the "
                                        + "solver prunes with it")
                        }
                }
            }, 1 :: 2 :: 3 :: 4 :: 5 :: Nil),
            1 :: 2 :: 3 :: 5 :: 8 :: 12 :: Nil)

}
