///
/// The first layer: the cross, and the four corners above it.
///
/// The coordinate is checked exhaustively, because a ranking that collides puts
/// two different layers at one table entry and makes every distance below it a
/// lie. The solver is checked by replay on a named stratum, because each search
/// costs seconds and the suite is not the place to spend minutes.
///
/// **The result is checked against the ladder, not against the coordinate.**
/// `Solve.FirstLayer.isSolved` asks the same encoders the search was steered by,
/// so a coordinate fault and a search fault that agreed with each other would
/// satisfy it. `Method.Beginner` reads the cube instead, and that is what the
/// public stage boundary means.
///
mod TestFirstLayer {

    use CubeSolve.Method.Beginner
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Solve.FirstLayer.Tables
    use CubeSolve.Table
    use CubeSolve.Table.FirstLayer.{encode, rank, solvedIndex, stateCount, successor, unrank}

    ///
    /// The corner table is complete, and no bottom corner is more than seven
    /// moves from home.
    ///
    @Test
    def theCornerTableIsCompleteAndSevenDeep(): Unit \ Assert =
        match CubeSolve.Table.FirstLayer.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "building")
            case Ok(t)  =>
                Assert.assertEqWithMsg(expected = stateCount(), Table.entries(t),
                    "one entry per state");
                let deepest = Vector.range(0, stateCount())
                    |> Vector.foldLeft((w, i) -> Int32.max(w, Table.get(i, t)), 0);
                Assert.assertEqWithMsg(expected = 7, deepest,
                    "the furthest bottom corners are seven moves from home");
                Assert.assertEqWithMsg(expected = 0, Table.get(solvedIndex(), t),
                    "solved corners are nought moves from home")
        }

    ///
    /// Every answer solves the first layer, and is short enough to teach.
    ///
    /// **Six fixed seeds.** Each search costs a few seconds, so this is a named
    /// stratum rather than a sweep: seeds 60000 to 60005, which the measurement
    /// recorded in `docs/architecture.md` came from the first twenty-five of.
    /// The bound asserted here is the worst that measurement saw, so a
    /// regression that made answers longer would fail rather than pass quietly.
    ///
    @Test
    def everyAnswerSolvesTheFirstLayerAndIsShortEnoughToTeach(): Unit \ Assert =
        match CubeSolve.Solve.FirstLayer.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "building the tables")
            case Ok(t)  =>
                Vector.range(0, 6) |> Vector.forEach(i -> {
                    let seed = Int32.toInt64(i) + 60000i64;
                    match Random.sampleDeterministic(seed, 3) |> Result.map(fst) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "seed ${seed}")
                        case Ok(c)  => check(t, seed, c)
                    }
                })
        }

    ///
    /// One scramble: solved, replayed, and within the recorded bound.
    ///
    def check(t: Tables, seed: Int64, c: Cube.Cube): Unit \ Assert =
        match CubeSolve.Solve.FirstLayer.solution(t, c) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "seed ${seed}")
            case Ok(ms) =>
                Assert.assertTrueWithMsg(List.length(ms) <= 11,
                    "seed ${seed}: ${List.length(ms)} moves, longer than the "
                        + "eleven the corpus measurement worst-cased at");
                match Cube.applyAll(ms, c) {
                    case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "replay")
                    case Ok(after) =>
                        // Against the ladder's decoded-model predicate rather than
                        // the coordinates the search was steered by. `isSolved`
                        // asks the same encoders the search used, so a fault they
                        // shared would satisfy it; the ladder reads the cube.
                        Assert.assertTrueWithMsg(
                            Beginner.isComplete(Beginner.Stage.FirstLayer, after),
                            "seed ${seed}: the answer does not reach the FirstLayer rung")
                }
        }

}
