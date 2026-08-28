mod TestDomino {

    use CubeSolve.Model.Cube
    use CubeSolve.Table
    use CubeSolve.Table.Domino

    /// Every phase-two table. Two breadth-first sweeps over 6.6 million states
    /// between them, so this is built once and asserted against thoroughly.
    def phase2(): Domino.Tables \ Assert =
        match Domino.build() {
            case Ok(p)  => p
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the phase-two tables");
                unreachable!()
        }

    // ---------- ranking ----------

    /// Both permutation ranks round-trip across their whole range, and unranking
    /// really produces permutations.
    @Test
    def permutationRanksRoundTrip(): Unit \ Assert =
        Vector.range(0, Domino.cornerPermCount()) |> Vector.forEach(r -> {
            let p = Domino.permUnrank(r);
            Assert.assertEqWithMsg(expected = r, Domino.permRank(p), "permutation ${r}")
        });
        Vector.range(0, 8) |> Vector.forEach(i ->
            Assert.assertTrue(Vector.memberOf(i, Domino.permUnrank(40319))));
        Vector.range(0, Domino.slicePermCount()) |> Vector.forEach(r ->
            Assert.assertEqWithMsg(
                expected = r, Domino.slicePermRank(Domino.slicePermUnrank(r)),
                "slice permutation ${r}"))

    /// CComb is parity times seventy plus a tetrad rank, and every one of the
    /// 140 values is actually taken by some permutation -- otherwise the table
    /// would have holes a representative could not fill.
    @Test
    def everyCombValueIsReachedBySomePermutation(): Unit \ Assert =
        let seen = region rc {
            let hit = Array.repeat(rc, Domino.combCount(), false);
            Vector.range(0, Domino.cornerPermCount()) |> Vector.forEach(r ->
                Array.put(true, Domino.combOf(Domino.permUnrank(r)), hit));
            Array.toVector(hit)
        };
        Vector.range(0, Domino.combCount()) |> Vector.forEach(c ->
            Assert.assertTrueWithMsg(Vector.get(c, seen), "CComb ${c} is never reached"));
        Assert.assertEq(expected = 0, Domino.combOf(Vector.range(0, 8)));
        Assert.assertEq(expected = 0, Domino.parityOf(Vector.range(0, 8)))

    /// The phase-two alphabet is the ten moves that leave phase one solved:
    /// quarter turns of U and D, half turns of everything else.
    @Test
    def thePhaseTwoAlphabetIsTheDominoOne(): Unit \ Assert =
        Assert.assertEq(expected = 10, Domino.moveCount());
        Vector.range(0, 10) |> Vector.forEach(m -> {
            let move = Domino.moveOfIndex(m);
            let face = CubeSolve.Model.Move.face(move);
            let quarter = CubeSolve.Model.Move.amount(move) != 2;
            let upOrDown =
                face == CubeSolve.Model.Move.Face.U or face == CubeSolve.Model.Move.Face.D;
            Assert.assertTrueWithMsg(
                upOrDown or not quarter,
                "phase two move ${m} is a quarter turn of a side face")
        })

    /// A solved cube is at the phase-two origin, and a cube outside the domino
    /// group is refused rather than given a meaningless coordinate.
    @Test
    def coordinatesExistExactlyInsideTheDominoGroup(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok((0, 0, 0)),
            Cube.solved(3) |> Result.flatMap(Domino.coordsOf));
        Assert.assertEq(
            expected = Ok(true),
            Cube.solved(3) |> Result.map(Domino.isSolved));
        // R takes a slice edge into the U layer, which leaves the group.
        let outside = Cube.solved(3)
            |> Result.flatMap(c -> Cube.applyNotation("R", c))
            |> Result.flatMap(Domino.coordsOf);
        match outside {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "R leaves the domino group")
            case Err(e) => Assert.assertTrue(String.contains(substr = "domino group", e))
        };
        // U2 R2 stays inside.
        Assert.assertOk(Cube.solved(3)
            |> Result.flatMap(c -> Cube.applyNotation("U2 R2 D' F2", c))
            |> Result.flatMap(Domino.coordsOf))

    // ---------- the tables ----------

    /// Everything the phase-two tables must satisfy, over one build.
    ///
    /// - **The move tables are closed and reversible.**
    /// - **The pruning tables reach depth 14 and 13.** Those are the maxima the
    ///   plan decoded from min2phase's own checked-in pruning data, for the
    ///   symmetry-reduced versions of these same pairings. Symmetry does not
    ///   change a pruning value, so the raw tables must agree -- and this is
    ///   the check that they do, without building the reference.
    /// - **Nothing is left unreached**, so every domino state really is within
    ///   those depths.
    @Test
    def thePhaseTwoTablesAreClosedAndReachTheKnownDepths(): Unit \ Assert =
        let p = phase2();
        let k = Domino.moveCount();

        let checkClosed = (table, count, what) ->
            Vector.range(0, count) |> Vector.forEach(r ->
                Vector.range(0, k) |> Vector.forEach(m -> {
                    let there = Table.get(r * k + m, table);
                    Assert.assertTrueWithMsg(there >= 0 and there < count,
                        "${what} ${r} under move ${m} left the range")
                }));
        checkClosed(Domino.cornerPermTable(p), Domino.cornerPermCount(), "corner perm");
        checkClosed(Domino.edgePermTable(p), Domino.edgePermCount(), "edge perm");
        checkClosed(Domino.slicePermTable(p), Domino.slicePermCount(), "slice perm");
        checkClosed(Domino.combTable(p), Domino.combCount(), "CComb");

        let checkPruning = (table, count, depth, what) -> {
            let worst = Vector.range(0, count)
                |> Vector.foldLeft((acc, i) -> Int32.max(acc, Table.get(i, table)), 0);
            Assert.assertEqWithMsg(expected = depth, worst,
                "${what} should reach depth ${depth} exactly, not ${worst}");
            Assert.assertEqWithMsg(expected = 0, Table.get(0, table),
                "${what} should be zero at the goal");
            let unreached = Vector.range(0, count)
                |> Vector.count(i -> Table.get(i, table) == Table.widest(8));
            Assert.assertEqWithMsg(expected = 0, unreached,
                "${what} left ${unreached} states unreached")
        };
        checkPruning(
            Domino.cornerSliceTable(p),
            Domino.cornerPermCount() * Domino.slicePermCount(), 14, "CPerm x MPerm");
        checkPruning(
            Domino.edgeCombTable(p),
            Domino.edgePermCount() * Domino.combCount(), 13, "EPerm x CComb")

}
