///
/// Recognising a cube as a published pattern, on both puzzles.
///
/// The property under test is not "the right name comes back". It is that the
/// witness handed back with the name is *usable*: reframe the pattern's recorded
/// solution by it and the cube in hand solves. A witness that is off by an
/// inverse still names the pattern correctly and still fails here, which is the
/// only reason this test is written round-trip rather than by comparing tokens.
/// That exact mistake has been made in this codebase before, in
/// `Cube.reframeSolution`, and nothing but a replay caught it.
///
mod TestPatternRecognition {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Rotation
    use CubeSolve.Patterns

    def made(size: Int32, what: String, alg: String): Cube.Cube \ Assert =
        match Cube.solved(size) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "${what}: '${alg}'");
                unreachable!()
        }

    def isSolved(c: Cube.Cube): Bool =
        Cube.solved(Cube.size(c))
            |> Result.map(s -> Cube.orbits(s) == Cube.orbits(c))
            |> Result.getWithDefault(false)

    ///
    /// Every 3x3x3 pattern, in all 24 orientations, is recognised and solved by
    /// the solution its own witness reframes.
    ///
    @Test
    def everyStandardPatternIsRecognisedHoweverItIsHeld(): Unit \ Assert =
        Patterns.Standard.all() |> Vector.forEach(p -> {
            let name = Patterns.Standard.name(p);
            let upright = made(3, name, Patterns.Standard.faceTurns(p));
            Rotation.all() |> Vector.forEach(r -> {
                let held = match Cube.conjugate(r, upright) {
                    case Ok(x)  => x
                    case Err(e) =>
                        Assert.assertEqWithMsg(expected = "", e, "conjugating");
                        upright
                };
                match Patterns.Standard.recognize(held) {
                    case None =>
                        Assert.assertTrueWithMsg(false,
                            "'${name}' held as ${r} was not recognised")
                    case Some((found, witness)) =>
                        Assert.assertEqWithMsg(
                            expected = Patterns.Standard.canonical(p),
                            Patterns.Standard.canonical(found),
                            "'${name}' held as ${r} was recognised as "
                                + "'${Patterns.Standard.name(found)}'");
                        match Patterns.Standard.solutionFor(found, witness) {
                            case Err(e) =>
                                Assert.assertEqWithMsg(expected = "", e, "'${name}' as ${r}")
                            case Ok(ms) =>
                                match Cube.applyAll(ms, held) {
                                    case Err(e) =>
                                        Assert.assertEqWithMsg(expected = "", e, "'${name}'")
                                    case Ok(after) =>
                                        Assert.assertTrueWithMsg(isSolved(after),
                                            "'${name}' held as ${r}: the witnessed "
                                                + "solution did not solve it")
                                }
                        }
                }
            })
        })

    ///
    /// The same for the 2x2x2, under its own equivalence.
    ///
    /// The re-holdings here are *moves*, not conjugations, because that is what
    /// re-holding a centreless puzzle is. Feeding conjugations in instead would
    /// make this test pass against a `recognize` that is wrong for the puzzle.
    ///
    @Test
    def everyPocketPatternIsRecognisedHoweverItIsHeld(): Unit \ Assert =
        Patterns.Pocket.all() |> Vector.forEach(p -> {
            let name = Patterns.Pocket.name(p);
            let upright = made(2, name, Patterns.Pocket.optimal(p));
            Patterns.Pocket.reorientations() |> Vector.forEach(match (r, word) -> {
                let held = match Cube.applyNotation(word, upright) {
                    case Ok(c)  => c
                    case Err(e) =>
                        Assert.assertEqWithMsg(expected = "", e, "'${name}' as '${word}'");
                        upright
                };
                match Patterns.Pocket.recognize(held) {
                    case None =>
                        Assert.assertTrueWithMsg(false,
                            "'${name}' held as ${r} was not recognised")
                    case Some((found, witness)) =>
                        Assert.assertEqWithMsg(
                            expected = Patterns.Pocket.canonical(p),
                            Patterns.Pocket.canonical(found),
                            "'${name}' held as ${r} was recognised as "
                                + "'${Patterns.Pocket.name(found)}'");
                        match Patterns.Pocket.solutionFor(found, witness) {
                            case Err(e) =>
                                Assert.assertEqWithMsg(expected = "", e, "'${name}' as ${r}")
                            case Ok(ms) =>
                                match Cube.applyAll(ms, held) {
                                    case Err(e) =>
                                        Assert.assertEqWithMsg(expected = "", e, "'${name}'")
                                    case Ok(after) =>
                                        Assert.assertTrueWithMsg(isSolved(after),
                                            "'${name}' held as ${r}: the witnessed "
                                                + "solution did not solve it")
                                }
                        }
                }
            })
        })

    ///
    /// An ordinary scramble is not a published pattern, and recognition says so.
    ///
    /// Without this, a `recognize` that returned the nearest entry rather than a
    /// match would pass everything above.
    ///
    @Test
    def anUnremarkableScrambleIsNotRecognised(): Unit \ Assert =
        Assert.assertEq(expected = None,
            Patterns.Standard.recognize(made(3, "scramble", "R U R' U' F' L F2 D B2")));
        Assert.assertEq(expected = None,
            Patterns.Pocket.recognize(made(2, "scramble", "R U' F R2 U F'")));
        Assert.assertEq(expected = None,
            Patterns.Standard.recognize(made(3, "solved", "")));
        Assert.assertEq(expected = None,
            Patterns.Pocket.recognize(made(2, "solved", "")))

    ///
    /// The 24 pocket re-holdings are distinct, compose the way their rotations
    /// do, and really are re-holdings.
    ///
    /// The pairing between a rotation and a word is what `solutionFor` reads a
    /// witness through, so it has to mean something. Two checks give it meaning
    /// without leaning on `recognize`, which is built from this table and so
    /// cannot vouch for it:
    ///
    /// - **It composes.** Doing `w1` then `w2` reaches the state paired with
    ///   `andThen(r1, r2)`. A table that paired the right 24 words with the
    ///   rotations in the wrong order would pass distinctness and fail here.
    /// That the words are re-holdings at all -- that `x` really is `R L'` and
    /// not, say, `R L` -- is not checked here and cannot be, because the table
    /// is built by closing over those generators and every structural property
    /// of it follows by construction. What checks it is
    /// `everyPocketPatternIsRecognisedHoweverItIsHeld` above: 89 identities,
    /// each validated against its published name in `TestPocketPatterns`, all
    /// stable under all 24 words. Wrong generators would carry a pattern to a
    /// state that is no known pattern, and recognition would come back empty.
    ///
    /// Two things are deliberately *not* asserted, both of them 3x3x3 intuitions
    /// that are false here.
    ///
    /// A re-holding does not leave a solved cube solved: every piece changes
    /// slot, and only the absence of centres makes that unobservable. And a
    /// re-holding does not preserve the solving distance either, which is the
    /// more surprising one. `CubeSolve.Solve.Pocket` holds the `DBL` corner
    /// fixed and generates from `U R F` alone -- that is what makes the state
    /// space 7! x 3^6 rather than 8! x 3^7 -- so a word that moves `DBL` lands
    /// on a genuinely different state of that model, and it can sit at a
    /// different depth. The puzzle in the hand is unchanged; the coordinate
    /// system is not.
    ///
    @Test
    def thePocketReHoldingsAreTwentyFourComposingTurns(): Unit \ Assert =
        let table = Patterns.Pocket.reorientations();
        Assert.assertEqWithMsg(expected = 24, Vector.length(table),
            "a centreless cube can be held 24 ways");
        let rotations = table |> Vector.map(fst) |> Vector.toList;
        Assert.assertEqWithMsg(expected = 24, List.length(List.distinct(rotations)),
            "two entries name the same rotation");
        let words = table |> Vector.map(snd) |> Vector.toList;
        Assert.assertEqWithMsg(expected = 24, List.length(List.distinct(words)),
            "two entries use the same word");

        let probe = made(2, "probe", "R U' F2 R U R' F U2");
        let reached = word -> match Cube.applyNotation(word, probe) {
            case Ok(c)  => Cube.orbits(c)
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${word}'"); Nil
        };
        table |> Vector.forEach(match (r1, w1) ->
            table |> Vector.forEach(match (r2, w2) -> {
                let combined = Rotation.andThen(r1, r2);
                match Patterns.Pocket.wordFor(combined) {
                    case None =>
                        Assert.assertTrueWithMsg(false,
                            "${r1} then ${r2} is not in the table")
                    case Some(w) =>
                        Assert.assertEqWithMsg(
                            expected = reached(w), reached("${w1} ${w2}"),
                            "'${w1}' then '${w2}' should reach the same state as '${w}'")
                }
            }))

}
