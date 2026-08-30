///
/// Recognising an OLL case and playing back its algorithm.
///
/// Same property as PLL: the answer must orient the cube in hand, not merely
/// name it. And a second one PLL does not need -- an OLL algorithm must leave
/// the first two layers alone, so a corpus entry that oriented the top while
/// disturbing what is below it would be caught here rather than by whoever ran
/// it on a real cube.
///
mod TestOll {

    use CubeSolve.Method.LastLayer
    use CubeSolve.Method.Oll
    use CubeSolve.Method.Pll
    use CubeSolve.Model.Cube

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// A cube in the case `one` describes, reached by undoing its algorithm.
    ///
    def inCase(one: Oll.Case, auf: Int32): Cube.Cube \ Assert =
        made("${Oll.aufOf(auf)} (${Oll.algorithm(one)})'")

    ///
    /// Every case, from every angle, is recognised and oriented -- and the
    /// layers below are left where they were.
    ///
    @Test
    def everyCaseIsRecognisedAndItsAnswerOrientsWithoutDisturbingF2l(): Unit \ Assert =
        Assert.assertEqWithMsg(expected = 57, Vector.length(Oll.all()),
            "OLL has 57 cases");
        Oll.all() |> Vector.forEach(one ->
            Vector.range(0, 4) |> Vector.forEach(auf -> {
                let c = inCase(one, auf);
                match Oll.recognize(c) {
                    case Err(e) =>
                        Assert.assertEqWithMsg(expected = "", e,
                            "'${Oll.name(one)}' turned ${auf} should be recognised")
                    case Ok(found) =>
                        // Each case is found as itself. Unlike PLL, several
                        // algorithms could in principle orient one state --
                        // orienting says nothing about where pieces sit -- but
                        // an algorithm orients the pattern it was written for
                        // and not another, so recognition is unambiguous. It was
                        // measured before being asserted.
                        Assert.assertEqWithMsg(expected = Oll.name(one), found#caseName,
                            "turned ${auf}, recognised as a different case");
                        match Cube.applyNotation(found#sequence, c) {
                            case Err(e) =>
                                Assert.assertEqWithMsg(expected = "", e, "replaying")
                            case Ok(after) =>
                                Assert.assertTrueWithMsg(LastLayer.topIsOriented(after),
                                    "'${Oll.name(one)}' turned ${auf}: "
                                        + "'${found#sequence}' did not orient the top");
                                Assert.assertEqWithMsg(
                                    expected = None, LastLayer.faultBelowTheTop(after),
                                    "'${Oll.name(one)}' turned ${auf}: "
                                        + "'${found#sequence}' disturbed the layers below")
                        }
                }
            }))

    ///
    /// Every recorded algorithm parses.
    ///
    @Test
    def everyAlgorithmParses(): Unit \ Assert =
        Oll.all() |> Vector.forEach(one ->
            match CubeSolve.Model.Notation.parse(3, Oll.algorithm(one)) {
                case Ok(_)  => ()
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e,
                        "'${Oll.name(one)}' does not parse")
            })

    ///
    /// What OLL finishes is what PLL requires.
    ///
    /// The two steps meet at one state, and this is the assertion that they
    /// agree about it: solving an OLL case leaves a cube PLL will accept.
    ///
    @Test
    def whatOllFinishesIsWhatPllAccepts(): Unit \ Assert =
        Oll.all() |> Vector.forEach(one -> {
            let c = inCase(one, 0);
            let solved = Oll.recognize(c)
                |> Result.flatMap(found -> Cube.applyNotation(found#sequence, c));
            match solved {
                case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "solving")
                case Ok(after) =>
                    Assert.assertEqWithMsg(expected = None, Pll.precondition(after),
                        "'${Oll.name(one)}' solved should be a PLL case")
            }
        })

    ///
    /// The states that are not OLL, each refused for its own reason.
    ///
    @Test
    def statesThatAreNotOllAreRefusedByReason(): Unit \ Assert =
        let refused = (what, alg, expected) ->
            match Oll.recognize(made(alg)) {
                case Ok(found) =>
                    Assert.assertTrueWithMsg(false,
                        "${what} should be refused, not read as '${found#caseName}'")
                case Err(why) =>
                    Assert.assertTrueWithMsg(String.contains(substr = expected, why),
                        "${what} should be refused for ${expected}, not: ${why}")
            };
        refused("a cube with unsolved F2L", "R", "first two layers");
        refused("a general scramble", "R U R' U' F2 L D B' R2 F", "first two layers");
        // Already oriented: a real state, but not one OLL has anything to do to.
        refused("a PLL case", "(R U R' U' R' F R2 U' R' U' R U R' F')'",
            "already oriented");
        refused("a solved cube", "", "already oriented")

}
