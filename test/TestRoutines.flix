///
/// That the committed routines are still what derivation says they are.
///
/// The corpus is generated source, so the risk it carries is drift: a record
/// that no longer matches the search that produced it, or one that never did.
/// Every routine is put through the same six steps, which is the shape settled
/// on after a reversed answer once passed a test that checked only its length:
///
/// 1. derive it again, under the alphabet and goal the record states;
/// 2. the recorded sequence equals the derivation;
/// 3. replay the recorded setup from solved to reach the case;
/// 4. the goal predicate holds after the routine;
/// 5. every preservation the record claims still holds;
/// 6. the routine is the inverse of the setup, so the pair is a round trip.
///
mod TestRoutines {

    use CubeSolve.Method.Beginner.Routines
    use CubeSolve.Method.Derive
    use CubeSolve.Method.Facts
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    ///
    /// The moves a routine's alphabet allows, from its letters.
    ///
    def alphabetOf(letters: String): Vector[Move.Move] \ Assert =
        String.splitOn(substr = " ", letters)
            |> List.flatMap(l -> (l :: "${l}2" :: "${l}'" :: Nil))
            |> List.map(t -> match Move.parseMove(t) {
                case Ok(m)  => m
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e, "'${t}'"); unreachable!()
            })
            |> List.toVector

    ///
    /// The cross and the three bottom corners a right-hand insertion keeps.
    ///
    def preservedForInsertion(c: Cube.Cube): Bool =
        let ok = r -> Result.getWithDefault(false, r);
        ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, false))
            and ok(Facts.allHome(c, Vector#{5, 6, 7}, true))

    ///
    /// The first layer and the other three middle edges a middle insertion keeps.
    ///
    def preservedForMiddle(c: Cube.Cube): Bool =
        let ok = r -> Result.getWithDefault(false, r);
        ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, false))
            and ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, true))
            and ok(Facts.allHome(c, Vector#{9, 10, 11}, false))

    ///
    /// What a record claims to leave alone, as the predicate it means.
    ///
    def preservedBy(routine: Routines.Routine): Cube.Cube -> Bool =
        if (routine#preserves == "cross; corners DLF, DBL, DRB")
            preservedForInsertion
        else
            preservedForMiddle

    ///
    /// The goal a record names, as the predicate it means.
    ///
    def goalOf(routine: Routines.Routine): Cube.Cube -> Bool =
        if (routine#goal == "the DFR corner is home and untwisted")
            c -> preservedForInsertion(c)
                and Result.getWithDefault(false, Facts.cornerHome(c, 4))
        else if (routine#goal == "the FR edge is home and unflipped")
            c -> preservedForMiddle(c)
                and Result.getWithDefault(false, Facts.edgeHome(c, 8))
        else
            _ -> false

    ///
    /// The case a record's setup reaches: its goal, one step away.
    ///
    /// Rebuilt from the record's own name, so a record whose name this cannot
    /// read has no case to check against and fails rather than passing.
    ///
    def caseOf(routine: Routines.Routine): Option[Cube.Cube -> Bool] =
        match placeOf("corner-insert-right-twist-", routine#name) {
            case Some((_, twist)) =>
                Some(c -> preservedForInsertion(c) and (match Facts.findCorner(c, 4) {
                    case Ok(p)  => p#slot == 0 and p#turn == twist
                    case Err(_) => false
                }))
            case None => match middlePlace(routine#name) {
                case Some((slot, flip)) =>
                    Some(c -> preservedForMiddle(c) and (match Facts.findEdge(c, 8) {
                        case Ok(p)  => p#slot == slot and p#turn == flip
                        case Err(_) => false
                    }))
                case None => None
            }
        }

    ///
    /// The trailing number of a `<prefix>N` name, with no second part.
    ///
    def placeOf(prefix: String, name: String): Option[(Int32, Int32)] =
        if (String.startsWith(prefix = prefix, name))
            Int32.fromString(String.drop(String.length(prefix), name))
                |> Option.map(n -> (0, n))
        else
            None

    ///
    /// The slot and flip of a `middle-insert-slot-S-flip-F` name.
    ///
    def middlePlace(name: String): Option[(Int32, Int32)] =
        let head = "middle-insert-slot-";
        if (not String.startsWith(prefix = head, name))
            None
        else
            match String.splitOn(substr = "-flip-", String.drop(String.length(head), name)) {
                case s :: f :: Nil =>
                    match (Int32.fromString(s), Int32.fromString(f)) {
                        case (Some(a), Some(b)) => Some((a, b))
                        case _                  => None
                    }
                case _ => None
            }

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
        match caseOf(r) {
            case None =>
                Assert.assertTrueWithMsg(false,
                    "'${r#name}' has no case this test knows how to rebuild, so it "
                        + "cannot be verified and must not be shipped unchecked")
            case Some(theCase) =>
                // 3. the setup reaches the case
                match Cube.applyNotation(r#setup, solved) {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${r#name}' setup")
                    case Ok(caseCube) =>
                        Assert.assertTrueWithMsg(theCase(caseCube),
                            "'${r#name}': the recorded setup should reach its case");
                        // 1 and 2. derivation still gives this sequence
                        match Derive.shortest(solved, theCase, alphabetOf(r#alphabet), 8) {
                            case None =>
                                Assert.assertTrueWithMsg(false,
                                    "'${r#name}': the case is no longer reachable under "
                                        + "'${r#alphabet}'")
                            case Some(setup) =>
                                let derived = Move.showAll(Move.inverseOf(setup));
                                Assert.assertEqWithMsg(expected = derived, r#sequence,
                                    "'${r#name}' is recorded as '${r#sequence}' and derives "
                                        + "as '${derived}'");
                                Assert.assertEqWithMsg(expected = List.length(setup), r#length,
                                    "'${r#name}' records a length that is not its own")
                        };
                        replayed(r, caseCube)
                }
        }

    ///
    /// 4, 5 and 6: the goal, the preservations, and the round trip.
    ///
    def replayed(r: Routines.Routine, caseCube: Cube.Cube): Unit \ Assert =
        match Cube.applyNotation(r#sequence, caseCube) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${r#name}' replay")
            case Ok(done) =>
                Assert.assertTrueWithMsg(goalOf(r)(done),
                    "'${r#name}': after the routine its goal should hold -- ${r#goal}");
                Assert.assertTrueWithMsg(preservedBy(r)(done),
                    "'${r#name}': it claims to preserve ${r#preserves}, and did not");
                // 6. the routine undoes the setup exactly
                match Cube.solved(3) |> Result.flatMap(s -> Cube.applyNotation(r#setup, s))
                        |> Result.flatMap(s -> Cube.applyNotation(r#sequence, s)) {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e, "round trip")
                    case Ok(back) =>
                        Assert.assertTrueWithMsg(Cube.isSolved(back),
                            "'${r#name}': setup then routine should return to solved")
                }
        }

    ///
    /// The corpus says how it was made.
    ///
    @Test
    def theCorpusCarriesItsProvenance(): Unit \ Assert =
        Assert.assertTrueWithMsg(String.contains(substr = "Derive", Routines.provenance()),
            "the provenance should name what derived it: ${Routines.provenance()}");
        Assert.assertTrueWithMsg(String.contains(substr = Routines.policy(), Routines.provenance()),
            "and the policy it was derived under: ${Routines.provenance()}")
}
