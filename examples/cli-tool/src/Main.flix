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
def dispatch(args: List[String]): Unit \ IO = match args {
    case "solve" :: rest    => report(Args.withSize(rest, Solving, solveCommand))
    case "show" :: rest     => report(Args.withSize(rest, Turning, showCommand))
    case "identify" :: rest => report(Args.withSize(rest, Corpus, identifyCommand))
    case "pll" :: rest      =>
        report(Args.withProfile(rest, (p, more) -> methodCommand(Method.pll, p, more)))
    case "oll" :: rest      =>
        report(Args.withProfile(rest, (p, more) -> methodCommand(Method.oll, p, more)))
    case "scramble" :: rest =>
        report(Args.withSize(rest, Solving, (n, _) -> Engine.scramble(n)))
    case "patterns" :: rest =>
        report(Args.withSize(rest, Corpus, (n, _) -> Ok(Corpus.listing(n))))
    case "help" :: _        => println(Usage.text())
    case Nil                => println(Usage.text())
    case other :: _         =>
        println("cubesolve: no such command '${other}'");
        println(Usage.text())
}

///
/// `solve [--size n] <scramble>`
///
def solveCommand(size: Int32, rest: List[String]): Result[String, String] \ IO =
    Args.onCube(size, rest, Engine.solveCube)

///
/// `show [--size n] <scramble>`
///
def showCommand(size: Int32, rest: List[String]): Result[String, String] =
    Args.onCube(size, rest, (_, c) -> Corpus.show(c))

///
/// `pll` and `oll` differ only in which method they ask, so they share this.
///
def methodCommand(
    ask: (Profile.Profile, Cube.Cube) -> Result[String, String],
    p: Profile.Profile,
    rest: List[String]
): Result[String, String] =
    Args.withSize(rest, Turning, (size, more) ->
        Args.onCube(size, more, (_, c) -> ask(p, c)))

///
/// `identify [--size n] <scramble>`
///
def identifyCommand(size: Int32, rest: List[String]): Result[String, String] =
    Args.onCube(size, rest, (n, c) -> Ok(Corpus.identify(n, c)))

///
/// Print what came back, or why nothing did.
///
/// A failure goes to standard error and leaves the exit status non-zero, so
/// this composes with a shell rather than only with a reader.
///
def report(outcome: Result[String, String]): Unit \ IO = match outcome {
    case Ok(text) => println(text)
    case Err(why) =>
        Sys.Console.runWithIO(_ -> Sys.Console.eprintln("cubesolve: ${why}"));
        Sys.Exit.runWithIO(_ -> Sys.Exit.exit(1))
}
