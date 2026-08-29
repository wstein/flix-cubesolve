///
/// Where the command line keeps its tables between runs.
///
/// A module of its own so that the commands can ask for a cache without also
/// acquiring the filesystem: `CubeSolve.Table.Cache` goes to some lengths to
/// stay free of `IO`, and a caller that reaches for `Fs` alongside it throws
/// that away.
///
mod CubeSolve.Cli.Store {

    use CubeSolve.Table.Cache
    use CubeSolve.Table.Cache.Disk

    ///
    /// Do `f` with the table cache on disk.
    ///
    /// A cache that cannot be reached is not a failure to solve: the handler
    /// falls back to building, which is slow and correct. So this returns the
    /// work's own result, never a cache error.
    ///
    pub def cached(f: Unit -> Result[String, a] \ Cache.Store): Result[String, a] \ IO =
        Disk.withFilesystem(directory(), f)

    ///
    /// The cache directory, made if it is not there.
    ///
    /// `XDG_CACHE_HOME` if the platform sets it, `~/.cache` otherwise, and the
    /// working directory if there is no home either -- a strange place to be,
    /// but one that always exists.
    ///
    pub def directory(): String \ IO =
        Sys.Env.runWithIO(_ -> {
            let dir = "${base(Sys.Env.getEnv())}/cubesolve";
            let _ = Fs.FileWrite.runWithIO(_ -> Fs.FileWrite.mkDirs(dir));
            dir
        })

    ///
    /// The directory caches go under on this platform.
    ///
    def base(env: Map[String, String]): String =
        match Map.get("XDG_CACHE_HOME", env) {
            case Some(x) => x
            case None    => match Map.get("HOME", env) {
                case Some(h) => "${h}/.cache"
                case None    => "."
            }
        }

}
