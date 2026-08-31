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
    /// One step: what it is called, and the notation that performs it.
    ///
    /// **Notation, not a list of layer turns.** Several published OLL and PLL
    /// algorithms rotate the whole cube partway through, and a rotation cannot
    /// be written as a layer turn: dropping it leaves every later letter naming
    /// a different face, and the sequence stops solving. A step therefore keeps
    /// what it was given.
    ///
    pub type alias Step = { name = String, sequence = String }

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
            |> Result.map(ms -> { name = name, sequence = Move.showAll(Move.compact(ms)) })
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
            |> Result.traverse(s -> Plan.step(3, s#name, s#sequence))
            |> Result.map(Plan.of)

    def ofStage(s: Method.Stage): Step =
        { name = labelFor(s), sequence = Notation.compact(s#sequence) }

    def labelFor(s: Method.Stage): String =
        if (s#caseName == "skip")
            "${s#step} skip -- ${s#note}"
        else
            "${s#step}: ${s#caseName}"

}
