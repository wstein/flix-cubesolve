///
/// The first two layers.
///
/// **The states are the recorded handoffs, decoded from their tokens.** The
/// corpus in `docs/architecture.md` was measured on cubes reached by solving a
/// random scramble down to its first layer, and each was recorded by its
/// canonical token. Decoding those is the same starting position without
/// re-running the first-layer search to get there, so this test measures the
/// step it is about and nothing else.
///
/// **The result is checked against `Method.Beginner`, not against the
/// coordinates.** `TwoLayers.isSolved` asks the same encoders the search was
/// steered by, so a fault they shared would satisfy it. The ladder reads the
/// cube, and the ladder is what the public stage boundary means.
///
mod TestTwoLayers {

    use CubeSolve.Solve.IdaStar

    use CubeSolve.Method.Beginner
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Holding
    use CubeSolve.Solve.TwoLayers

    ///
    /// Two recorded handoffs: the cheapest of the corpus and the worst.
    ///
    /// Each is a token, the node count the naive `max(cross, corners, middle)`
    /// heuristic spent on it, and half of that -- the ceiling this must stay
    /// under, so the gate fails if the paired projection stops delivering at
    /// least a twofold saving.
    ///
    /// Node counts rather than seconds: a machine's speed is not a property of
    /// the search.
    ///
    def corpus(): Vector[(String, Int64)] = Vector#{
        // seed 70000, depth 11, naive 4,148,363 nodes
        ("AJmiz2F3jagE", 2074181i64),
        // seed 70006, depth 12, naive 84,458,590 nodes -- the state the paired
        // projection was added for
        ("AKuGw6tcoYcE", 42229295i64)
    }

    ///
    /// Every recorded handoff is finished, and reaches the `TwoLayers` rung.
    ///
    /// One test rather than several: the five tables take about eighty seconds
    /// to build and nothing shares them across `@Test` functions.
    ///
    @Test
    def everyRecordedHandoffReachesTheTwoLayersRung(): Unit \ Assert =
        match TwoLayers.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "the tables should build")
            case Ok(tl) =>
                corpus() |> Vector.forEach(match (token, ceiling) ->
                    check(tl, token, ceiling));
                pairTableIsClosed(tl)
        }

    ///
    /// One handoff: finished, replayed, judged by the ladder, and within budget.
    ///
    def check(tl: TwoLayers.Tables, token: String, ceiling: Int64): Unit \ Assert =
        match Holding.ofToken(3, token) {
            case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "decoding ${token}")
            case Ok(begun) =>
                Assert.assertTrueWithMsg(
                    Beginner.isComplete(Beginner.Stage.FirstLayer, begun),
                    "${token} should be a first-layer handoff");
                finish(tl, token, ceiling, begun)
        }

    ///
    /// The search, and everything asserted about its answer.
    ///
    def finish(
        tl: TwoLayers.Tables,
        token: String,
        ceiling: Int64,
        begun: Cube.Cube
    ): Unit \ Assert =
        match TwoLayers.found(tl, begun, IdaStar.unbounded()) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "token ${token}")
            case Ok(f)  =>
                Assert.assertTrueWithMsg(TwoLayers.nodesOf(f) <= ceiling,
                    "${token}: ${TwoLayers.nodesOf(f)} nodes, over the ${ceiling} "
                        + "this stratum allows -- the paired projection has stopped "
                        + "paying for itself");
                match Cube.applyAll(TwoLayers.movesOf(f), begun) {
                    case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "replay")
                    case Ok(after) =>
                        Assert.assertTrueWithMsg(
                            Beginner.isComplete(Beginner.Stage.TwoLayers, after),
                            "${token}: the answer did not reach the TwoLayers rung");
                        Assert.assertTrueWithMsg(
                            Beginner.isComplete(Beginner.Stage.FirstLayer, after),
                            "${token}: the first layer was not restored")
                }
        }

    ///
    /// The paired projection's table is closed over its coordinate.
    ///
    /// Asserted here rather than in `TestCornerEdgePair` because this fixture
    /// builds the table anyway, and building 3.2 million states twice to prove
    /// one thing cost the suite seventy seconds.
    ///
    /// An entry the sweep never reached would mean the successor is not closed,
    /// which is as quiet a fault as a collision and just as damaging: the
    /// heuristic would read a fill value and stop being a lower bound.
    ///
    def pairTableIsClosed(tl: TwoLayers.Tables): Unit \ Assert =
        let paired = TwoLayers.pairedTable(tl);
        Assert.assertEqWithMsg(expected = TwoLayers.pairedStateCount(),
            CubeSolve.Table.entries(paired), "one entry per pair state");
        Assert.assertEqWithMsg(expected = 0,
            CubeSolve.Table.get(TwoLayers.pairedSolvedIndex(), paired),
            "the solved pair is nought moves from solved");
        let deepest = Vector.range(0, TwoLayers.pairedStateCount())
            |> Vector.foldLeft((w, i) ->
                Int32.max(w, CubeSolve.Table.get(i, paired)), 0);
        Assert.assertTrueWithMsg(deepest > 0 and deepest < 20,
            "the deepest pair state is ${deepest} moves out, outside anything "
                + "this projection should reach")

}
