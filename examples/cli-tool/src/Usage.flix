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
            :: "  solve    [--size n] <scramble>   a solution, and its move count"
            :: "  show     [--size n] <scramble>   the cube as a coloured net"
            :: "  identify [--size n] <scramble>   which published pattern it is"
            :: "  scramble                         a uniform random-state scramble"
            :: "  patterns [--size n]              the published corpus"
            :: "  help                             this"
            :: ""
            :: "Solves ${Args.written(CubeSolve.supportedSizes())}; "
                + "draws ${Args.written(CubeSolve.turnableSizes())}."
            :: "Tables are cached after the first run."
            :: Nil)

}
