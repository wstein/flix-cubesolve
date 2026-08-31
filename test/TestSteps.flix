///
/// Turning an algorithm into a step of a plan.
///
mod TestSteps {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Notation

    ///
    /// An algorithm that rotates the cube cannot be written as layer turns.
    ///
    /// This is the defect this module exists for. `Notation.layersOnly` keeps
    /// layer turns and drops frame rotations, which is right for a search --
    /// a search never rotates -- and wrong for a published algorithm, because
    /// several OLL and PLL algorithms turn the whole cube partway through.
    /// Dropping the rotation leaves every later turn naming a different face,
    /// so the sequence stops solving.
    ///
    /// A plan therefore carries each step as the notation it was given, not as
    /// a flattened list of layer turns.
    ///
    @Test
    def flatteningAnAlgorithmThatRotatesChangesWhatItDoes(): Unit \ Assert =
        let withRotation = "R U R' U' y l' U' L U L' l";
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(start) =>
                let whole = Cube.applyNotation(withRotation, start);
                let flattened =
                    Notation.parse(3, withRotation)
                        |> Result.map(Notation.layersOnly)
                        |> Result.flatMap(ms -> Cube.applyAll(ms, start));
                match (whole, flattened) {
                    case (Ok(a), Ok(b)) =>
                        Assert.assertTrueWithMsg(
                            Facelets.token(a) != Facelets.token(b),
                            "if these agree, flattening is safe and this test is "
                                + "wrong; they must differ, which is why a step "
                                + "keeps its notation")
                    case _ => Assert.assertTrueWithMsg(false, "both should apply")
                }
        }

    ///
    /// Compacting notation composes adjacent turns of one face and nothing else.
    ///
    @Test
    def compactingNotationLeavesRotationsAndWideMovesAlone(): Unit \ Assert =
        let cases =
            ("U U U U F U R U' R' F'", "F U R U' R' F'")
                :: ("U2 U2 F", "F")
                :: ("R U R' U' y l' U' L U L' l", "R U R' U' y l' U' L U L' l")
                :: ("U U y U U", "U2 y U2")
                :: ("(y') R U2 R'", "(y') R U2 R'")
                :: ("R R R", "R'")
                :: Nil;
        cases |> List.forEach(match (given, want) ->
            Assert.assertEqWithMsg(expected = want, Notation.compact(given),
                "compacting '${given}'"))

    ///
    /// Compacting never changes what a sequence does.
    ///
    @Test
    def compactingNotationPreservesTheCube(): Unit \ Assert =
        let sequences =
            "U U U U F U R U' R' F'"
                :: "R U R' U' y l' U' L U L' l"
                :: "U U y U U"
                :: "F F F B B B"
                :: Nil;
        sequences |> List.forEach(text ->
            match Cube.solved(3) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
                case Ok(start) =>
                    match (Cube.applyNotation(text, start),
                           Cube.applyNotation(Notation.compact(text), start)) {
                        case (Ok(a), Ok(b)) =>
                            Assert.assertEqWithMsg(
                                expected = Facelets.token(a), Facelets.token(b),
                                "compacting '${text}' changed what it does")
                        case _ => Assert.assertTrueWithMsg(false, "applying '${text}'")
                    }
            })
}
