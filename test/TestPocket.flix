mod TestPocket {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Table
    use CubeSolve.Table.Pocket

    /// Every 2x2x2 table. Building these is the engine's one expensive step, so
    /// each test that needs them builds them once and asserts a great deal.
    def tables(): Pocket.Tables \ Assert =
        match Pocket.build() {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    // ---------- coordinates ----------

    /// Gate: both rank directions. A coordinate that does not round-trip
    /// silently aliases two states onto one entry.
    @Test
    def permutationRankRoundTripsOverTheWholeRange(): Unit \ Assert =
        Vector.range(0, Pocket.permCount()) |> Vector.forEach(r ->
            Assert.assertEqWithMsg(
                expected = r, Pocket.permRank(Pocket.permUnrank(r)), "permutation ${r}"))

    @Test
    def orientationRankRoundTripsOverTheWholeRange(): Unit \ Assert =
        Vector.range(0, Pocket.oriCount()) |> Vector.forEach(r ->
            Assert.assertEqWithMsg(
                expected = r, Pocket.oriRank(Pocket.oriUnrank(r)), "orientation ${r}"))

    /// Unranking really does produce permutations, not merely distinct vectors.
    @Test
    def everyUnrankedPermutationIsAPermutation(): Unit \ Assert =
        Vector.range(0, Pocket.permCount()) |> Vector.forEach(r -> {
            let q = Pocket.permUnrank(r);
            Vector.range(0, 7) |> Vector.forEach(i ->
                Assert.assertTrueWithMsg(Vector.memberOf(i, q),
                    "permutation ${r} is missing ${i}"))
        })

    /// Unranked twists obey the sum rule, so the seventh really is forced.
    @Test
    def everyUnrankedOrientationSumsToZeroModThree(): Unit \ Assert =
        Vector.range(0, Pocket.oriCount()) |> Vector.forEach(r -> {
            let o = Pocket.oriUnrank(r);
            Assert.assertEq(expected = 7, Vector.length(o));
            Assert.assertEqWithMsg(
                expected = 0, Int32.modulo(Vector.sum(o), 3), "orientation ${r}")
        })

    /// The coordinate and the model describe the same cube.
    @Test
    def theCoordinateRoundTripsThroughTheModel(): Unit \ Assert =
        List.forEach(i ->
            match Pocket.decode(i) |> Result.flatMap(Pocket.encode) {
                case Ok(back) => Assert.assertEqWithMsg(expected = i, back, "state ${i}")
                case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "state ${i}")
            },
            0 :: 1 :: 728 :: 729 :: 100000 :: 2000000 :: 3674159 :: Nil)

    @Test
    def theSolvedCoordinateIsZero(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(Pocket.solvedIndex()),
            Cube.solved(2) |> Result.flatMap(Pocket.encode)
        )

    @Test
    def outOfRangeCoordinatesAreRefused(): Unit \ Assert =
        Assert.assertErr(Pocket.decode(-1));
        Assert.assertErr(Pocket.decode(Pocket.stateCount()))

    /// The coordinate holds DBL still, so a cube whose DBL has moved has no
    /// coordinate and says so rather than encoding to a wrong one.
    @Test
    def aCubeWithItsHeldCornerMovedIsRefused(): Unit \ Assert =
        match Cube.solved(2) |> Result.flatMap(c -> Cube.applyNotation("D", c)) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "D applies")
            case Ok(c)  =>
                match Pocket.encode(c) {
                    case Ok(_)  => Assert.assertTrueWithMsg(false, "D moves DBL")
                    case Err(e) => Assert.assertTrue(String.contains(substr = "DBL", e))
                }
        }

    // ---------- move tables agree with the model ----------

    /// Gate 3.3, on a sample: the coordinate move tables and the model's own
    /// turns agree. They share no code -- the tables are built from the
    /// coordinate arithmetic directly -- so this is a real cross-check rather
    /// than a restatement.
    @Test
    def coordinateMovesAgreeWithModelMoves(): Unit \ Assert =
        // Only the move tables, not the distance sweep: this costs milliseconds
        // where build() costs seconds.
        let pm = match Pocket.permMoves() {
            case Ok(x)  => x
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "perm moves"); unreachable!()
        };
        let om = match Pocket.oriMoves() {
            case Ok(x)  => x
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "ori moves"); unreachable!()
        };
        List.forEach(i ->
            Vector.range(0, Pocket.moveCount()) |> Vector.forEach(m -> {
                let viaTable =
                    Table.get(i / Pocket.oriCount() * Pocket.moveCount() + m, pm)
                        * Pocket.oriCount()
                    + Table.get(Int32.modulo(i, Pocket.oriCount()) * Pocket.moveCount() + m, om);
                let viaModel =
                    Pocket.decode(i)
                        |> Result.flatMap(c -> Cube.apply(Pocket.moveOfIndex(m), c))
                        |> Result.flatMap(Pocket.encode);
                Assert.assertEqWithMsg(
                    expected = Ok(viaTable), viaModel, "state ${i} under move ${m}")
            }),
            0 :: 1 :: 729 :: 5000 :: 123457 :: 2000000 :: 3674159 :: Nil)

    // ---------- the exhaustive oracle ----------

    /// Gates 3.1, 3.2 and 3.4 together, in one sweep of all 3,674,160 states.
    ///
    /// - every state is reached, so the space is exactly 3,674,160;
    /// - the distance histogram matches the independently computed one, to the
    ///   digit;
    /// - the diameter is 11 under the nine half-turn moves;
    /// - and no entry is left at the "not reached" marker, which is what makes
    ///   using the width's largest value as that marker sound.
    @Test
    def theOracleIsExhaustiveAndMatchesTheKnownHistogram(): Unit \ Assert =
        let d = Pocket.distanceTable(tables());
        Assert.assertEq(expected = Pocket.stateCount(), Table.entries(d));
        let counts = region rc {
            let tally = Array.repeat(rc, 16, 0);
            Vector.range(0, Pocket.stateCount()) |> Vector.forEach(i -> {
                let v = Table.get(i, d);
                Array.put(Array.get(v, tally) + 1, v, tally)
            });
            Array.toVector(tally)
        };
        let expected = Vector#{
            1, 9, 54, 321, 1847, 9992, 50136, 227536, 870072, 1887748, 623800, 2644
        };
        Vector.range(0, 12) |> Vector.forEach(i ->
            Assert.assertEqWithMsg(
                expected = Vector.get(i, expected), Vector.get(i, counts),
                "states at distance ${i}"));
        Vector.range(12, 16) |> Vector.forEach(i ->
            Assert.assertEqWithMsg(
                expected = 0, Vector.get(i, counts),
                "nothing should sit at distance ${i}, including the unvisited marker"));
        Assert.assertEq(expected = 0, Table.get(Pocket.solvedIndex(), d))

    /// Gate 3.2, exhaustively: a move changes the distance by at most one, and
    /// every unsolved state has a neighbour one step closer. Together these say
    /// the table really is a distance and not merely a labelling.
    @Test
    def everyStateHasAConsistentNeighbourhood(): Unit \ Assert =
        let t = tables();
        let d = Pocket.distanceTable(t);
        let pm = Pocket.permMoveTable(t);
        let om = Pocket.oriMoveTable(t);
        let bad = region rc {
            let faults = Array.repeat(rc, 2, -1);
            Vector.range(0, Pocket.stateCount()) |> Vector.forEach(s -> {
                let here = Table.get(s, d);
                let pi = s / Pocket.oriCount();
                let oi = Int32.modulo(s, Pocket.oriCount());
                let closer = Vector.range(0, Pocket.moveCount()) |> Vector.count(m -> {
                    let to = Table.get(pi * Pocket.moveCount() + m, pm) * Pocket.oriCount()
                           + Table.get(oi * Pocket.moveCount() + m, om);
                    let there = Table.get(to, d);
                    if (Int32.abs(here - there) > 1) Array.put(s, 0, faults) else ();
                    there == here - 1
                });
                if (here > 0 and closer == 0) Array.put(s, 1, faults) else ()
            });
            Array.toVector(faults)
        };
        Assert.assertEqWithMsg(expected = -1, Vector.get(0, bad),
            "a move changed the distance by more than one");
        Assert.assertEqWithMsg(expected = -1, Vector.get(1, bad),
            "an unsolved state had no neighbour closer to solved")

    // ---------- the two admissible projections ----------

    /// Gate 4.1, exhaustively and once per projection: both heuristics are
    /// admissible, and their maximum is too.
    ///
    /// Admissible because each projection is homomorphic -- a move acts on it
    /// without reference to what was projected away -- so distance in the
    /// quotient can only be shorter.
    @Test
    def bothProjectionsAreAdmissibleEverywhere(): Unit \ Assert =
        let t = tables();
        let d = Pocket.distanceTable(t);
        let oriD = Pocket.oriDistanceTable(t);
        let permD = Pocket.permDistanceTable(t);
        let worst = region rc {
            let seen = Array.repeat(rc, 3, 0);
            Vector.range(0, Pocket.stateCount()) |> Vector.forEach(s -> {
                let exact = Table.get(s, d);
                let ho = Table.get(Int32.modulo(s, Pocket.oriCount()), oriD);
                let hp = Table.get(s / Pocket.oriCount(), permD);
                if (ho > exact) Array.put(1, 0, seen) else ();
                if (hp > exact) Array.put(1, 1, seen) else ();
                let best = Int32.max(ho, hp);
                if (best > Array.get(2, seen)) Array.put(best, 2, seen) else ()
            });
            Array.toVector(seen)
        };
        Assert.assertEqWithMsg(expected = 0, Vector.get(0, worst),
            "the orientation heuristic overestimated some state");
        Assert.assertEqWithMsg(expected = 0, Vector.get(1, worst),
            "the permutation heuristic overestimated some state");
        // Measured independently: the orientation projection tops out at 6 and
        // the permutation projection at 7, against a diameter of 11. That gap
        // is why the two are used together rather than either alone.
        Assert.assertEq(expected = 7, Vector.get(2, worst))

    /// The projections really are coarser than the full space, so a search
    /// still has work to do and the heuristics are not secretly the oracle.
    @Test
    def theProjectionsHaveTheirKnownMaxima(): Unit \ Assert =
        let t = tables();
        let maxOf = (table, count) ->
            Vector.range(0, count)
                |> Vector.foldLeft((acc, i) -> Int32.max(acc, Table.get(i, table)), 0);
        Assert.assertEq(
            expected = 6, maxOf(Pocket.oriDistanceTable(t), Pocket.oriCount()));
        Assert.assertEq(
            expected = 7, maxOf(Pocket.permDistanceTable(t), Pocket.permCount()))

}
