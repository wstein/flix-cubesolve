///
/// That every state a stage can meet has exactly one routine.
///
/// The executor observes a case and plays the routine for it. That only works
/// if the family is a partition: every actionable state classifies to one
/// situation, every situation has one record, and a state needing nothing says
/// so rather than selecting an insertion. A hole here would not be a wrong
/// answer -- it would be the executor meeting a state at run time with nothing
/// to play, which is a design decision deferred to the worst possible moment.
///
/// The corner family is checked exhaustively against its own declared list of
/// situations, which is the list the corpus must cover rather than however many
/// records happen to exist.
///
mod TestRoutineClosure {

    use CubeSolve.Method.Beginner.Routines
    use CubeSolve.Method.Beginner.Spec
    use CubeSolve.Method.Beginner.Spec.CornerStep
    use CubeSolve.Model.Cube

    ///
    /// Every declared corner situation has exactly one routine.
    ///
    @Test
    def everyCornerSituationHasOneRoutine(): Unit \ Assert =
        Spec.cornerSituations() |> List.forEach(s -> {
            let matching = Routines.all() |> List.filter(r -> r#situation == s);
            Assert.assertEqWithMsg(expected = 1, List.length(matching),
                "${s} should have exactly one routine, and has "
                    + "${List.length(matching)}")
        })

    ///
    /// And every corner routine answers a declared situation.
    ///
    /// The other direction: a record for a situation the stage cannot reach is
    /// dead data that will never be selected, and says the two disagree about
    /// what the family is.
    ///
    @Test
    def everyCornerRoutineAnswersADeclaredSituation(): Unit \ Assert =
        let declared = Spec.cornerSituations();
        Routines.cornerInsertions() |> List.forEach(r ->
            Assert.assertTrueWithMsg(List.memberOf(r#situation, declared),
                "'${r#name}' answers ${r#situation}, which the stage never asks for"))

    ///
    /// Each recorded setup classifies to the situation it was recorded for.
    ///
    /// This is the join between observation and selection: the classifier sees
    /// a cube and names a situation, and that name must find the routine that
    /// was derived for it.
    ///
    @Test
    def theClassifierNamesTheSituationTheRoutineAnswers(): Unit \ Assert =
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                Routines.cornerInsertions() |> List.forEach(r ->
                    match Cube.applyNotation(r#setup, solved) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "setup")
                        case Ok(c)  => match Spec.classifyCorner(c) {
                            case CornerStep.Insert(s) =>
                                Assert.assertEqWithMsg(expected = r#situation, s,
                                    "'${r#name}': its own setup classifies as ${s}")
                            case other =>
                                Assert.assertTrueWithMsg(false,
                                    "'${r#name}': its own setup classifies as ${other}, "
                                        + "so the executor would not select it")
                        }
                    })
        }

    ///
    /// A solved corner is `AlreadyDone`, not an insertion.
    ///
    /// The case that must not be answered with a routine: playing one here
    /// would take a finished corner out again, and a loop that did so would
    /// never terminate.
    ///
    @Test
    def aFinishedCornerAsksForNothing(): Unit \ Assert =
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                Assert.assertEqWithMsg(expected = CornerStep.AlreadyDone,
                    Spec.classifyCorner(solved),
                    "a solved cube's DFR corner needs no routine")
        }

    ///
    /// A cube whose lower rungs are not in place is refused, not classified.
    ///
    @Test
    def anUnreadyCubeIsRefusedByName(): Unit \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation("D", c)) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "turning D")
            case Ok(c)  => match Spec.classifyCorner(c) {
                case CornerStep.NotReady(_) => ()
                case other =>
                    Assert.assertTrueWithMsg(false,
                        "a cube with the cross broken classified as ${other} rather "
                            + "than saying the stage below it is not done")
            }
        }

    ///
    /// Every middle-edge situation has exactly one routine, and back again.
    ///
    @Test
    def theMiddleFamilyIsAlsoAPartition(): Unit \ Assert =
        let declared = List.range(0, 4) |> List.flatMap(slot ->
            List.range(0, 2) |> List.map(f -> Spec.Situation.MiddleInsert(slot, f)));
        declared |> List.forEach(s -> {
            let matching = Routines.all() |> List.filter(r -> r#situation == s);
            Assert.assertEqWithMsg(expected = 1, List.length(matching),
                "${s} should have exactly one routine, and has "
                    + "${List.length(matching)}")
        });
        Routines.middleInsertions() |> List.forEach(r ->
            Assert.assertTrueWithMsg(List.memberOf(r#situation, declared),
                "'${r#name}' answers ${r#situation}, which the stage never asks for"))
}
