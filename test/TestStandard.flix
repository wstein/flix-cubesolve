mod TestStandard {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized
    use CubeSolve.Table
    use CubeSolve.Table.Standard

    /// Every phase-one table. Three breadth-first sweeps over 6.6 million
    /// states between them, so tests that need it build it once and assert a
    /// great deal.
    def phase1(): Standard.Phase1 \ Assert =
        match Standard.build() {
            case Ok(p)  => p
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the phase-one tables");
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

    // ---------- coordinates ----------

    @Test
    def theCoordinateSizesAreTheKnownOnes(): Unit \ Assert =
        Assert.assertEq(expected = 2187, Standard.twistCount());
        Assert.assertEq(expected = 2048, Standard.flipCount());
        Assert.assertEq(expected = 495, Standard.sliceCount());
        Assert.assertEq(expected = 18, Standard.moveCount())

    /// Flip is eleven free bits, not twelve: the twelfth is forced by the sum
    /// rule. Twist is seven free trits for the same reason. Getting this wrong
    /// doubles or triples the space and every table with it.
    @Test
    def orientationCoordinatesRoundTripAndObeyTheSumRules(): Unit \ Assert =
        Vector.range(0, Standard.twistCount()) |> Vector.forEach(r -> {
            let co = Standard.twistUnrank(r);
            Assert.assertEqWithMsg(expected = 8, Vector.length(co), "twist ${r}");
            Assert.assertEqWithMsg(
                expected = 0, Int32.modulo(Vector.sum(co), 3), "twist ${r} sums wrong");
            Assert.assertEqWithMsg(expected = r, Standard.twistOf(co), "twist ${r}")
        });
        Vector.range(0, Standard.flipCount()) |> Vector.forEach(r -> {
            let eo = Standard.flipUnrank(r);
            Assert.assertEqWithMsg(expected = 12, Vector.length(eo), "flip ${r}");
            Assert.assertEqWithMsg(
                expected = 0, Int32.modulo(Vector.sum(eo), 2), "flip ${r} sums wrong");
            Assert.assertEqWithMsg(expected = r, Standard.flipOf(eo), "flip ${r}")
        })

    /// UDSlice is a set, not a sequence: it says which four slots hold slice
    /// edges and not which is which. Every rank must round-trip and name four
    /// distinct slots below twelve.
    @Test
    def theSliceCoordinateRoundTripsOverItsWholeRange(): Unit \ Assert =
        Vector.range(0, Standard.sliceCount()) |> Vector.forEach(r -> {
            let slots = Standard.sliceUnrank(r);
            Assert.assertEqWithMsg(expected = 4, Vector.length(slots), "slice ${r}");
            Assert.assertTrueWithMsg(
                Vector.forAll(x -> x >= 0 and x < 12, slots), "slice ${r} escaped 0..11");
            Assert.assertEqWithMsg(
                expected = r, Orbit64.Rank.combRank(slots), "slice ${r}")
        })

    /// The solved cube sits at the phase-one goal, and the slice coordinate is
    /// the largest rather than zero -- the solved set {8,9,10,11} is the last
    /// one colexicographically.
    @Test
    def theSolvedCubeIsAtThePhaseOneGoal(): Unit \ Assert =
        Assert.assertEq(expected = 494, Standard.solvedSlice());
        match Cube.solved(3) |> Result.flatMap(Standard.coordsOf) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved has coordinates")
            case Ok((twist, flip, slice)) =>
                Assert.assertEq(expected = 0, twist);
                Assert.assertEq(expected = 0, flip);
                Assert.assertEq(expected = Standard.solvedSlice(), slice)
        };
        Assert.assertEq(
            expected = Ok(true),
            Cube.solved(3) |> Result.map(Standard.isPhase1Solved))

    /// Half turns never disturb phase one, and quarter turns of R, L, F and B
    /// always do. That asymmetry is what phase one is about, and it is a
    /// property of the coordinates rather than of the search.
    @Test
    def thePhaseOneSubgroupIsExactlyTheHalfTurnOne(): Unit \ Assert =
        List.forEach(alg ->
            Assert.assertTrueWithMsg(
                Standard.isPhase1Solved(Sized.cubeOfStandard(scrambled(alg))),
                "'${alg}' should stay inside the phase-one subgroup"),
            "U D' R2 L2 F2 B2" :: "U2 D2" :: "R2 F2 L2 B2 U D" :: "" :: Nil);
        List.forEach(alg ->
            Assert.assertFalseWithMsg(
                Standard.isPhase1Solved(Sized.cubeOfStandard(scrambled(alg))),
                "'${alg}' should leave the phase-one subgroup"),
            "R" :: "F'" :: "L" :: "B2 R" :: "U R" :: Nil)

    // ---------- tables ----------

    /// Everything the phase-one tables must satisfy, over one build.
    ///
    /// - **The move tables are closed and reversible.** Applying a move and
    ///   then its inverse returns the coordinate, for every coordinate and
    ///   every move. A move table that lost a state would pass a spot check and
    ///   fail here.
    /// - **The pruning tables reach depth 9 and no further**, which is the
    ///   figure decoded from the reference's own checked-in pruning data. It
    ///   also keeps fifteen free as the not-reached marker in a four-bit table.
    /// - **Nothing is left unreached**, so every state really is within nine.
    /// - **The goal is at zero.**
    @Test
    def thePhaseOneTablesAreClosedBoundedAndComplete(): Unit \ Assert =
        let p = phase1();
        let k = Standard.moveCount();

        // move tables: a move and its inverse return the coordinate
        let checkClosed = (table, count, what) ->
            Vector.range(0, count) |> Vector.forEach(r ->
                Vector.range(0, k) |> Vector.forEach(m -> {
                    let inverse = CubeSolve.Model.Move.index(
                        CubeSolve.Model.Move.inverse(Standard.moveOfIndex(m)));
                    let there = Table.get(r * k + m, table);
                    Assert.assertTrueWithMsg(there >= 0 and there < count,
                        "${what} ${r} under move ${m} left the range");
                    Assert.assertEqWithMsg(
                        expected = r, Table.get(there * k + inverse, table),
                        "${what} ${r} did not survive move ${m} and its inverse")
                }));
        checkClosed(Standard.twistMoveTable(p), Standard.twistCount(), "twist");
        checkClosed(Standard.flipMoveTable(p), Standard.flipCount(), "flip");
        checkClosed(Standard.sliceMoveTable(p), Standard.sliceCount(), "slice");

        // pruning tables: bounded by 9, complete, zero at the goal
        let checkPruning = (table, count, goal, what) -> {
            let worst = Vector.range(0, count)
                |> Vector.foldLeft((acc, i) -> Int32.max(acc, Table.get(i, table)), 0);
            Assert.assertEqWithMsg(expected = 9, worst,
                "${what} should reach depth 9 exactly, not ${worst}");
            Assert.assertEqWithMsg(expected = 0, Table.get(goal, table),
                "${what} should be zero at the goal");
            let unreached = Vector.range(0, count)
                |> Vector.count(i -> Table.get(i, table) == Table.widest(4));
            Assert.assertEqWithMsg(expected = 0, unreached,
                "${what} left ${unreached} states unreached")
        };
        checkPruning(
            Standard.twistSliceTable(p),
            Standard.twistCount() * Standard.sliceCount(),
            0 * Standard.sliceCount() + Standard.solvedSlice(),
            "Twist x UDSlice");
        checkPruning(
            Standard.flipSliceTable(p),
            Standard.flipCount() * Standard.sliceCount(),
            0 * Standard.sliceCount() + Standard.solvedSlice(),
            "Flip x UDSlice");
        checkPruning(
            Standard.flipTwistTable(p),
            Standard.flipCount() * Standard.twistCount(),
            0,
            "Flip x Twist")

}
