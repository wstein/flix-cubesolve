///
/// The cross coordinate and its solver.
///
/// The coordinate is the part that has to be right: a table built over a
/// coordinate that is not a bijection has unreachable entries at best and
/// collisions at worst, and either makes every distance below it a lie. So it
/// is checked exhaustively rather than sampled.
///
mod TestCross {


    use CubeSolve.Method.Beginner
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Solve.Cross
    use CubeSolve.Table
    use CubeSolve.Table.Cross.{encode, rank, solvedIndex, stateCount, successor, unrank}

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// A solved cube has the solved coordinate, and only it does.
    ///
    @Test
    def onlyASolvedCrossHasTheSolvedCoordinate(): Unit \ Assert =
        Assert.assertEq(expected = Ok(solvedIndex()), encode(made("")));
        Assert.assertTrue(Cross.isSolved(made("")));
        // the top layer may be anything at all
        Assert.assertTrueWithMsg(Cross.isSolved(made("U R U' R' F' U F")),
            "turning the top does not disturb the cross");
        Assert.assertFalseWithMsg(Cross.isSolved(made("D")),
            "turning the bottom does");
        Assert.assertFalseWithMsg(Cross.isSolved(made("F")),
            "and so does any move that lifts a cross edge")

    ///
    /// The table is exact, and eight is as far as a cross ever is.
    ///
    /// Every entry reachable, no gaps: an entry left at the fill value would
    /// mean a state the sweep never visited, which for a space this size means
    /// the successor is not closed.
    ///
    @Test
    def theTableIsCompleteAndTheDiameterIsEight(): Unit \ Assert =
        match Cross.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "building the table")
            case Ok(t)  =>
                Assert.assertEqWithMsg(expected = stateCount(), Table.entries(t),
                    "one entry per state");
                let deepest = Vector.range(0, stateCount())
                    |> Vector.foldLeft((worst, i) -> Int32.max(worst, Table.get(i, t)), 0);
                Assert.assertEqWithMsg(expected = Cross.diameter(), deepest,
                    "the furthest cross should be ${Cross.diameter()} moves out");
                Assert.assertEqWithMsg(expected = 0, Table.get(solvedIndex(), t),
                    "a solved cross is nought moves from solved")
        }

    ///
    /// Every solution solves the cross, and is as short as the table says.
    ///
    /// Replay rather than trust: the search returns move indices, and an
    /// off-by-one in turning those back into moves would give the right length
    /// and the wrong cube.
    ///
    @Test
    def everySolutionSolvesTheCrossInTheOptimalNumberOfMoves(): Unit \ Assert =
        match Cross.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "building the table")
            case Ok(t)  =>
                Vector.range(0, 60) |> Vector.forEach(i -> {
                    let seed = Int32.toInt64(i) + 40000i64;
                    match Random.sampleDeterministic(seed, 3) |> Result.map(fst) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "seed ${seed}")
                        case Ok(c)  =>
                            match (encode(c), Cross.solution(t, c, noNodeLimit())) {
                                case (Ok(here), Ok(ms)) =>
                                    Assert.assertEqWithMsg(
                                        expected = Table.get(here, t), List.length(ms),
                                        "seed ${seed}: the solution is not the length "
                                            + "the table says is optimal");
                                    match Cube.applyAll(ms, c) {
                                        case Err(e) =>
                                            Assert.assertEqWithMsg(expected = "", e, "replay")
                                        case Ok(after) =>
                                            // Against the ladder's own predicate, not the
                                            // coordinate the search was steered by: a
                                            // coordinate bug and a search bug that agreed
                                            // with each other would satisfy `isSolved` and
                                            // still leave the cross unsolved.
                                            Assert.assertTrueWithMsg(
                                                Beginner.isComplete(Beginner.Stage.Cross, after),
                                                "seed ${seed}: the answer does not reach "
                                                    + "the Cross rung")
                                    }
                                case _ =>
                                    Assert.assertTrueWithMsg(false, "seed ${seed} failed")
                            }
                    }
                })
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
