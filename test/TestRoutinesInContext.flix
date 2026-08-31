///
/// That a routine works wherever its case holds, not only from its own setup.
///
/// Every recorded setup starts from solved, so in that one fixture the pieces
/// the routine says nothing about happen to be solved too. The claim a routine
/// actually makes is stronger: **whenever its case and its preservation
/// precondition hold, it achieves its rung and leaves the earlier rungs alone**
/// -- however the pieces it does not mention are arranged.
///
/// Compatible states are found rather than constructed. Starting from the
/// recorded case, sequences over the routine's own alphabet are applied and
/// kept when the case still holds; each one leaves the untouched top-layer
/// pieces somewhere different. That gives states this corpus has never seen,
/// reached without asserting anything about how they were built.
///
mod TestRoutinesInContext {

    use CubeSolve.Method.Beginner.Routines
    use CubeSolve.Method.Beginner.Spec
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    ///
    /// States where `r`'s case still holds, reached from its own case.
    ///
    /// Depth two over the routine's alphabet, which is enough to move the top
    /// layer's other pieces around without leaving the case.
    ///
    def compatible(r: Routines.Routine, caseCube: Cube.Cube): List[(String, Cube.Cube)] =
        let holds = Spec.caseHolds(r#situation);
        let ms = Spec.alphabet(r#situation);
        let ones = ms |> Vector.toList |> List.map(m -> (Move.show(m), m));
        let pair = (an, a) -> ones |> List.map(match (bn, b) ->
            ("${an} ${bn}", a :: b :: Nil));
        let twos = ones |> List.flatMap(match (an, a) -> pair(an, a));
        let singles = ones |> List.map(match (n, m) -> (n, m :: Nil));
        let candidates = List.append(singles, twos);
        candidates
            |> List.filterMap(match (name, seq) -> match Cube.applyAll(seq, caseCube) {
                case Ok(after) if holds(after) => Some((name, after))
                case _                         => None
            })

    ///
    /// Every routine, in every compatible state reachable two moves away.
    ///
    @Test
    def everyRoutineWorksWhereverItsCaseHolds(): Unit \ Assert =
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                Routines.all() |> List.forEach(r ->
                    match Cube.applyNotation(r#setup, solved) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "setup")
                        case Ok(caseCube) => inEachOf(r, compatible(r, caseCube))
                    })
        }

    def inEachOf(r: Routines.Routine, states: List[(String, Cube.Cube)]): Unit \ Assert =
        let s = r#situation;
        states |> List.forEach(match (how, start) ->
            match Cube.applyNotation(r#sequence, start) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${r#name}' replay")
                case Ok(done) =>
                    Assert.assertTrueWithMsg(Spec.achieves(s)(done),
                        "'${r#name}' after '${how}': ${Spec.achievesWritten(s)} should "
                            + "hold, and does not");
                    Assert.assertTrueWithMsg(Spec.preserves(s)(done),
                        "'${r#name}' after '${how}': it must leave "
                            + "${Spec.preservesWritten(s)} alone, and did not")
            })

    ///
    /// The states being checked are not all the recorded one.
    ///
    /// Without this the test above could pass by finding nothing: an empty list
    /// satisfies every assertion made of its elements. Each routine must be
    /// exercised somewhere other than its own setup.
    ///
    @Test
    def thereAreCompatibleStatesToCheck(): Unit \ Assert =
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                Routines.all() |> List.forEach(r ->
                    match Cube.applyNotation(r#setup, solved) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e, "setup")
                        case Ok(caseCube) =>
                            let found = compatible(r, caseCube);
                            Assert.assertTrueWithMsg(not List.isEmpty(found),
                                "'${r#name}' has no compatible state other than its own "
                                    + "setup, so the context test proves nothing for it")
                    })
        }

    ///
    /// The checks reject a routine that preserves the wrong thing.
    ///
    /// A verifier that only ever sees correct routines is not known to
    /// discriminate. These are deliberately wrong sequences: each reaches its
    /// situation's rung and wrecks something the situation says it must leave
    /// alone, and `preserves` must therefore refuse it while `achieves` does
    /// not. If both passed, the preservation half of every check above would be
    /// decoration.
    ///
    @Test
    def preservationRejectsARoutineThatBreaksALowerRung(): Unit \ Assert =
        // Each of these inserts the piece correctly and then lifts a bottom
        // corner out of the layer with `L U L'`, which the `L` layer reaches and
        // the target piece does not.
        wrongOne("corner", Spec.Situation.CornerInsertion(0, 1), "R U' R'",
            "R U R' L U L'");
        wrongOne("middle", Spec.Situation.MiddleInsert(3, 0),
            "R U R' U' F' U' F", "F' U F U R U' R' L U L'")

    ///
    /// One deliberately wrong sequence, from the case its situation names.
    ///
    def wrongOne(
        what: String,
        s: Spec.Situation,
        setup: String,
        wrong: String
    ): Unit \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(setup, c)) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "${what} setup")
            case Ok(caseCube) =>
                Assert.assertTrueWithMsg(Spec.caseHolds(s)(caseCube),
                    "${what}: the setup should reach the case being spoiled");
                match Cube.applyNotation(wrong, caseCube) {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e, "${what} wrong")
                    case Ok(done) =>
                        Assert.assertTrueWithMsg(Spec.achieves(s)(done),
                            "${what}: the wrong sequence should still reach the rung, or "
                                + "it tests nothing about preservation");
                        Assert.assertTrueWithMsg(not Spec.preserves(s)(done),
                            "${what}: '${wrong}' breaks a lower rung and preservation "
                                + "must refuse it")
                }
        }

}
