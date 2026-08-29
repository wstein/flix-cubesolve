mod TestCacheOnDisk {

    use CubeSolve.Table
    use CubeSolve.Table.Cache
    use CubeSolve.Table.Cache.Disk
    use CubeSolve.Table.Codec

    def header(generator: String): Codec.Header =
        Codec.header({
            table = "pocket.distances",
            convention = "kociemba-htm@1",
            generator = generator
        })

    ///
    /// The real handler chain is `Cache.Disk.withFilesystem`, and using it here is
    /// the point:
    /// the in-memory tests cover the policy, so what is left untested is the
    /// plumbing -- the filesystem handler, the staging directory and the atomic
    /// move. A chain assembled here instead would be a second chain, and the
    /// one consumers use would still have no coverage.
    ///
    def table(seed: Int32): Result[String, Table.TableView] =
        Table.ofValues(8, Vector.init(i -> Int32.modulo(i + seed, 200), 400))

    ///
    /// A table survives a round trip through actual files, and a second run
    /// reads it back instead of rebuilding.
    ///
    /// This is the path a consumer takes, and until now nothing exercised it:
    /// the in-memory store proved the policy and left the filesystem handler,
    /// the staging directory and the atomic move untested.
    ///
    @Test
    def theCacheRoundTripsThroughRealFiles(): Unit \ Assert + IO = region rc {
        let builds = Ref.fresh(rc, 0);
        let build = () -> { Ref.put(Ref.get(builds) + 1, builds); table(0) };
        match Fs.FileWrite.runWithIO(_ -> Fs.FileWrite.mkTempDir("cubesolve-test-")) {
            case Err(_) =>
                Assert.assertTrueWithMsg(false, "could not make a temporary directory")
            case Ok(dir) =>
                let once = () ->
                    Disk.withFilesystem(dir, () ->
                        Cache.table("pocket.distances", header("t"), build));
                let first = once();
                let second = once();
                Assert.assertOk(first);
                Assert.assertOk(second);
                Assert.assertEqWithMsg(expected = 1, Ref.get(builds),
                    "the second run should have read the file, not rebuilt it");
                match (first, second) {
                    case (Ok(a), Ok(b)) =>
                        Assert.assertEq(expected = Table.entries(a), Table.entries(b));
                        Vector.range(0, Table.entries(a)) |> Vector.forEach(i ->
                            Assert.assertEqWithMsg(
                                expected = Table.get(i, a), Table.get(i, b),
                                "entry ${i} came back changed"))
                    case _ => Assert.assertTrueWithMsg(false, "both runs should succeed")
                }
        }
    }

    ///
    /// A file on disk written by another build is rebuilt rather than trusted.
    ///
    /// The end-to-end form of the codec's rule: seed the directory under one
    /// generator, read it under another, and the table must be rebuilt.
    ///
    @Test
    def aFileFromAnotherBuildIsRebuilt(): Unit \ Assert + IO = region rc {
        let builds = Ref.fresh(rc, 0);
        let build = () -> { Ref.put(Ref.get(builds) + 1, builds); table(0) };
        match Fs.FileWrite.runWithIO(_ -> Fs.FileWrite.mkTempDir("cubesolve-test-")) {
            case Err(_) =>
                Assert.assertTrueWithMsg(false, "could not make a temporary directory")
            case Ok(dir) =>
                let seeded = Disk.withFilesystem(dir,
                    () -> Cache.table("pocket.distances", header("cubesolve 0.0.9"), build));
                Assert.assertOk(seeded);
                let why = Disk.withFilesystem(dir,
                    () -> Cache.reasonToRebuild("pocket.distances", header("cubesolve 9.9.9")));
                match why {
                    case None    => Assert.assertTrueWithMsg(false, "the build differs")
                    case Some(w) =>
                        Assert.assertTrueWithMsg(
                            String.contains(substr = "0.0.9", w),
                            "the reason should name the build that wrote it: ${w}")
                };
                let again = Disk.withFilesystem(dir,
                    () -> Cache.table("pocket.distances", header("cubesolve 9.9.9"), build));
                Assert.assertOk(again);
                Assert.assertEqWithMsg(expected = 2, Ref.get(builds),
                    "a file from another build should have forced exactly one rebuild")
        }
    }

}
