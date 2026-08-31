///
/// The phase-one tables: closed, bounded and complete.
///
/// Split from `TestStandard`, which checks the coordinates that index these.
/// Building and closing the tables is twenty seconds and the coordinate checks
/// are milliseconds, so they are gated differently -- and one module doing both
/// reached one module too many.
///
mod TestStandardTables {

    use CubeSolve.Table
    use CubeSolve.Table.Standard

    ///
    /// The phase-one tables, built once for this module.
    ///
    def phase1(): Standard.Tables \ Assert =
        match Standard.build() {
            case Ok(p)  => p
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the phase-one tables");
                unreachable!()
        }

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
    def thePhaseOneTablesAreClosedBoundedAndComplete(): Unit \ Assert + IO =
        if (Slow.skip("TestStandardTables.thePhaseOneTablesAreClosedBoundedAndComplete",
                "builds and closes the phase-one tables"))
            ()
        else {
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
        }
