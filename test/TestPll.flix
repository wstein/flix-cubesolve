///
/// Recognising a PLL case and playing back its algorithm.
///
/// The property that matters is not "the right name comes back" but "the answer
/// solves the cube in hand". Recognition returns a sequence it has already
/// replayed, so the test replays it again independently: a recogniser that
/// returned the right case with the wrong AUF would name the case correctly and
/// hand back something that does not work.
///
mod TestPll {

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
    /// Running an algorithm backwards from solved is what puts a cube into the
    /// case that algorithm solves, which makes every case constructible without
    /// a scramble that happens to land there.
    ///
    def inCase(one: Pll.Case, auf: Int32): Cube.Cube \ Assert =
        made("${Pll.aufOf(auf)} ${inverseOf(Pll.algorithm(one))}")

    def inverseOf(alg: String): String = "(${alg})'"

    ///
    /// Every case, arriving turned all four ways, is recognised and solved.
    ///
    /// 21 cases by 4 approaches. The returned sequence is applied here rather
    /// than trusted, and the case name is checked too, so a recogniser that
    /// solved the cube by stumbling onto a different case would fail.
    ///
    @Test
    def everyCaseIsRecognisedFromEveryAngleAndItsAnswerSolves(): Unit \ Assert =
        Assert.assertEqWithMsg(expected = 21, Vector.length(Pll.all()),
            "PLL has 21 cases");
        Pll.all() |> Vector.forEach(one ->
            Vector.range(0, 4) |> Vector.forEach(auf -> {
                let c = inCase(one, auf);
                match Pll.recognize(c) {
                    case Err(e) =>
                        Assert.assertEqWithMsg(expected = "", e,
                            "'${Pll.name(one)}' turned ${auf} should be recognised")
                    case Ok(found) =>
                        Assert.assertEqWithMsg(expected = Pll.name(one), found#caseName,
                            "turned ${auf}, recognised as the wrong case");
                        match Cube.applyNotation(found#sequence, c) {
                            case Err(e) =>
                                Assert.assertEqWithMsg(expected = "", e, "replaying")
                            case Ok(after) =>
                                Assert.assertTrueWithMsg(Cube.isSolved(after),
                                    "'${Pll.name(one)}' turned ${auf}: the answer "
                                        + "'${found#sequence}' does not solve it")
                        }
                }
            }))

    ///
    /// Every recorded algorithm parses, and is at least as long as the optimum
    /// the same source gives.
    ///
    /// A speed algorithm being longer than the optimal one is the whole reason
    /// both numbers are recorded; a recorded algorithm *shorter* than the stated
    /// optimum would mean one of the two figures is wrong.
    ///
    @Test
    def everyAlgorithmParsesAndIsNoShorterThanTheOptimum(): Unit \ Assert =
        Pll.all() |> Vector.forEach(one -> {
            match CubeSolve.Model.Notation.parse(3, Pll.algorithm(one)) {
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e,
                        "'${Pll.name(one)}' does not parse")
                case Ok(ops) =>
                    let turns = List.length(CubeSolve.Model.Notation.layersOnly(ops));
                    Assert.assertTrueWithMsg(turns >= Pll.optimalHtm(one),
                        "'${Pll.name(one)}' is ${turns} layer turns against a stated "
                            + "optimum of ${Pll.optimalHtm(one)}")
            };
            Assert.assertTrueWithMsg(Pll.optimalHtm(one) > 0,
                "'${Pll.name(one)}' has no recorded optimum")
        })

    ///
    /// A solved cube is not a PLL case to solve, and is not refused either.
    ///
    /// It meets the precondition -- first two layers solved, last layer oriented
    /// -- so the honest answer is that some case's algorithm plus AUFs leaves it
    /// solved, which is what recognition finds.
    ///
    @Test
    def aSolvedCubeMeetsThePrecondition(): Unit \ Assert =
        Assert.assertEq(expected = None, Pll.precondition(made("")))

    ///
    /// The three states that are not PLL, each refused for its own reason.
    ///
    @Test
    def statesThatAreNotPllAreRefusedByReason(): Unit \ Assert =
        let refused = (what, alg, expected) ->
            match Pll.recognize(made(alg)) {
                case Ok(found) =>
                    Assert.assertTrueWithMsg(false,
                        "${what} should be refused, not recognised as "
                            + "'${found#caseName}'")
                case Err(why) =>
                    Assert.assertTrueWithMsg(String.contains(substr = expected, why),
                        "${what} should be refused for ${expected}, not: ${why}")
            };
        // F2L broken: a single R turn moves bottom and middle pieces.
        refused("a cube with unsolved F2L", "R", "first two layers");
        // OLL but not PLL: Sune leaves the top layer unoriented.
        refused("an OLL-but-not-PLL state", "(R U R' U R U2 R')'", "not oriented");
        // An ordinary scramble is neither.
        refused("a general scramble", "R U R' U' F2 L D B' R2 F", "first two layers")

    ///
    /// A 2x2x2 is refused by size rather than by orbit.
    ///
    @Test
    def aPocketCubeIsRefusedBySize(): Unit \ Assert =
        match Cube.solved(2) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "a solved 2x2x2")
            case Ok(c)  =>
                match Pll.precondition(c) {
                    case None      => Assert.assertTrueWithMsg(false, "a 2x2x2 has no PLL")
                    case Some(why) =>
                        Assert.assertTrue(String.contains(substr = "2x2x2", why))
                }
        }

}
