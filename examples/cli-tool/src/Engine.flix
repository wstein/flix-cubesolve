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
    use CubeSolve.Patterns
    use CubeSolve.Solve.Standard
    use CubeSolve.Table

    ///
    /// A solution for `c`, with colored net, move count, metric, method, and pattern DB recognition.
    ///
    pub def solveCube(size: Int32, c: Cube.Cube): Result[String, String] \ IO =
        forM (
            netStr <- RenderNet.colouredNet(c);
            tok <- CubeSolve.Model.Facelets.token(c);
            ms <- movesFor(size, c)
        ) yield {
            let sol = Move.showAll(ms);
            let len = List.length(ms);
            let meth = if (size == 2) "optimal BFS" else "Kociemba two-phase";
            let patLine = match patternFor(size, c) {
                case Some((name, url)) => "pattern: ${name} (${url})"
                case None              => "pattern: none (search)"
            };
            "${netStr}${String.lineSeparator()}"
                + "${sol}${String.lineSeparator()}"
                + "${len} moves (HTM)${String.lineSeparator()}"
                + "method:  ${meth}${String.lineSeparator()}"
                + "${patLine}${String.lineSeparator()}"
                + "orbit64: ${tok}"
        }

    ///
    /// A solution for `c` as structured JSON.
    ///
    pub def solveCubeJson(size: Int32, c: Cube.Cube): Result[String, String] \ IO =
        forM (
            tok <- CubeSolve.Model.Facelets.token(c);
            ms <- movesFor(size, c)
        ) yield {
            let sol = Move.showAll(ms);
            let moveStrs = ms |> List.map(Move.show);
            let meth = if (size == 2) "optimal BFS" else "Kociemba two-phase";
            let patOpt = patternFor(size, c);
            JsonOut.solution(size, tok, sol, moveStrs, meth, "HTM", patOpt)
        }

    def patternFor(size: Int32, c: Cube.Cube): Option[(String, String)] =
        if (size == 2)
            match Patterns.Pocket.recognize(c) {
                case Some((p, _)) =>
                    Some((Patterns.Pocket.name(p), Patterns.Pocket.url(Patterns.Pocket.source(p))))
                case None => None
            }
        else if (size == 3)
            match Patterns.Standard.recognize(c) {
                case Some((p, _)) =>
                    Some((Patterns.Standard.name(p), Patterns.Standard.url(Patterns.Standard.source(p))))
                case None => None
            }
        else
            None

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
    /// A uniform random-state scramble as structured JSON.
    ///
    pub def scrambleJson(size: Int32): Result[String, String] \ IO =
        if (size != 3)
            Err("scrambling is implemented for the 3x3x3 only")
        else
            let seed = Random.secureSeed();
            Store.cached(() ->
                Standard.cachedTables() |> Result.flatMap(t ->
                    CubeSolve.Scramble.Standard.uniform(t, Standard.defaultBudget(), seed)))
                |> Result.map(drawn -> {
                    let s = fst(drawn);
                    let text = CubeSolve.Scramble.Standard.show(s);
                    let atMost = CubeSolve.Scramble.Standard.atMostMoves(s);
                    let atLeast = CubeSolve.Scramble.Standard.atLeastMoves(s);
                    let rawMoves = CubeSolve.Scramble.Standard.moves(s);
                    let ms = rawMoves |> List.map(Move.show);
                    let tok = match Cube.solved(3) {
                        case Ok(sol) =>
                            Cube.applyNotation(text, sol)
                                |> Result.flatMap(CubeSolve.Model.Facelets.token)
                                |> Result.getWithDefault("")
                        case Err(_)  => ""
                    };
                    JsonOut.scramble(size, text, tok, atMost, atLeast, ms)
                })

    ///
    /// A scramble and what is known about how hard it is, plus Orbit64 token.
    ///
    def describe(s: CubeSolve.Scramble.Standard.Scramble): String = {
        let show = CubeSolve.Scramble.Standard.show;
        let atMost = CubeSolve.Scramble.Standard.atMostMoves;
        let atLeast = CubeSolve.Scramble.Standard.atLeastMoves;
        let text = show(s);
        let tok = match Cube.solved(3) {
            case Ok(sol) =>
                Cube.applyNotation(text, sol)
                    |> Result.flatMap(CubeSolve.Model.Facelets.token)
                    |> Result.getWithDefault("")
            case Err(_)  => ""
        };
        "${text}${String.lineSeparator()}"
            + "solvable in ${atMost(s)} moves, and no fewer than ${atLeast(s)}"
            + (if (String.length(tok) > 0) "${String.lineSeparator()}orbit64: ${tok}" else "")
    }

    ///
    /// Solve at whichever size, through the cache.
    ///
    /// The tests build tables so that they measure building. A person at a
    /// terminal should wait once, which is what the cache is for and what this
    /// is the only caller of.
    ///
    def movesFor(size: Int32, c: Cube.Cube): Result[String, List[Move.Move]] \ IO =
        match CubeSolve.Model.Validate.faultOf(c) {
            case Some(why) => Err(why)
            case None      => Store.cached(() -> if (size == 2) pocket(c) else standard(c))
        }

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
