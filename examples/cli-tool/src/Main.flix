use Args.Needs.{Turning, Solving, Corpus}
use CubeSolve.Method.Profile
use CubeSolve.Model.Cube

///
/// A command line over cubesolve, and the demonstration that it is usable.
///
/// **Kept in its own package, never in the library.** Flix allows one `main`
/// per program, so a library that ships one at the top level cannot be
/// depended on. This runs against the published `cubesolve` package exactly
/// the way any other consuming project would.
///
/// This module parses arguments and prints results. The work is in `Engine`,
/// which runs the solver, and `Corpus`, which reads the pattern collections --
/// a split that keeps the command line from being the one module that reaches
/// into everything.
///
/// Read the arguments, do the thing, say how it went.
///
/// Arguments come from `Sys.Env.getArgs`, not from parameters: a Flix entry
/// point takes none.
///
def main(): Unit \ IO =
    Sys.Env.runWithIO(_ -> dispatch(Sys.Env.getArgs()))

///
/// One invocation.
///
/// Every command parses its own options, so `--budget` on `show` is refused
/// rather than ignored, and `--help` works everywhere rather than only as its
/// own command.
///
def dispatch(args: List[String]): Unit \ IO = match args {
    case Nil         => println(Usage.text())
    case "help" :: _ => println(Usage.text())
    case cmd :: rest =>
        if (Usage.isCommand(cmd))
            match Options.parse(cmd, rest) {
                case Err(why) => report(false, Err(why))
                case Ok(p)    =>
                    let flags = p#flags;
                    if (Options.has(flags, Options.Flag.Help))
                        println(Options.help(cmd))
                    else
                        execute(cmd, flags, p#operands)
            }
        else {
            Sys.Console.runWithIO(_ -> Sys.Console.eprintln("cubesolve: no such command '${cmd}'"));
            println(Usage.text());
            Sys.Exit.runWithIO(_ -> Sys.Exit.exit(1))
        }
}

///
/// A command, its options already parsed.
///
def execute(cmd: String, flags: List[Options.Flag], operands: List[String]): Unit \ IO =
    let isJson = Options.has(flags, Options.Flag.Json);
    let loud = Options.loudness(flags);
    let withStats = Options.has(flags, Options.Flag.Stats);
    let showNet = not Options.has(flags, Options.Flag.NoNet) and loud != Verbosity.Level.Quiet;
    Verbosity.say(loud, Verbosity.Level.Debug, "command '${cmd}', ${List.length(operands)} operand(s)");
    match cmd {
        case "solve" =>
            report(isJson, forM (
                m <- Methods.named(Options.method(flags));
                b <- Budgets.named(Options.budget(flags));
                size <- Args.sizeFor(Solving, Options.size(flags));
                given <- scrambleOrOperands(loud, size, Options.has(flags, Options.Flag.Scramble), operands);
                answer <- solveCommand(isJson, showNet, loud, withStats, m, b, size, given)
            ) yield answer)
        case "show" =>
            report(isJson, Args.sizeFor(Turning, Options.size(flags))
                |> Result.flatMap(n -> showCommand(isJson, n, operands)))
        case "identify" =>
            report(isJson, Args.sizeFor(Corpus, Options.size(flags))
                |> Result.flatMap(n -> identifyCommand(isJson, n, operands)))
        case "scramble" =>
            report(isJson, Args.sizeFor(Solving, Options.size(flags))
                |> Result.flatMap(n ->
                    Verbosity.timed(loud, Verbosity.Level.Verbose, "scrambling", () ->
                        if (isJson) Engine.scrambleJson(n) else Engine.scramble(n))))
        case "patterns" =>
            report(isJson, Args.sizeFor(Corpus, Options.size(flags))
                |> Result.flatMap(n ->
                    if (isJson) Ok(Corpus.patternsJson(n))
                    else Corpus.queryOrList(n, List.join(" ", operands))))
        case "oll" =>
            report(isJson, Args.namedProfile(Options.profile(flags))
                |> Result.flatMap(pr ->
                    methodCommand(isJson, c -> Method.oll(pr, c), c -> Method.ollJson(pr, c), operands)))
        case "pll" =>
            report(isJson, Args.namedProfile(Options.profile(flags))
                |> Result.flatMap(pr ->
                    methodCommand(isJson, c -> Method.pll(pr, c), c -> Method.pllJson(pr, c), operands)))
        case _ => report(isJson, Err("no such command '${cmd}'"))
    }

///
/// What to solve: a fresh random scramble, or what was on the command line.
///
/// `--scramble` prints the scramble it drew before solving it, because an
/// answer to a cube nobody can see is not reproducible.
///
def scrambleOrOperands(
    loud: Verbosity.Level,
    size: Int32,
    wanted: Bool,
    operands: List[String]
): Result[String, List[String]] \ IO =
    if (not wanted)
        Ok(operands)
    else
        Verbosity.timed(loud, Verbosity.Level.Verbose, "scrambling", () ->
            Engine.scrambleNotation(size) |> Result.map(text -> {
                Verbosity.say(loud, Verbosity.Level.Normal, "scramble ${text}");
                text :: Nil
            }))

///
/// `solve [--size n] [--budget name] [--method name] [--json] [--stats] <scramble>`
///
def solveCommand(
    isJson: Bool,
    showNet: Bool,
    loud: Verbosity.Level,
    withStats: Bool,
    m: Methods.Method,
    b: Budgets.Budget,
    size: Int32,
    rest: List[String]
): Result[String, String] \ IO =
    Args.onCube(size, rest, (n, c) -> {
        if (not isJson and showNet) {
            match RenderNet.colouredNet(c) {
                case Ok(netStr) => println(netStr)
                case Err(_)     => ()
            }
        };
        Verbosity.say(loud, Verbosity.Level.Verbose,
            "solving a ${size}x${size}x${size} by ${Methods.nameOf(m)}, "
                + "budget ${Budgets.nameOf(b)}");
        Verbosity.say(loud, Verbosity.Level.Verbose, Methods.cost(m, b));
        Verbosity.timed(loud, Verbosity.Level.Verbose, "solving", () ->
            if (Methods.twoPhase(m))
                if (isJson)
                    Engine.solveCubeJsonDetailed(loud, withStats, b, n, c)
                else
                    Engine.solveCubeDetailed(loud, withStats, b, n, c)
            else if (isJson)
                Methods.answerJson(m, b, n, c)
            else
                Methods.answer(m, b, n, c))
    })

///
/// `show [--size n] [--json] <scramble>`
///
def showCommand(
    isJson: Bool,
    size: Int32,
    rest: List[String]
): Result[String, String] =
    if (isJson)
        Args.onCube(size, rest, (s, c) -> Corpus.showJson(s, c))
    else
        Args.onCube(size, rest, (_, c) -> Corpus.show(c))

///
/// `pll` and `oll` differ only in which method they ask, so they share this.
///
def methodCommand(
    isJson: Bool,
    askText: Cube.Cube -> Result[String, String],
    askJson: Cube.Cube -> Result[String, String],
    rest: List[String]
): Result[String, String] =
    Args.withSize(rest, Turning, (size, more) ->
        Args.onCube(size, more, (_, c) -> if (isJson) askJson(c) else askText(c)))

///
/// `identify [--size n] [--json] <scramble>`
///
def identifyCommand(
    isJson: Bool,
    size: Int32,
    rest: List[String]
): Result[String, String] =
    if (isJson)
        Args.onCube(size, rest, (n, c) -> Ok(Corpus.identifyJson(n, c)))
    else
        Args.onCube(size, rest, (n, c) -> Ok(Corpus.identify(n, c)))

///
/// Print what came back, or why nothing did.
///
/// A failure goes to standard error and leaves the exit status non-zero, so
/// this composes with a shell rather than only with a reader.
///
def report(isJson: Bool, outcome: Result[String, String]): Unit \ IO = match outcome {
    case Ok(text) => println(text)
    case Err(why) =>
        if (isJson)
            println(JsonOut.error(why))
        else
            Sys.Console.runWithIO(_ -> Sys.Console.eprintln("cubesolve: ${why}"));
        Sys.Exit.runWithIO(_ -> Sys.Exit.exit(1))
}
