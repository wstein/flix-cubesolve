///
/// That the committed routines are still what derivation says they are.
///
/// The corpus is generated source, so the risk it carries is drift: a record
/// that no longer matches the search that produced it, or one that never did.
/// Every routine goes through the same steps, which is the shape this project
/// settled on after a reversed answer once passed a test that checked only the
/// length of what it was given:
///
/// 1. derive it again, under its situation's own alphabet and bound;
/// 2. the recorded sequence equals the derivation;
/// 3. replay the recorded setup from solved to reach the case;
/// 4. what the situation *achieves* holds afterwards;
/// 5. what it *preserves* holds afterwards;
/// 6. setup then routine returns to solved.
///
/// **Nothing here reads a string to decide what a record means.** Its situation
/// is a value, and `Spec` answers every question about it, so a record cannot
/// be checked against the wrong claim by naming it slightly wrong.
///
mod TestRoutines {

    use CubeSolve.Method.Beginner.Routines
    use CubeSolve.Method.Beginner.Spec
    use CubeSolve.Method.Derive
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    ///
    /// Every record, through all six steps.
    ///
    @Test
    def everyRoutineIsWhatDerivationSays(): Unit \ Assert =
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) => Routines.all() |> List.forEach(r -> check(solved, r))
        }

    def check(solved: Cube.Cube, r: Routines.Routine): Unit \ Assert =
        let s = r#situation;
        match Cube.applyNotation(r#setup, solved) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${r#name}' setup")
            case Ok(caseCube) =>
                Assert.assertTrueWithMsg(Spec.caseHolds(s)(caseCube),
                    "'${r#name}': the recorded setup should reach its own case");
                derivesTheSame(solved, r);
                replayed(r, caseCube)
        }

    ///
    /// 1 and 2: the search still gives this sequence, at this length.
    ///
    def derivesTheSame(solved: Cube.Cube, r: Routines.Routine): Unit \ Assert =
        let s = r#situation;
        match Derive.shortest(solved, Spec.caseHolds(s), Spec.alphabet(s), Spec.maxDepth(s)) {
            case None =>
                Assert.assertTrueWithMsg(false,
                    "'${r#name}': its case is no longer reachable under "
                        + "'${Spec.alphabetWritten(s)}' within ${Spec.maxDepth(s)}")
            case Some(setup) =>
                let derived = Move.showAll(Move.inverseOf(setup));
                Assert.assertEqWithMsg(expected = derived, r#sequence,
                    "'${r#name}' is recorded as '${r#sequence}' and derives as "
                        + "'${derived}'");
                Assert.assertEqWithMsg(expected = List.length(setup), r#length,
                    "'${r#name}' records a length that is not its own")
        }

    ///
    /// 4, 5 and 6: what it achieves, what it preserves, and the round trip.
    ///
    /// `achieves` and `preserves` are asserted separately and nothing stronger
    /// is asserted at all. A routine that happened to solve more of this
    /// particular fixture must not have the extra become a requirement.
    ///
    def replayed(r: Routines.Routine, caseCube: Cube.Cube): Unit \ Assert =
        let s = r#situation;
        match Cube.applyNotation(r#sequence, caseCube) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${r#name}' replay")
            case Ok(done) =>
                Assert.assertTrueWithMsg(Spec.achieves(s)(done),
                    "'${r#name}': afterwards ${Spec.achievesWritten(s)}");
                Assert.assertTrueWithMsg(Spec.preserves(s)(done),
                    "'${r#name}': it must leave ${Spec.preservesWritten(s)} alone");
                Assert.assertTrueWithMsg(Cube.isSolved(done),
                    "'${r#name}': its setup is the inverse of it, so the two "
                        + "together should return to solved")
        }

    ///
    /// A routine can be found by the situation it answers.
    ///
    /// How the method will choose: observe a situation, ask for its routine.
    /// Every record must be reachable that way, or it is unreachable data.
    ///
    @Test
    def everySituationFindsItsRoutine(): Unit \ Assert =
        Routines.all() |> List.forEach(r ->
            match Routines.forSituation(r#situation) {
                case None    =>
                    Assert.assertTrueWithMsg(false,
                        "'${r#name}' cannot be found by its own situation")
                case Some(f) =>
                    Assert.assertEqWithMsg(expected = r#name, f#name,
                        "two records answer ${r#situation}, so choosing is ambiguous")
            })

    ///
    /// The corpus says how it was made.
    ///
    @Test
    def theCorpusCarriesItsProvenance(): Unit \ Assert =
        Assert.assertTrueWithMsg(String.contains(substr = "Derive", Routines.provenance()),
            "the provenance should name what derived it: ${Routines.provenance()}");
        Assert.assertTrueWithMsg(
            String.contains(substr = Routines.policy(), Routines.provenance()),
            "and the policy it was derived under: ${Routines.provenance()}")
}
