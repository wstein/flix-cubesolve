mod TestCache {

    use CubeSolve.Table
    use CubeSolve.Table.Cache
    use CubeSolve.Table.Cache.Store
    use CubeSolve.Table.Codec

    def header(): Codec.Header =
        Codec.header({
            table = "pocket.distances",
            convention = "kociemba-htm@1",
            generator = "cubesolve 0.4.2"
        })

    def table(seed: Int32): Result[String, Table.TableView] =
        Table.ofValues(8, Vector.init(i -> Int32.modulo(i + seed, 200), 500))

    ///
    /// Run `f` with a cache held in a map, and report what it ended up holding.
    ///
    /// This is the point of making the store an effect: the caching logic is
    /// exercised exactly as it runs in production, with no filesystem anywhere
    /// near the test.
    ///
    def inMemory(
        rc: Region[r],
        f: Unit -> a \ ef
    ): (a, Int32) \ (ef - Store) + r =
        let kept = Ref.fresh(rc, Map#{});
        let writes = Ref.fresh(rc, 0);
        let result = run { f() } with handler Store {
            def load(key, k) = k(Map.get(key, Ref.get(kept)))
            def save(key, bytes, k) = {
                Ref.put(Map.insert(key, bytes, Ref.get(kept)), kept);
                Ref.put(Ref.get(writes) + 1, writes);
                k(())
            }
        };
        (result, Ref.get(writes))

    /// The first call builds and keeps; the second reads back and does not
    /// build again. That is the whole purpose, so it is the first thing tested.
    @Test
    def theSecondCallReadsTheCacheInsteadOfBuilding(): Unit \ Assert = region rc {
        let builds = Ref.fresh(rc, 0);
        let build = () -> { Ref.put(Ref.get(builds) + 1, builds); table(0) };
        let (results, writes) = inMemory(rc, () -> {
            let first = Cache.table("pocket.distances", header(), build);
            let second = Cache.table("pocket.distances", header(), build);
            (first, second)
        });
        let (first, second) = results;
        Assert.assertEqWithMsg(expected = 1, Ref.get(builds),
            "the table should have been built once, not ${Ref.get(builds)} times");
        Assert.assertEqWithMsg(expected = 1, writes,
            "the table should have been written once, not ${writes} times");
        match (first, second) {
            case (Ok(a), Ok(b)) =>
                Assert.assertEq(expected = Table.entries(a), Table.entries(b));
                Vector.range(0, Table.entries(a)) |> Vector.forEach(i ->
                    Assert.assertEqWithMsg(
                        expected = Table.get(i, a), Table.get(i, b), "entry ${i}"))
            case _ => Assert.assertTrueWithMsg(false, "both calls should succeed")
        }
    }

    /// An empty cache reports a miss rather than an error.
    @Test
    def anEmptyCacheIsAMissAndSaysSo(): Unit \ Assert = region rc {
        let (reason, _) = inMemory(rc, () ->
            Cache.reasonToRebuild("pocket.distances", header()));
        match reason {
            case None    => Assert.assertTrueWithMsg(false, "an empty cache is a miss")
            case Some(w) => Assert.assertTrue(String.contains(substr = "nothing is cached", w))
        }
    }

    /// A cache written under another convention is a miss, and the reason says
    /// which -- not an outage, and not a silently wrong table.
    @Test
    def aCacheFromAnotherConventionIsRebuiltAndTheReasonGiven(): Unit \ Assert = region rc {
        let foreign = Codec.header({
            table = "pocket.distances",
            convention = "some-other-numbering@1",
            generator = "cubesolve 0.4.2"
        });
        let builds = Ref.fresh(rc, 0);
        let build = () -> { Ref.put(Ref.get(builds) + 1, builds); table(0) };
        let (reason, _) = inMemory(rc, () -> {
            // seed the cache under the wrong convention
            let _seeded = Cache.table("pocket.distances", foreign, build);
            let why = Cache.reasonToRebuild("pocket.distances", header());
            // and confirm it is rebuilt rather than refused
            let _rebuilt = Cache.table("pocket.distances", header(), build);
            why
        });
        match reason {
            case None    => Assert.assertTrueWithMsg(false, "the convention differs")
            case Some(w) => Assert.assertTrue(String.contains(substr = "convention", w))
        };
        Assert.assertEqWithMsg(expected = 2, Ref.get(builds),
            "the foreign cache should have forced exactly one rebuild")
    }

    /// A damaged cache is a miss too. A half-written file should cost a rebuild
    /// and nothing more.
    @Test
    def aDamagedCacheIsRebuilt(): Unit \ Assert = region rc {
        let kept = Ref.fresh(rc, Map#{});
        let builds = Ref.fresh(rc, 0);
        let build = () -> { Ref.put(Ref.get(builds) + 1, builds); table(0) };
        let outcome = run {
            let _first = Cache.table("pocket.distances", header(), build);
            Cache.table("pocket.distances", header(), build)
        } with handler Store {
            def load(key, k) =
                // hand back a truncated file, as an interrupted write would
                let truncate = bs -> Vector.take(20, bs);
                k(Map.get(key, Ref.get(kept)) |> Option.map(truncate))
            def save(key, bytes, k) = {
                Ref.put(Map.insert(key, bytes, Ref.get(kept)), kept);
                k(())
            }
        };
        Assert.assertOk(outcome);
        Assert.assertEqWithMsg(expected = 2, Ref.get(builds),
            "a damaged cache should force a rebuild every time it is read")
    }

    /// A store that keeps nothing still works. The engine is slow without a
    /// cache, not broken, and `withoutCache` is the honest way to say so.
    @Test
    def theEngineWorksWithNoCacheAtAll(): Unit \ Assert =
        let built = Cache.withoutCache(() ->
            Cache.table("pocket.distances", header(), () -> table(0)));
        Assert.assertOk(built);
        let missed = Cache.withoutCache(() ->
            Cache.reasonToRebuild("pocket.distances", header()));
        Assert.assertSome(missed)

    /// A failure to build is reported rather than cached.
    @Test
    def aBuildThatFailsIsNotCached(): Unit \ Assert = region rc {
        let (outcome, writes) = inMemory(rc, () ->
            Cache.table("pocket.distances", header(), () -> Err("the build failed")));
        Assert.assertErr(outcome);
        Assert.assertEqWithMsg(expected = 0, writes, "a failed build should keep nothing")
    }

    /// The real 2x2x2 tables go through the cache, and a second run reads all
    /// five back rather than rebuilding any of them.
    ///
    /// Counted rather than timed: the second run must write nothing, which is
    /// only true if every one of the five was found and accepted.

    @Test
    def theRealTablesAreCachedAndNotRebuilt(): Unit \ Assert = region rc {
        let kept = Ref.fresh(rc, Map#{});
        let writes = Ref.fresh(rc, 0);
        let both = run {
            let first = CubeSolve.Table.Pocket.cachedTables();
            let after = Ref.get(writes);
            let second = CubeSolve.Table.Pocket.cachedTables();
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
        Assert.assertEqWithMsg(expected = 5, afterFirst,
            "the first run should have written all five 2x2x2 tables");
        Assert.assertEqWithMsg(expected = 5, Ref.get(writes),
            "the second run should have written nothing, but the total reached "
                + "${Ref.get(writes)}");
        // and the cached tables really are the same tables
        match (first, second) {
            case (Ok(a), Ok(b)) =>
                let da = CubeSolve.Table.Pocket.distanceTable(a);
                let db = CubeSolve.Table.Pocket.distanceTable(b);
                Assert.assertEq(expected = Table.entries(da), Table.entries(db));
                Vector.range(0, 5000) |> Vector.forEach(i ->
                    Assert.assertEqWithMsg(
                        expected = Table.get(i, da), Table.get(i, db),
                        "cached distance ${i}"))
            case _ => Assert.assertTrueWithMsg(false, "both runs should succeed")
        }
    }

}
