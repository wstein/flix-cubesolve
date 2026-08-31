///
/// The first-two-layer tables, and that they are cached.
///
/// Split from `TestCache`, which covers the cache itself -- headers, damage,
/// staging, rebuild reasons -- because reaching into the solver as well took
/// that module over the coupling threshold. The subject here is one claim about
/// one set of tables.
///
mod TestCacheTwoLayers {

    use CubeSolve.Table.Cache.Store

    ///
    /// The first-two-layer tables are cached, and a second call rebuilds none.
    ///
    /// This is the test that was missing. `Solve.TwoLayers.build` went through
    /// no cache at all, so `--method cfop` and `--method beginner` rebuilt 3.8
    /// million states on every invocation -- about a hundred seconds each time,
    /// warm or cold, with the second run no faster than the first. Nothing
    /// caught it because nothing asserted it, and the tables were correct.
    ///
    /// Written against writes rather than against elapsed time, for the reason
    /// the whole suite prefers: a slow machine is not a regression, and a second
    /// build that writes nothing is the actual claim.
    ///
    @Test
    def theTwoLayerTablesAreCachedAndNotRebuilt(): Unit \ Assert = region rc {
        let kept = Ref.fresh(rc, Map#{});
        let writes = Ref.fresh(rc, 0);
        let both = run {
            let first = CubeSolve.Solve.TwoLayers.cachedTables();
            let after = Ref.get(writes);
            let second = CubeSolve.Solve.TwoLayers.cachedTables();
            (first, after, second)
        } with handler Store {
            def load(key, k) = k(Map.get(key, Ref.get(kept)))
            def save(key, bytes, k) = {
                Ref.put(Map.insert(key, bytes, Ref.get(kept)), kept);
                Ref.put(Ref.get(writes) + 1, writes);
                k(())
            }
        };
        let (first, afterFirst, second) = both;
        Assert.assertOk(first);
        Assert.assertOk(second);
        Assert.assertEqWithMsg(expected = 4, afterFirst,
            "the first run should have written all four first-two-layer tables");
        Assert.assertEqWithMsg(expected = 4, Ref.get(writes),
            "the second run should have written nothing, but the total reached "
                + "${Ref.get(writes)}")
    }
}
