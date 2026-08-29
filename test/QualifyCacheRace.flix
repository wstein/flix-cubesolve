///
/// The two-process half of Gate 13.2, which no `@Test` can reach.
///
/// `TestCacheOnDisk.twoThreadsRacingOnOneDirectoryLeaveOneValidCache` races two
/// threads and runs on every commit, but two threads share a JVM, a runtime and
/// one table of open file handles. The staging defect this gate exists to
/// exclude lives exactly where they do not: two operating-system processes, each
/// with its own open file, each issuing its own rename onto one name. Proving
/// that needs real processes, so it needs an entry point and a jar, and it can
/// therefore not be a test function.
///
/// It lives under `test/` all the same. `--entrypoint` reaches a definition here
/// perfectly well, so the harness never enters `src/` and the library still
/// ships no `main` for a consumer to collide with.
///
/// Driven by `scripts/qualify-cache-race.sh`; see that script for the sequence.
///
mod QualifyCacheRace {

    use CubeSolve.Table
    use CubeSolve.Table.TableView
    use CubeSolve.Table.Cache
    use CubeSolve.Table.Cache.Disk
    use CubeSolve.Table.Pocket

    ///
    /// `child <dir>` generates into `dir`; `verify <dir>` reads back what is
    /// there. Exit status is the result: 0 for what was asked, 1 otherwise.
    ///
    pub def qualify(): Unit \ IO =
        Sys.Exit.runWithIO(_ ->
            Sys.Env.runWithIO(_ -> match Sys.Env.getArgs() {
                case "child" :: dir :: Nil  => finish(generate(dir))
                case "verify" :: dir :: Nil => finish(readBack(dir))
                case _                      =>
                    println("usage: child <dir> | verify <dir>");
                    Sys.Exit.exit(2)
            }))

    ///
    /// Report `outcome` and exit with its verdict.
    ///
    def finish(outcome: Result[String, String]): Unit \ IO + Sys.Exit =
        match outcome {
            case Ok(what)  => println("ok: ${what}"); Sys.Exit.exit(0)
            case Err(why) => println("failed: ${why}"); Sys.Exit.exit(1)
        }

    ///
    /// Build the 2x2x2 tables with `dir` as the cache -- the production
    /// first-run path, not a stand-in for it.
    ///
    /// `Pocket.cachedTables` is what a consumer calls, and on a cold directory
    /// it builds every table and writes each one. That the build takes real time
    /// is the point: it is what holds two processes inside the window where they
    /// can collide.
    ///
    def generate(dir: String): Result[String, String] \ IO =
        Disk.withFilesystem(dir, Pocket.cachedTables)
            |> Result.map(_ -> "generated into ${dir}")

    ///
    /// Read the directory back, refusing to rebuild anything.
    ///
    /// The build function passed to the cache fails, so a table that reaches us
    /// came off the disk. A file the race left torn, truncated or interleaved
    /// fails its digest, counts as a miss, and lands here as that failure rather
    /// than being quietly regenerated -- which is the whole reason this checks
    /// through the cache instead of stat-ing the files.
    ///
    def readBack(dir: String): Result[String, String] \ IO =
        forM (
            fromDisk <- Disk.withFilesystem(dir, () ->
                Cache.table("pocket.distances", Pocket.headerFor("pocket.distances"),
                    () -> Err("nothing readable survived the race")));
            fresh <- Pocket.build() |> Result.map(Pocket.distanceTable)
            ;
            checked <- verdict(fresh, fromDisk)
        ) yield checked

    ///
    /// Whether two tables agree entry for entry.
    ///
    def sameTable(a: TableView, b: TableView): Bool =
        Table.entries(a) == Table.entries(b) and
            Vector.range(0, Table.entries(a))
                |> Vector.forAll(i -> Table.get(i, a) == Table.get(i, b))

    ///
    /// What to report about the table the race published.
    ///
    /// A table that decodes but differs is a worse finding than a missing one:
    /// the digest passed, so it is not a torn write but two writers producing
    /// genuinely different bytes. Name that, rather than letting it read as an
    /// ordinary failure.
    ///
    def verdict(fresh: TableView, fromDisk: TableView): Result[String, String] =
        if (sameTable(fresh, fromDisk))
            Ok("the published table matches a fresh build, "
                + "${Table.entries(fresh)} entries")
        else
            Err("BUG: the published table decoded but differs from a fresh "
                + "build -- the digest passed, so this is not a torn write")

}
