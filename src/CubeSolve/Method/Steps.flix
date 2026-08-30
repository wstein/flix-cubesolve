///
/// Turning searches and last-layer cases into named steps of a plan.
///
/// Both human methods here -- `CubeSolve.Method.Beginner` and
/// `CubeSolve.Method.Cfop` -- end the same way and answer in the same shape:
/// some searched steps, then OLL, then PLL, rendered as a
/// `CubeSolve.Method.Plan`. Only the searched middle differs between them.
///
/// That shared tail lives here rather than in either method for the reason
/// `CubeSolve.Method.LastLayer` gives about preconditions: two copies of it
/// would be free to drift, and a plan whose steps were labelled one way by one
/// method and another way by the other would be a difference with no meaning
/// behind it.
///
mod CubeSolve.Method.Steps {

    use CubeSolve.Method
    use CubeSolve.Method.Plan
    use CubeSolve.Method.Profile
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Notation

    ///
    /// One step: what it is called, and the moves it makes.
    ///
    pub type alias Step = { name = String, moves = List[Move.Move] }

    ///
    /// A step, or the failure of the search behind it, named for the step.
    ///
    /// A search that cannot finish says so with the stage in the message. "No
    /// first two layers within twenty moves" is a fact about a search; "F2L:
    /// ..." is what a caller can act on.
    ///
    pub def stage(
        name: String,
        found: Result[String, List[Move.Move]]
    ): Result[String, Step] =
        found
            |> Result.map(ms -> { name = name, moves = ms })
            |> Result.mapErr(why -> "${name}: ${why}")

    ///
    /// The OLL and PLL steps for a cube whose first two layers are solved.
    ///
    /// Either may be a skip, which arrives here as a step with no moves and a
    /// name saying why. See `CubeSolve.Method.lastLayer`.
    ///
    pub def lastLayer(p: Profile.Profile, c: Cube.Cube): Result[String, List[Step]] =
        Method.lastLayer(p, c)
            |> Result.map(staged -> staged#stages |> List.map(ofStage))
            |> Result.mapErr(why -> "Last layer: ${why}")

    ///
    /// Assemble steps into a plan.
    ///
    pub def plan(steps: List[Step]): Result[String, Plan.Plan] =
        steps
            |> Result.traverse(s -> Plan.step(3, s#name, Move.showAll(s#moves)))
            |> Result.map(Plan.of)

    def ofStage(s: Method.Stage): Step =
        { name = labelFor(s), moves = movesOf(s) }

    def labelFor(s: Method.Stage): String =
        if (s#caseName == "skip")
            "${s#step} skip -- ${s#note}"
        else
            "${s#step}: ${s#caseName}"

    ///
    /// The moves a last-layer stage makes.
    ///
    /// A stage carries its algorithm as notation, and the notation is what was
    /// checked when the case was recorded, so a parse failure here would mean a
    /// corrupt table rather than a bad cube. It yields no moves, which shows up
    /// as a step that does nothing and a plan that does not reach the goal --
    /// louder than a plan that silently omits a step.
    ///
    def movesOf(s: Method.Stage): List[Move.Move] =
        Notation.parse(3, s#sequence)
            |> Result.map(Notation.layersOnly)
            |> Result.getWithDefault(Nil)
}
