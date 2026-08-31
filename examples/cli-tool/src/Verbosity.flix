///
/// How much the command line says about what it is doing.
///
/// Solving is not always fast. Building the first-two-layer tables is over
/// three million states, and a `solve --method` on a cold cache is a long
/// silence with nothing on screen -- which is indistinguishable, from the
/// outside, from a hang. These levels exist so that silence is a choice.
///
/// **Everything written here goes to standard error**, so `--json` on standard
/// output stays machine-readable at every level. A caller piping JSON into
/// another program can turn tracing on and lose nothing.
///
mod Verbosity {

    use Verbosity.Level.{Quiet, Normal, Verbose, Debug, Trace}

    ///
    /// How loud to be.
    ///
    /// Each level includes the ones before it.
    ///
    pub enum Level with Eq, Order, ToString {
        /// Only the answer, and errors.
        case Quiet
        /// A line per stage, so a long wait shows it is alive. The default.
        case Normal
        /// What is happening and what it cost.
        case Verbose
        /// Also why: cache misses, table sizes, budgets.
        case Debug
        /// Also every step as it is taken.
        case Trace
    }

    ///
    /// The flags that select a level, loudest wins.
    ///
    /// `-v` is `--verbose`. There is no `-d` or `-t`: a single letter that
    /// silently turns on tracing is easier to type by accident than to notice.
    ///
    pub def ofArgs(args: List[String]): (Level, List[String]) =
        let flags = "--verbose" :: "-v" :: "--debug" :: "--trace" :: "--quiet" :: "-q" :: Nil;
        let level =
            if (List.exists(a -> a == "--trace", args)) Trace
            else if (List.exists(a -> a == "--debug", args)) Debug
            else if (List.exists(a -> a == "--verbose" or a == "-v", args)) Verbose
            else if (List.exists(a -> a == "--quiet" or a == "-q", args)) Quiet
            else Normal;
        (level, List.filter(a -> not List.memberOf(a, flags), args))

    ///
    /// Whether `wanted` is on at `level`.
    ///
    pub def says(level: Level, wanted: Level): Bool = level >= wanted

    ///
    /// Write a line at `wanted`, if the level allows it.
    ///
    /// To standard error, prefixed, so it is never confused with the answer.
    ///
    pub def say(level: Level, wanted: Level, message: String): Unit \ IO =
        if (says(level, wanted))
            Sys.Console.runWithIO(_ -> Sys.Console.eprintln("cubesolve: ${message}"))
        else
            ()

    ///
    /// Run `f`, and at `wanted` report what it cost.
    ///
    /// The clock is read around the call rather than inside anything, so this
    /// costs nothing at `Quiet` beyond one comparison.
    ///
    pub def timed(
        level: Level,
        wanted: Level,
        what: String,
        f: Unit -> a \ ef
    ): a \ ef + IO =
        if (says(level, wanted)) {
            say(level, wanted, "${what}...");
            let started = Time.Clock.runWithIO(_ -> Time.Clock.now());
            let result = f();
            let ended = Time.Clock.runWithIO(_ -> Time.Clock.now());
            say(level, wanted, "${what} took ${written(ended - started)}");
            result
        } else
            f()

    ///
    /// A count of milliseconds, in the units a person reads.
    ///
    def written(ms: Int64): String =
        if (ms < 1000i64)
            "${ms} ms"
        else
            "${Int64.toFloat64(ms) / 1000.0} s"

    ///
    /// The names, for the usage text.
    ///
    pub def names(): String = "--quiet (-q), --verbose (-v), --debug, --trace"

    ///
    /// Say that a stage has started, on one line that later output replaces.
    ///
    /// Carriage return rather than newline, so a run of stages occupies one
    /// line rather than scrolling: this is an alive sign, not a log. Padded
    /// because a shorter line must overwrite a longer one completely.
    ///
    pub def stage(level: Level, n: Int32, of: Int32, what: String): Unit \ IO =
        if (says(level, Normal) and not says(level, Verbose))
            Sys.Console.runWithIO(_ ->
                Sys.Console.eprint("\r  [${n}/${of}] ${what}" + String.repeat(24, " ") + "\r  [${n}/${of}] ${what}"))
        else
            say(level, Verbose, "[${n}/${of}] ${what}")

    ///
    /// Clear the stage line, once there is nothing more to report.
    ///
    pub def done(level: Level): Unit \ IO =
        if (says(level, Normal) and not says(level, Verbose))
            Sys.Console.runWithIO(_ -> Sys.Console.eprint("\r" + String.repeat(60, " ") + "\r"))
        else
            ()
}
