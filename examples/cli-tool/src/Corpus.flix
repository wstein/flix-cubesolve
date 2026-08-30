///
/// The commands that read the published pattern corpora.
///
/// Nothing here runs a solver. Recognising a cube is a lookup, and the split
/// between this module and `Engine` is the same split the library draws:
/// patterns are reference data and the solver never consults them.
///
mod Corpus {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Rotation
    use CubeSolve.Patterns
    use CubeSolve.Render

    ///
    /// The cube as a colored face-letter net in box-drawing format, plus Orbit64 token.
    ///
    pub def show(c: Cube.Cube): Result[String, String] =
        forM (
            netStr <- RenderNet.colouredNet(c);
            tok <- CubeSolve.Model.Facelets.token(c)
        ) yield "${netStr}${String.lineSeparator()}orbit64: ${tok}"

    ///
    /// The cube as structured JSON.
    ///
    pub def showJson(size: Int32, c: Cube.Cube): Result[String, String] =
        forM (
            netStr <- RenderNet.net(c);
            fs <- CubeSolve.Model.Facelets.of(c);
            tok <- CubeSolve.Model.Facelets.token(c)
        ) yield JsonOut.show(size, tok, netStr, fs)

    ///
    /// Which published pattern this is, if it is one, including colored net and Orbit64 token.
    ///
    pub def identify(size: Int32, c: Cube.Cube): String = {
        let netStr = RenderNet.colouredNet(c) |> Result.getWithDefault("");
        let tok = CubeSolve.Model.Facelets.token(c) |> Result.getWithDefault("");
        let details = if (size == 2) pocket(c) else standard(c);
        let tokLine = if (String.length(tok) > 0) "${String.lineSeparator()}orbit64: ${tok}" else "";
        "${netStr}${String.lineSeparator()}${details}${tokLine}"
    }

    ///
    /// Which published pattern this is, as structured JSON.
    ///
    pub def identifyJson(size: Int32, c: Cube.Cube): String =
        let tok = CubeSolve.Model.Facelets.token(c) |> Result.getWithDefault("");
        if (size == 2)
            match Patterns.Pocket.recognize(c) {
                case None => JsonOut.identifyNotFound(size, tok)
                case Some((p, held)) =>
                    JsonOut.identifyFound(
                        size,
                        tok,
                        Patterns.Pocket.name(p),
                        Patterns.Pocket.notation(p),
                        Patterns.Pocket.url(Patterns.Pocket.source(p)),
                        "${held}",
                        written(Patterns.Pocket.solutionFor(p, held))
                    )
            }
        else
            match Patterns.Standard.recognize(c) {
                case None => JsonOut.identifyNotFound(size, tok)
                case Some((p, held)) =>
                    JsonOut.identifyFound(
                        size,
                        tok,
                        Patterns.Standard.name(p),
                        Patterns.Standard.notation(p),
                        Patterns.Standard.url(Patterns.Standard.source(p)),
                        "${held}",
                        written(Patterns.Standard.solutionFor(p, held))
                    )
            }

    ///
    /// The corpus for a size, showing each pattern with its miniature colored net, name, token, and notation.
    ///
    pub def listing(size: Int32): String =
        if (size == 2)
            Patterns.Pocket.all()
                |> Vector.map(p -> {
                    let name = Patterns.Pocket.name(p);
                    let notat = Patterns.Pocket.optimal(p);
                    let tok = Patterns.Pocket.canonical(p);
                    let mini = Cube.solved(2)
                        |> Result.flatMap(c0 -> Cube.applyNotation(notat, c0))
                        |> Result.flatMap(RenderNet.miniColouredNet)
                        |> Result.getWithDefault("");
                    "${name}${String.lineSeparator()}${mini}${String.lineSeparator()}orbit64: ${tok}\t${notat}"
                })
                |> Vector.toList
                |> List.join(String.lineSeparator() + String.lineSeparator())
        else
            Patterns.Standard.all()
                |> Vector.map(p -> {
                    let name = Patterns.Standard.name(p);
                    let notat = Patterns.Standard.notation(p);
                    let tok = Patterns.Standard.canonical(p);
                    let mini = Cube.solved(3)
                        |> Result.flatMap(c0 -> Cube.applyNotation(notat, c0))
                        |> Result.flatMap(RenderNet.miniColouredNet)
                        |> Result.getWithDefault("");
                    "${name}${String.lineSeparator()}${mini}${String.lineSeparator()}orbit64: ${tok}\t${notat}"
                })
                |> Vector.toList
                |> List.join(String.lineSeparator() + String.lineSeparator())

    ///
    /// Query a specific pattern by name or token (with colored net) or list all patterns.
    ///
    pub def queryOrList(size: Int32, searchTerm: String): Result[String, String] =
        let trimmed = String.trim(searchTerm);
        if (String.isEmpty(trimmed))
            Ok(listing(size))
        else
            queryPattern(size, trimmed)

    def queryPattern(size: Int32, q: String): Result[String, String] =
        let lowerQ = String.toLowerCase(q);
        if (size == 2) {
            let matches = Patterns.Pocket.all()
                |> Vector.filter(p ->
                    String.toLowerCase(Patterns.Pocket.name(p)) == lowerQ
                    or String.contains(substr = lowerQ, String.toLowerCase(Patterns.Pocket.name(p)))
                    or Patterns.Pocket.canonical(p) == q);
            if (Vector.isEmpty(matches))
                Err("pattern '${q}' not found in 2x2x2 corpus")
            else {
                let p = Vector.get(0, matches);
                let name = Patterns.Pocket.name(p);
                let notat = Patterns.Pocket.optimal(p);
                let url = Patterns.Pocket.url(Patterns.Pocket.source(p));
                let tok = Patterns.Pocket.canonical(p);
                forM (
                    c0 <- Cube.solved(2);
                    c <- Cube.applyNotation(notat, c0);
                    netStr <- RenderNet.colouredNet(c)
                ) yield "${netStr}${String.lineSeparator()}${name}${String.lineSeparator()}${notat}${String.lineSeparator()}${url}${String.lineSeparator()}orbit64: ${tok}"
            }
        } else {
            let matches = Patterns.Standard.all()
                |> Vector.filter(p ->
                    String.toLowerCase(Patterns.Standard.name(p)) == lowerQ
                    or String.contains(substr = lowerQ, String.toLowerCase(Patterns.Standard.name(p)))
                    or Patterns.Standard.canonical(p) == q);
            if (Vector.isEmpty(matches))
                Err("pattern '${q}' not found in 3x3x3 corpus")
            else {
                let p = Vector.get(0, matches);
                let name = Patterns.Standard.name(p);
                let notat = Patterns.Standard.notation(p);
                let url = Patterns.Standard.url(Patterns.Standard.source(p));
                let tok = Patterns.Standard.canonical(p);
                forM (
                    c0 <- Cube.solved(3);
                    c <- Cube.applyNotation(notat, c0);
                    netStr <- RenderNet.colouredNet(c)
                ) yield "${netStr}${String.lineSeparator()}${name}${String.lineSeparator()}${notat}${String.lineSeparator()}${url}${String.lineSeparator()}orbit64: ${tok}"
            }
        }

    ///
    /// The corpus for a size as structured JSON.
    ///
    pub def patternsJson(size: Int32): String = {
        let items = if (size == 2)
            Patterns.Pocket.all()
                |> Vector.map(p -> (
                    Patterns.Pocket.name(p),
                    Patterns.Pocket.canonical(p),
                    Patterns.Pocket.optimal(p)
                ))
                |> Vector.toList
        else
            Patterns.Standard.all()
                |> Vector.map(p -> (
                    Patterns.Standard.name(p),
                    Patterns.Standard.canonical(p),
                    Patterns.Standard.notation(p)
                ))
                |> Vector.toList;
        JsonOut.patterns(size, items)
    }

    ///
    /// What the 3x3x3 corpus says about this cube.
    ///
    def standard(c: Cube.Cube): String =
        match Patterns.Standard.recognize(c) {
            case None            => "no published pattern"
            case Some((p, held)) =>
                lines(Patterns.Standard.name(p)
                    :: Patterns.Standard.notation(p)
                    :: Patterns.Standard.url(Patterns.Standard.source(p))
                    :: "held as ${held}"
                    :: "known solution, not optimal: "
                        + "${written(Patterns.Standard.solutionFor(p, held))}"
                    :: Nil)
        }

    ///
    /// What the 2x2x2 corpus says about this cube.
    ///
    /// The solution is exact only for a cube held as the corpus recorded it:
    /// anywhere else it carries the moves that turn the cube upright first, and
    /// those are real moves. Saying which is the difference between a promise
    /// and a claim.
    ///
    def pocket(c: Cube.Cube): String =
        match Patterns.Pocket.recognize(c) {
            case None            => "no published pattern"
            case Some((p, held)) =>
                let upright = held == Rotation.identity();
                let label = if (upright) "optimal solution" else "solution, not optimal as held";
                lines(Patterns.Pocket.name(p)
                    :: Patterns.Pocket.notation(p)
                    :: Patterns.Pocket.url(Patterns.Pocket.source(p))
                    :: "held as ${held}"
                    :: "${label}: ${written(Patterns.Pocket.solutionFor(p, held))}"
                    :: Nil)
        }

    ///
    /// A solution as notation, or why there is none to show.
    ///
    def written(ms: Result[String, List[Move.Move]]): String =
        ms |> Result.map(Move.showAll) |> Result.getWithDefault("unavailable")

    ///
    /// Strings, one per line.
    ///
    def lines(ls: List[String]): String = List.join(String.lineSeparator(), ls)

}
