///
/// The first-layer solver's answers.
///
/// Split from `TestFirstLayer`, which checks the table itself. The table checks
/// are cheap and read only `CubeSolve.Table`; this one builds the table, solves
/// a sample and judges the result against the beginner ladder, which is both
/// the slow half and a different set of modules. One module doing both was over
/// the coupling threshold.
///
mod TestFirstLayerSolutions {

    use CubeSolve.Method.Beginner
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Solve.FirstLayer.Tables

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
    def everyAnswerSolvesTheFirstLayerAndIsShortEnoughToTeach(): Unit \ Assert + IO =
        if (Slow.skip(
                "TestFirstLayerSolutions.everyAnswerSolvesTheFirstLayer",
                "builds the first-layer table and solves a sample"))
            ()
        else {
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
        }

    ///
    /// One scramble: solved, replayed, and within the recorded bound.
    ///
    def check(t: Tables, seed: Int64, c: Cube.Cube): Unit \ Assert =
        match CubeSolve.Solve.FirstLayer.solution(t, c, noNodeLimit()) {
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


    ///
    /// A node budget larger than any search in this module can spend.
    ///
    /// A literal rather than `IdaStar.unbounded()` so that this module does not
    /// name `IdaStar` to say one thing that never changes, and a bound rather
    /// than no bound because a test that could run forever is not a test.
    /// These searches are thousands of nodes; this is half a billion.
    ///
    def noNodeLimit(): Int64 = 500_000_000i64
}
