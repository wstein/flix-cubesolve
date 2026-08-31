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
    pub def solveCube(b: Budgets.Budget, size: Int32, c: Cube.Cube): Result[String, String] \ IO =
        solveCubeDetailed(Verbosity.Level.Quiet, false, b, size, c)

    ///
    /// A solution for `c` with explicit verbosity level and telemetry options.
    ///
    pub def solveCubeDetailed(
        loud: Verbosity.Level,
        withStats: Bool,
        b: Budgets.Budget,
        size: Int32,
        c: Cube.Cube
    ): Result[String, String] \ IO =
        forM (
            netStr <- RenderNet.colouredNet(c);
            tok <- CubeSolve.Model.Facelets.token(c);
            _ <- {
                println(netStr);
                Ok(())
            };
            (ms, outOpt) <- solveDetails(loud, b, size, c)
        ) yield {
            let sol = Move.showAll(ms);
            let len = List.length(ms);
            let meth = if (size == 2) "optimal BFS" else "Kociemba two-phase";
            let patLine = match patternFor(size, c) {
                case Some((name, url)) => "pattern: ${name} (${url})"
                case None              => "pattern: none (search)"
            };
            let statsBlock = if (withStats) match outOpt {
                case Some(out) =>
                    let termStr = match out#termination {
                        case Standard.Termination.SolvedImmediately => "cube is already solved"
                        case Standard.Termination.Settled =>
                            "answer settled after the ${Budgets.nameOf(b)} view target"
                        case Standard.Termination.ProbeCap => "exhausted the ${Budgets.nameOf(b)} probe cap"
                        case Standard.Termination.ViewsExhausted => "searched all views without further improvement"
                    };
                    "${String.lineSeparator()}views:   ${out#viewsTried} / ${out#viewsAvailable}"
                        + " (target ${out#viewTarget})"
                        + "${String.lineSeparator()}probes:  ${out#probesSpent} / ${out#probeCap}"
                        + "${String.lineSeparator()}stopped: ${termStr}"
                case None => ""
            } else "";
            "${sol}${String.lineSeparator()}"
                + "${len} moves (HTM)${String.lineSeparator()}"
                + "method:  ${meth}${String.lineSeparator()}"
                + "budget:  ${Budgets.nameOf(b)}${budgetNote(size)}${String.lineSeparator()}"
                + "${patLine}${String.lineSeparator()}"
                + "orbit64: ${tok}"
                + "${statsBlock}"
        }

    ///
    /// A solution for `c` as structured JSON.
    ///
    pub def solveCubeJson(b: Budgets.Budget, size: Int32, c: Cube.Cube): Result[String, String] \ IO =
        solveCubeJsonDetailed(Verbosity.Level.Quiet, false, b, size, c)

    ///
    /// A solution for `c` as structured JSON with explicit verbosity level and telemetry options.
    ///
    pub def solveCubeJsonDetailed(
        loud: Verbosity.Level,
        withStats: Bool,
        b: Budgets.Budget,
        size: Int32,
        c: Cube.Cube
    ): Result[String, String] \ IO =
        forM (
            tok <- CubeSolve.Model.Facelets.token(c);
            (ms, outOpt) <- solveDetails(loud, b, size, c)
        ) yield {
            let sol = Move.showAll(ms);
            let moveStrs = ms |> List.map(Move.show);
            let meth = if (size == 2) "optimal BFS" else "Kociemba two-phase";
            let patOpt = patternFor(size, c);
            let statsParam = if (withStats) outOpt else None;
            JsonOut.solutionWithStats(size, tok, sol, moveStrs, meth, "HTM", patOpt, statsParam)
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
    ///
    /// A fresh random scramble, as notation and nothing else.
    ///
    /// `scramble` describes one for a reader; this returns what a solver can be
    /// handed, which is what `solve --scramble` needs.
    ///
    pub def scrambleNotation(size: Int32): Result[String, String] \ IO =
        if (size != 3)
            Err("scrambling is implemented for the 3x3x3 only")
        else
            let seed = Random.secureSeed();
            Store.cached(() ->
                Standard.cachedTables() |> Result.flatMap(t ->
                    CubeSolve.Scramble.Standard.uniform(t, Standard.defaultBudget(), seed)))
                |> Result.map(drawn -> CubeSolve.Scramble.Standard.show(fst(drawn)))

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
    ///
    /// What the budget means for a 2x2x2, which ignores it.
    ///
    /// The pocket solver reads a table and returns a shortest answer; there is
    /// nothing for a budget to buy. Saying so beats printing a budget that had
    /// no effect.
    ///
    def budgetNote(size: Int32): String =
        if (size == 2) " (ignored: the 2x2x2 answer is already shortest)" else ""

    def solveDetails(
        loud: Verbosity.Level,
        b: Budgets.Budget,
        size: Int32,
        c: Cube.Cube
    ): Result[String, (List[Move.Move], Option[Standard.Outcome])] \ IO =
        match CubeSolve.Model.Validate.faultOf(c) {
            case Some(why) => Err(why)
            case None      =>
                if (size == 2)
                    Store.cached(() -> pocket(c)) |> Result.map(ms -> (ms, None))
                else
                    forM (
                        pair <- Store.cached(() -> standardOutcome(b, c))
                    ) yield {
                        let (ms, out) = pair;
                        reportOutcome(loud, b, out);
                        (ms, Some(out))
                    }
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
    /// A 3x3x3 solution, which produces structured Outcome telemetry.
    ///
    def standardOutcome(
        b: Budgets.Budget,
        c: Cube.Cube
    ): Result[String, (List[Move.Move], Standard.Outcome)] \ Table.Cache.Store =
        forM (
            t <- Standard.cachedTables();
            x <- Sized.standardOf(c);
            pair <- {
                let out = Standard.solveWithOutcome(t, Budgets.solverBudget(b), x);
                match out#answer {
                    case Some(ms) => Ok((ms, out))
                    case None     => Err("no solution found within probe budget")
                }
            }
        ) yield pair

    def reportOutcome(loud: Verbosity.Level, b: Budgets.Budget, out: Standard.Outcome): Unit \ IO = {
        let budgetName = Budgets.nameOf(b);
        let firstHtmStr = match out#firstHtm {
            case Some(h) => "${h}"
            case None    => "none"
        };
        let finalHtmStr = match out#finalHtm {
            case Some(h) => "${h}"
            case None    => "none"
        };
        Verbosity.say(loud, Verbosity.Level.Verbose,
            "budget ${budgetName}: ${out#probesSpent}/${out#probeCap} probes, "
                + "${out#viewsTried}/${out#viewsAvailable} views, "
                + "first ${firstHtmStr} HTM, final ${finalHtmStr} HTM");
        let stopMsg = match out#termination {
            case Standard.Termination.SolvedImmediately => "cube is already solved"
            case Standard.Termination.Settled => "answer settled after the ${budgetName} view target"
            case Standard.Termination.ProbeCap => "exhausted the ${budgetName} probe cap"
            case Standard.Termination.ViewsExhausted => "searched all views without further improvement"
        };
        Verbosity.say(loud, Verbosity.Level.Verbose, "stopped: ${stopMsg}");
        if (Verbosity.says(loud, Verbosity.Level.Debug)) {
            out#viewStats |> List.forEach(v -> {
                let axisStr = match v#axis {
                    case Standard.ViewAxis.UD => "UD"
                    case Standard.ViewAxis.FB => "FB"
                    case Standard.ViewAxis.RL => "RL"
                };
                let invStr = if (v#inverted) " (inverted)" else "";
                let candStr = match v#foundMoves {
                    case Some(m) => "${m} moves"
                    case None    => "no candidate"
                };
                let accStr = if (v#accepted) " (accepted)" else "";
                Verbosity.say(loud, Verbosity.Level.Debug,
                    "view ${axisStr}${invStr}: ${v#probesSpent} probes, ${candStr}${accStr}")
            })
        };
        if (Verbosity.says(loud, Verbosity.Level.Trace) and out#improvements > 0) {
            Verbosity.say(loud, Verbosity.Level.Trace,
                "improvement: ${firstHtmStr} -> ${finalHtmStr} (${out#improvements} reduction(s))")
        }
    }

}
