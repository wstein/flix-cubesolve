///
/// That the frontier-free builder agrees with the one it exists to replace.
///
/// `Table.distancesBySweep` is for tables too large to hold a frontier -- two
/// `Int32` arrays the size of the state space is a gigabyte once a table has a
/// hundred million states. It is only worth having if it produces exactly the
/// table `distancesFrom` produces, so that is what is checked: entry by entry,
/// over whole real tables, not a sample.
///
/// A builder that agreed "mostly" would be worse than none. A pruning table one
/// short anywhere is inadmissible, and an inadmissible heuristic does not fail
/// loudly -- it quietly returns longer answers, or claims a state is unreachable
/// when it is not.
///
mod TestSweepBuilder {

    use CubeSolve.Table

    ///
    /// The two builders agree on the cross table, entry for entry.
    ///
    /// 190,080 states and eight deep: small enough to build twice in a test and
    /// large enough that an off-by-one in the sweep would show.
    ///
    @Test
    def theSweepAgreesWithTheFrontierOnTheCrossTable(): Unit \ Assert + IO =
        if (Slow.skip("TestSweepBuilder.theSweepAgreesWithTheFrontierOnTheCrossTable",
                "builds the cross table twice"))
            ()
        else
            agreeOn(
                { states = CubeSolve.Table.Cross.stateCount(),
                  goal = CubeSolve.Table.Cross.solvedIndex(),
                  moves = CubeSolve.Table.Cross.moveCount(),
                  bits = 4 },
                CubeSolve.Table.Cross.successor)

    ///
    /// And on the first-layer corners, which is a different shape of space.
    ///
    /// The cross is edges; this is corners with three orientations rather than
    /// two, and seven deep rather than eight. Agreeing on one shape is weaker
    /// evidence than agreeing on two.
    ///
    @Test
    def theSweepAgreesWithTheFrontierOnTheFirstLayerTable(): Unit \ Assert + IO =
        if (Slow.skip("TestSweepBuilder.theSweepAgreesWithTheFrontierOnTheFirstLayerTable",
                "builds the first-layer table twice"))
            ()
        else
            agreeOn(
                { states = CubeSolve.Table.FirstLayer.stateCount(),
                  goal = CubeSolve.Table.FirstLayer.solvedIndex(),
                  moves = CubeSolve.Table.FirstLayer.moveCount(),
                  bits = 4 },
                CubeSolve.Table.FirstLayer.successor)

    ///
    /// Both builders, every entry compared.
    ///
    def agreeOn(
        shape: { states = Int32, goal = Int32, moves = Int32, bits = Int32 },
        successor: (Int32, Int32) -> Int32
    ): Unit \ Assert =
        match (Table.distancesFrom(shape, successor),
               Table.distancesBySweep(shape, successor)) {
            case (Ok(a), Ok(b)) =>
                Assert.assertEqWithMsg(expected = Table.entries(a), Table.entries(b),
                    "the two builders should fill the same number of entries");
                let differing = Vector.range(0, shape#states)
                    |> Vector.count(i -> Table.get(i, a) != Table.get(i, b));
                Assert.assertEqWithMsg(expected = 0, differing,
                    "${differing} entries differ between the frontier builder and "
                        + "the sweep")
            case (Err(e), _) => Assert.assertEqWithMsg(expected = "", e, "frontier build")
            case (_, Err(e)) => Assert.assertEqWithMsg(expected = "", e, "sweep build")
        }
}
