///
/// The first layer: the cross, and the four corners above it.
///
/// The coordinate is checked exhaustively, because a ranking that collides puts
/// two different layers at one table entry and makes every distance below it a
/// lie. The solver is checked by replay on a named stratum, because each search
/// costs seconds and the suite is not the place to spend minutes.
///
/// That the ladder in `CubeSolve.Method.Beginner` agrees this counts as a first
/// layer is checked there, against its own rungs, rather than again here.
///
mod TestFirstLayer {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Solve.FirstLayer.Tables
    use CubeSolve.Table
    use CubeSolve.Table.FirstLayer.{encode, rank, solvedIndex, stateCount, successor, unrank}

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// All 136,080 coordinates round-trip.
    ///
    @Test
    def everyCornerCoordinateRoundTrips(): Unit \ Assert =
        let bad = Vector.range(0, stateCount()) |> Vector.count(i -> {
            let (places, twists) = unrank(i);
            rank(places, twists) != i
        });
        Assert.assertEqWithMsg(expected = 0, bad,
            "coordinates that do not survive unrank then rank");
        Assert.assertEqWithMsg(expected = 136080, stateCount(),
            "8 x 7 x 6 x 5 placements, each with four twists")

    ///
    /// The coordinate agrees with the model about what a move does.
    ///
    @Test
    def theCornerSuccessorAgreesWithTheModel(): Unit \ Assert =
        Vector#{"", "R", "R U", "F2 L' D", "R U R' U' F2 L D B'", "D2 R2 L F B' U"}
            |> Vector.forEach(alg -> {
                let c = made(alg);
                match encode(c) {
                    case Err(e)  => Assert.assertEqWithMsg(expected = "", e, "'${alg}'")
                    case Ok(here) =>
                        Move.all() |> Vector.forEach(m ->
                            Assert.assertEqWithMsg(
                                expected = Ok(successor(here, Move.index(m))),
                                Cube.apply(m, c) |> Result.flatMap(encode),
                                "'${alg}' then ${m}: the coordinate and the model "
                                    + "disagree about where the corners went"))
                }
            })

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
                        Assert.assertTrueWithMsg(CubeSolve.Solve.FirstLayer.isSolved(after),
                            "seed ${seed}: the answer does not solve the first layer")
                }
        }

}
