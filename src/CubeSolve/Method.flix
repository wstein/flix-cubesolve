///
/// Solving a cube the way a person does, in named steps.
///
/// The submodules are the steps: `Cross` searches, `Oll` and `Pll` recognise a
/// case and play back an algorithm. This module joins them, and holds the shape
/// an answer takes when it is made of steps rather than being one sequence.
///
/// **A staged answer is never optimal and does not pretend to be.** Two steps
/// that are each shortest for their own goal are not together shortest for the
/// cube: the last layer alone comes out around twenty moves where the two-phase
/// solver answers a whole scramble in about twenty. `CubeSolve.Solve.Standard`
/// is what solves cubes; this is what explains them.
///
mod CubeSolve.Method {

    use CubeSolve.Method.LastLayer
    use CubeSolve.Method.Oll
    use CubeSolve.Method.Pll
    use CubeSolve.Method.Profile
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation

    ///
    /// One step of an answer.
    ///
    /// `sequence` is empty when the step was already done -- a skip, which is a
    /// real and welcome thing to happen and is reported rather than dropped. A
    /// reader who sees two stages where they expected three should be told why,
    /// not left to count.
    ///
    pub type alias Stage = {
        step = String,
        caseName = String,
        sequence = String,
        layerTurns = Int32,
        note = String
    }

    ///
    /// An answer made of steps.
    ///
    pub type alias Staged = {
        stages = List[Stage],
        layerTurns = Int32
    }

    ///
    /// The whole thing to execute, the stages run together.
    ///
    pub def sequenceOf(s: Staged): String =
        s#stages
            |> List.map(stage -> stage#sequence)
            |> List.filter(x -> not String.isEmpty(x))
            |> List.join(" ")

    ///
    /// Finish a cube whose first two layers are solved: orient, then permute.
    ///
    /// Refuses anything else, and by the same reason `Oll` and `Pll` give, since
    /// all three ask `CubeSolve.Method.LastLayer` what state the cube is in.
    ///
    /// Either step may be a skip. A last layer that arrives already oriented has
    /// no OLL case -- every algorithm would break it -- and one that arrives
    /// solved has no PLL case. Both are reported as stages with no moves, so the
    /// answer says what happened rather than silently containing fewer steps.
    ///
    pub def lastLayer(p: Profile.Profile, c: Cube.Cube): Result[String, Staged] =
        match LastLayer.faultBelowTheTop(c) {
            case Some(why) => Err(why)
            case None      => forM (
                oriented <- orientStage(p, c);
                permuted <- permuteStage(p, oriented#cube)
            ) yield collect(oriented#stage :: permuted#stage :: Nil)
        }

    ///
    /// The OLL step, or a skip if the layer is oriented already.
    ///
    def orientStage(
        p: Profile.Profile,
        c: Cube.Cube
    ): Result[String, { stage = Stage, cube = Cube.Cube }] =
        if (LastLayer.topIsOriented(c))
            Ok({ stage = skipped("OLL", "the last layer arrived oriented"), cube = c })
        else
            forM (
                found <- Oll.recognizeWith(p, c);
                after <- Cube.applyNotation(found#sequence, c)
            ) yield {
                stage = stageOf("OLL", found#caseName, found#sequence, found#choice),
                cube = after
            }

    ///
    /// The PLL step, or a skip if the cube is solved already.
    ///
    def permuteStage(
        p: Profile.Profile,
        c: Cube.Cube
    ): Result[String, { stage = Stage, cube = Cube.Cube }] =
        if (Cube.isSolved(c))
            Ok({ stage = skipped("PLL", "the last layer arrived solved"), cube = c })
        else
            forM (
                found <- Pll.recognizeWith(p, c);
                after <- Cube.applyNotation(found#sequence, c)
            ) yield {
                stage = stageOf("PLL", found#caseName, found#sequence, found#choice),
                cube = after
            }

    ///
    /// A step that was done.
    ///
    def stageOf(step: String, caseName: String, sequence: String, choice: Profile.Choice): Stage =
        {
            step = step,
            caseName = caseName,
            sequence = sequence,
            layerTurns = Profile.layerTurns(sequence),
            note = choice#note
        }

    ///
    /// A step that was not needed.
    ///
    def skipped(step: String, why: String): Stage =
        { step = step, caseName = "skip", sequence = "", layerTurns = 0, note = why }

    ///
    /// The stages, with what they cost together.
    ///
    def collect(stages: List[Stage]): Staged =
        { stages = stages,
          layerTurns = stages |> List.foldLeft((n, s) -> n + s#layerTurns, 0) }

}
