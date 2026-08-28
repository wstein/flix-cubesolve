///
/// Keeping built tables, so they are built once.
///
/// The tables are pure and deterministic and expensive: the 3x3x3's phase
/// tables are several breadth-first sweeps over millions of states, and a
/// consumer that rebuilt them on every run would pay that every time.
///
/// **The cache is an effect, not a filesystem.** `Store` says only that bytes
/// can be fetched and kept under a key. The filesystem is one handler of it,
/// `onFilesystem`; a test uses another; and `withoutCache` is a third that
/// always misses and keeps nothing. So the caching logic is written once and
/// tested without touching a disk, and the code that decides *whether* a cached
/// table is acceptable never gains an `IO` effect.
///
/// **A corrupt or foreign cache is a miss, not a failure.** A half-written file
/// or one from another convention should cost a rebuild, not an outage. What
/// is *not* silent is which of those happened: `reasonToRebuild` returns it, so
/// a caller that wants to warn can.
///
mod CubeSolve.Table.Cache {

    use CubeSolve.Table.Codec
    use CubeSolve.Table.TableView
    use Fs.FileExists
    use Fs.MoveFile
    use Fs.ReadBytes
    use Fs.WriteBytes

    ///
    /// Somewhere bytes can be kept and fetched under a key.
    ///
    pub eff Store {

        ///
        /// The bytes kept under `key`, or nothing.
        ///
        def load(key: String): Option[Vector[Int8]]

        ///
        /// Keep `bytes` under `key`.
        ///
        /// Best effort: a store that cannot keep anything is a store that
        /// always misses, which is a slow cache and not a broken engine.
        ///
        def save(key: String, bytes: Vector[Int8]): Unit

    }

    ///
    /// The table under `key`, built by `build` if the cache cannot supply it.
    ///
    /// A cached table is used only if it decodes, its checksum holds, and its
    /// header says it is this table under this convention. Anything else is a
    /// miss, and the rebuilt table replaces it.
    ///
    pub def table(
        key: String,
        wanted: Codec.Header,
        build: Unit -> Result[String, TableView] \ ef
    ): Result[String, TableView] \ ef + Store =
        match cached(key, wanted) {
            case Some(t) => Ok(t)
            case None    => buildAndKeep(key, wanted, build)
        }

    ///
    /// The table the cache holds under `key`, if it is usable.
    ///
    pub def cached(key: String, wanted: Codec.Header): Option[TableView] \ Store =
        Store.load(key) |> Option.flatMap(bytes ->
            Codec.expect(wanted, bytes) |> Result.toOption)

    ///
    /// Why the cache could not supply `key`, or nothing when it could.
    ///
    /// Separate from `table` because the two questions differ: a caller solving
    /// a cube wants the table, and a caller diagnosing a slow start wants to
    /// know whether the file was missing, damaged, or built under another
    /// convention.
    ///
    pub def reasonToRebuild(key: String, wanted: Codec.Header): Option[String] \ Store =
        match Store.load(key) {
            case None => Some("nothing is cached under '${key}'")
            case Some(bytes) =>
                match Codec.expect(wanted, bytes) {
                    case Ok(_)  => None
                    case Err(e) => Some(e)
                }
        }

    ///
    /// Build the table and keep it, best effort.
    ///
    /// A table that cannot be written is still returned. Failing a solve
    /// because a cache directory is read-only would trade a slow start for no
    /// start at all.
    ///
    def buildAndKeep(
        key: String,
        wanted: Codec.Header,
        build: Unit -> Result[String, TableView] \ ef
    ): Result[String, TableView] \ ef + Store =
        build() |> Result.map(t -> {
            match Codec.encode(wanted, t) {
                case Ok(bytes) => Store.save(key, bytes)
                case Err(_)    => ()
            };
            t
        })

    // ---------- handlers ----------

    ///
    /// Run `f` with no cache at all: every lookup misses and nothing is kept.
    ///
    /// The honest way to say "build it every time", and what the tests of the
    /// tables themselves use so that they measure building rather than reading.
    ///
    pub def withoutCache(f: Unit -> a \ ef): a \ ef - Store =
        run { f() } with handler Store {
            def load(_, k) = k(None)
            def save(_, _, k) = k(())
        }

    ///
    /// Run `f` with the cache kept as files under `directory`.
    ///
    /// Publication is atomic: the bytes go to a neighbouring temporary file and
    /// are then moved into place. A reader therefore sees either the old file
    /// or the whole new one, never a partial write -- which is the failure the
    /// checksum would otherwise have to catch, and which two processes starting
    /// at once would otherwise produce.
    ///
    pub def onFilesystem(directory: String, f: Unit -> a \ ef): a \
        (ef - Store) + FileExists + ReadBytes + WriteBytes + MoveFile =
        run { f() } with handler Store {
            def load(key, k) = k(readFile(pathOf(directory, key)))
            def save(key, bytes, k) = k(writeAtomically(pathOf(directory, key), bytes))
        }

    ///
    /// Where `key` lives under `directory`.
    ///
    def pathOf(directory: String, key: String): String = "${directory}/${key}.table"

    ///
    /// The bytes of `path`, or nothing if it is absent or unreadable.
    ///
    def readFile(path: String): Option[Vector[Int8]] \ FileExists + ReadBytes =
        match Fs.FileExists.exists(path) {
            case Ok(true) => Fs.ReadBytes.readBytes(path) |> Result.toOption
            case _        => None
        }

    ///
    /// Write `bytes` to `path` so that no reader can see a partial file.
    ///
    def writeAtomically(path: String, bytes: Vector[Int8]): Unit \ WriteBytes + MoveFile =
        let staged = "${path}.writing";
        match Fs.WriteBytes.writeBytes(bytes, staged) {
            case Err(_) => ()
            case Ok(_)  =>
                Fs.MoveFile.moveWith(
                    src = staged,
                    path,
                    Set#{Fs.MoveOption.AtomicMove, Fs.MoveOption.ReplaceExisting}
                ) |> Result.toOption |> Option.getWithDefault(())
        }

}
