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
    /// The cube as a coloured net.
    ///
    pub def show(c: Cube.Cube): Result[String, String] =
        Render.colouredNet(c)

    ///
    /// Which published pattern this is, if it is one.
    ///
    pub def identify(size: Int32, c: Cube.Cube): String =
        if (size == 2) pocket(c) else standard(c)

    ///
    /// The corpus for a size, one pattern per line.
    ///
    pub def listing(size: Int32): String =
        if (size == 2)
            Patterns.Pocket.all()
                |> Vector.map(p -> "${Patterns.Pocket.name(p)}\t${Patterns.Pocket.optimal(p)}")
                |> Vector.toList
                |> lines
        else
            Patterns.Standard.all()
                |> Vector.map(p -> "${Patterns.Standard.name(p)}\t"
                    + "${Patterns.Standard.notation(p)}")
                |> Vector.toList
                |> lines

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
