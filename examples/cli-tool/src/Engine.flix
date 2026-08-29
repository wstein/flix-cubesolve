///
/// The commands that run the solver.
///
/// Split from `Main` so that the part which parses arguments does not also
/// reach into every table, solver and scrambler in the library. This is the
/// only place the command line touches the engine.
///
mod Engine {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard
    use CubeSolve.Table

    ///
    /// A solution for `c`, and how many moves it took.
    ///
    pub def solveCube(size: Int32, c: Cube.Cube): Result[String, String] \ IO =
        movesFor(size, c) |> Result.map(ms ->
            "${Move.showAll(ms)}${String.lineSeparator()}${List.length(ms)} moves")

    ///
    /// A uniform random-state scramble, with the bounds it can promise.
    ///
    /// Scrambling is the library's own operation rather than a sample followed
    /// by a solve done here: `uniform` certifies the scramble by solving it and
    /// reports both bounds. Only the seed is drawn locally.
    ///
    pub def scramble(size: Int32): Result[String, String] \ IO =
        if (size != 3)
            Err("scrambling is implemented for the 3x3x3 only")
        else
            let seed = Random.secureSeed();
            Store.cached(() ->
                Standard.cachedTables() |> Result.flatMap(t ->
                    CubeSolve.Scramble.Standard.uniform(t, Standard.defaultBudget(), seed)))
                |> Result.map(drawn -> describe(fst(drawn)))

    ///
    /// A scramble and what is known about how hard it is.
    ///
    def describe(s: CubeSolve.Scramble.Standard.Scramble): String =
        let show = CubeSolve.Scramble.Standard.show;
        let atMost = CubeSolve.Scramble.Standard.atMostMoves;
        let atLeast = CubeSolve.Scramble.Standard.atLeastMoves;
        "${show(s)}${String.lineSeparator()}"
            + "solvable in ${atMost(s)} moves, and no fewer than ${atLeast(s)}"

    ///
    /// Solve at whichever size, through the cache.
    ///
    /// The tests build tables so that they measure building. A person at a
    /// terminal should wait once, which is what the cache is for and what this
    /// is the only caller of.
    ///
    def movesFor(size: Int32, c: Cube.Cube): Result[String, List[Move.Move]] \ IO =
        Store.cached(() -> if (size == 2) pocket(c) else standard(c))

    ///
    /// A 2x2x2 solution, which is exact.
    ///
    def pocket(c: Cube.Cube): Result[String, List[Move.Move]] \ Table.Cache.Store =
        forM (
            t <- Table.Pocket.cachedTables();
            x <- Sized.pocketOf(c);
            ms <- CubeSolve.Solve.Pocket.solution(t, x)
        ) yield ms

    ///
    /// A 3x3x3 solution, which is short rather than shortest.
    ///
    def standard(c: Cube.Cube): Result[String, List[Move.Move]] \ Table.Cache.Store =
        forM (
            t <- Standard.cachedTables();
            x <- Sized.standardOf(c);
            ms <- Standard.solutionWith(t, Standard.defaultBudget(), x)
        ) yield ms

}
