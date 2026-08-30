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
def dispatch(args: List[String]): Unit \ IO =
    Args.withJson(args, (isJson, cmdArgs) -> match cmdArgs {
        case "solve" :: rest    =>
            report(isJson, Args.withBudget(rest, (b, afterBudget) ->
                Args.withSize(afterBudget, Solving, (size, more) ->
                    solveCommand(isJson, b, size, more))))
        case "show" :: rest     =>
            report(isJson, Args.withSize(rest, Turning, (size, more) ->
                showCommand(isJson, size, more)))
        case "identify" :: rest =>
            report(isJson, Args.withSize(rest, Corpus, (size, more) ->
                identifyCommand(isJson, size, more)))
        case "pll" :: rest      =>
            report(isJson, Args.withProfile(rest, (p, more) ->
                methodCommand(isJson, c -> Method.pll(p, c), c -> Method.pllJson(p, c), more)))
        case "oll" :: rest      =>
            report(isJson, Args.withProfile(rest, (p, more) ->
                methodCommand(isJson, c -> Method.oll(p, c), c -> Method.ollJson(p, c), more)))
        case "scramble" :: rest =>
            report(isJson, Args.withSize(rest, Solving, (n, _) ->
                if (isJson) Engine.scrambleJson(n) else Engine.scramble(n)))
        case "patterns" :: rest =>
            report(isJson, Args.withSize(rest, Corpus, (n, more) ->
                if (isJson) Ok(Corpus.patternsJson(n)) else Corpus.queryOrList(n, List.join(" ", more))))
        case "help" :: _        => println(Usage.text())
        case Nil                => println(Usage.text())
        case other :: _         =>
            if (isJson)
                report(true, Err("no such command '${other}'"))
            else {
                println("cubesolve: no such command '${other}'");
                println(Usage.text())
            }
    })

///
/// `solve [--size n] [--budget name] [--json] <scramble>`
///
def solveCommand(
    isJson: Bool,
    b: Budgets.Budget,
    size: Int32,
    rest: List[String]
): Result[String, String] \ IO =
    if (isJson)
        Args.onCube(size, rest, (n, c) -> Engine.solveCubeJson(b, n, c))
    else
        Args.onCube(size, rest, (n, c) -> Engine.solveCube(b, n, c))

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
