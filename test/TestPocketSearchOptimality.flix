mod TestPocketSearchOptimality {

    use CubeSolve.Table

    /// Optimality over a stratification chosen from measurement, not taste.
    ///
    /// Verifying optimality exhaustively would run a search per state. Measured
    /// on this implementation the deepest states cost about 226,000 nodes each,
    /// so all 2,644 of them alone would be roughly 6 x 10^8 nodes and some
    /// three minutes -- and the full 3,674,160 would be hours. That is a
    /// nightly job, not a gate, and pretending otherwise would mean a gate
    /// nobody ever lets finish.
    ///
    /// So: exhaustive where the class is small, sampled where it is not, and
    /// the split named rather than left implicit.
    ///
    /// - **Exhaustive** over every state within four moves, all 2,232 of them.
    /// - **A fixed stride** across the whole space, covering every distance
    ///   class in proportion to its size. A stride rather than a random sample
    ///   because it reproduces without carrying a seed, and because the
    ///   coordinate's ordering has nothing to do with distance.
    /// - **The deepest class sampled**, which is where the search works
    ///   hardest.
    ///
    /// Every solution is also replayed through the model, so a length that
    /// matches the oracle but does not actually solve the cube fails here.
    @Test
    def theStratifiedSampleIsSolvedOptimally(): Unit \ Assert + IO =
        if (Slow.skip("TestPocketSearchOptimality.theStratifiedSampleIsSolvedOptimally",
                "solves a stratified sample optimally"))
            ()
        else {
            let t = PocketSearchTestSupport.tables();
            let d = Table.Pocket.distanceTable(t);
            let shallow = Vector.range(0, Table.Pocket.stateCount())
                |> Vector.filter(i -> Table.get(i, d) <= 4);
            Assert.assertEqWithMsg(expected = 2232, Vector.length(shallow),
                "the classes within four moves should hold 2,232 states");
            shallow |> Vector.forEach(s -> PocketSearchTestSupport.assertOptimal(t, s));

            let stride = 3673;
            Vector.range(0, 600) |> Vector.forEach(step ->
                PocketSearchTestSupport.assertOptimal(t,
                    Int32.modulo(step * stride + 7, Table.Pocket.stateCount())));

            let deepest = PocketSearchTestSupport.deepestStates(t);
            Assert.assertEqWithMsg(expected = 2644, Vector.length(deepest),
                "there should be 2,644 states at distance 11");
            deepest |> Vector.take(60) |> Vector.forEach(s ->
                PocketSearchTestSupport.assertOptimal(t, s))
        }

}
