///
/// What the command line says when asked how to use it.
///
/// Its own module so that `Main` is left holding argument dispatch and
/// nothing else -- the help text is the one part that has to know which sizes
/// the engine supports, and asking that question is a dependency the
/// dispatcher need not carry.
///
mod Usage {

    ///
    /// How to use this.
    ///
    pub def text(): String = List.join(String.lineSeparator(),
        "cubesolve -- solve, scramble and draw n x n x n cubes"
            :: ""
            :: "  solve    [--method m] [--size n] [--budget b] <scramble>   a solution"
            :: "  show     [--size n] [--json] <input>      the cube as a coloured net"
            :: "  identify [--size n] [--json] <input>      which published pattern it is"
            :: "  scramble [--size n] [--json]              a uniform random-state scramble"
            :: "  patterns [--size n] [--json]              the published corpus"
            :: "  oll                 [--json] <input>      the last-layer orientation case"
            :: "  pll                 [--json] <input>      the last-layer permutation case"
            :: "  help                                      this"
            :: ""
            :: "<input> autodetects move notations, Orbit64 tokens, and URLs."
            :: "Every command accepts an optional --json flag for JSON output."
            :: "Solves ${Args.written(CubeSolve.supportedSizes())}; "
                + "draws ${Args.written(CubeSolve.turnableSizes())}."
            :: "Tables are cached after the first run."
            :: "solve takes --budget: ${Budgets.names()} (probes, not seconds)."
            :: "solve takes --method: ${Methods.names()}. kociemba answers any"
            :: "  size and takes --budget; cfop and beginner answer 3x3x3 in named"
            :: "  steps, are much longer, and search their own stages."
            :: "Every command takes ${Verbosity.names()}."
            :: "oll and pll take --profile: ${Args.profileNames()}."
            :: Nil)


    ///
    /// The commands, named once.
    ///
    /// `dispatch` asks this rather than carrying its own list, so a command
    /// that appears in the help and not in the dispatch -- or the reverse -- is
    /// not possible.
    ///
    pub def commands(): List[String] =
        "solve" :: "show" :: "identify" :: "scramble" :: "patterns"
            :: "oll" :: "pll" :: "help" :: Nil

    ///
    /// Whether `name` is one of them.
    ///
    pub def isCommand(name: String): Bool = List.memberOf(name, commands())

}
