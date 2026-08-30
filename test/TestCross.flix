///
/// The cross coordinate and its solver.
///
/// The coordinate is the part that has to be right: a table built over a
/// coordinate that is not a bijection has unreachable entries at best and
/// collisions at worst, and either makes every distance below it a lie. So it
/// is checked exhaustively rather than sampled.
///
mod TestCross {

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
    /// Every one of the 190,080 coordinates round-trips through `unrank` and
    /// `rank`.
    ///
    /// Exhaustive because the space allows it. A ranking that collides on even
    /// one pair would put two different crosses at one table entry, and the
    /// distance stored there would be wrong for one of them.
    ///
    @Test
    def everyCoordinateRoundTrips(): Unit \ Assert =
        let bad = Vector.range(0, stateCount()) |> Vector.count(i -> {
            let (places, flips) = unrank(i);
            rank(places, flips) != i
        });
        Assert.assertEqWithMsg(expected = 0, bad,
            "coordinates that do not survive unrank then rank");
        // and no two coordinates decode to the same arrangement
        Assert.assertEqWithMsg(expected = 190080, stateCount(),
            "12 x 11 x 10 x 9 arrangements, each with four flips")

    ///
    /// The coordinate agrees with the model about what a move does.
    ///
    /// The successor is arithmetic on four slots; the model turns a whole cube.
    /// They are independent derivations of the same thing, and this is where
    /// they are made to agree -- every move, from a fixed sample of states.
    ///
    @Test
    def theSuccessorAgreesWithTheModel(): Unit \ Assert =
        let seeds = Vector#{"", "R", "R U", "F2 L' D", "R U R' U' F2 L D B'",
            "M2 E2 S2", "D2 R2 L F B' U"};
        seeds |> Vector.forEach(alg -> {
            let c = made(alg);
            match encode(c) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'")
                case Ok(here) =>
                    Move.all() |> Vector.forEach(m -> {
                        let byModel = Cube.apply(m, c) |> Result.flatMap(encode);
                        let byCoord = successor(here, Move.index(m));
                        Assert.assertEqWithMsg(expected = Ok(byCoord), byModel,
                            "'${alg}' then ${m}: the coordinate and the model "
                                + "disagree about where the cross went")
                    })
            }
        })

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
                            match (encode(c), Cross.solution(t, c)) {
                                case (Ok(here), Ok(ms)) =>
                                    Assert.assertEqWithMsg(
                                        expected = Table.get(here, t), List.length(ms),
                                        "seed ${seed}: the solution is not the length "
                                            + "the table says is optimal");
                                    match Cube.applyAll(ms, c) {
                                        case Err(e) =>
                                            Assert.assertEqWithMsg(expected = "", e, "replay")
                                        case Ok(after) =>
                                            Assert.assertTrueWithMsg(Cross.isSolved(after),
                                                "seed ${seed}: the answer does not solve "
                                                    + "the cross")
                                    }
                                case _ =>
                                    Assert.assertTrueWithMsg(false, "seed ${seed} failed")
                            }
                    }
                })
        }

}
