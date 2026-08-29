///
/// Running the table cache against the real filesystem.
///
/// This is kept apart from `CubeSolve.Table.Cache` on purpose. That module is
/// policy -- what makes a cached table acceptable -- and is deliberately free of
/// `IO`, so it can be tested with a map where a disk would go. This module is
/// the wiring to an actual disk, and nothing else is in it. Putting the two
/// together would give the policy module a dependency on every filesystem
/// effect it exists to avoid naming.
///
mod CubeSolve.Table.Cache.Disk {

    use CubeSolve.Table.Cache
    use CubeSolve.Table.Cache.Store
    use Fs.FileExists
    use Fs.MkTempDir
    use Fs.MoveFile
    use Fs.ReadBytes
    use Fs.WriteBytes

    ///
    /// `onFilesystem` with every filesystem effect discharged against the real
    /// one -- the whole chain a consumer needs, in one call.
    ///
    /// `onFilesystem` deliberately leaves the five filesystem effects open, so
    /// that a test can supply a map instead of a disk and the acceptance logic
    /// never acquires `IO`. That is right for the policy and a burden on
    /// everyone who just wants the cache: eight nested handlers, in an order
    /// that has to be correct, to say "use these files". This is that order,
    /// written once.
    ///
    pub def withFilesystem(directory: String, f: Unit -> a \ ef): a \
        (((((((ef - Store) - FileExists) - ReadBytes) - WriteBytes)
            - MoveFile) - MkTempDir) - Fs.FileTest - Fs.FileRead) - Fs.FileWrite + IO =
        Fs.FileWrite.runWithIO(_ ->
            Fs.FileRead.runWithIO(_ ->
                Fs.FileTest.runWithIO(_ ->
                    Fs.MkTempDir.runWithFileWrite(_ ->
                        Fs.MoveFile.runWithFileWrite(_ ->
                            Fs.WriteBytes.runWithFileWrite(_ ->
                                Fs.ReadBytes.runWithFileRead(_ ->
                                    Fs.FileExists.runWithFileTest(_ ->
                                        Cache.onFilesystem(directory, f)))))))))

}
