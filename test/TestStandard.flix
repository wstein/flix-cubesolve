mod TestStandard {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized
    use CubeSolve.Table
    use CubeSolve.Table.Standard

    /// Every phase-one table. Three breadth-first sweeps over 6.6 million
    /// states between them, so tests that need it build it once and assert a
    /// great deal.

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
}
