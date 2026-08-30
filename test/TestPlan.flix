///
/// Solutions written as labelled steps.
///
mod TestPlan {

    use CubeSolve.Method
    use CubeSolve.Method.Oll
    use CubeSolve.Method.Pll
    use CubeSolve.Method.Plan
    use CubeSolve.Method.Profile.Profile.SourceFirst
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    def parsed(text: String): Plan.Plan \ Assert =
        match Plan.parse(3, text) {
            case Ok(p)  => p
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "parsing"); Plan.of(Nil)
        }

    ///
    /// The written form parses into the steps it shows.
    ///
    @Test
    def aWrittenPlanParsesIntoItsSteps(): Unit \ Assert =
        let text = List.join(String.lineSeparator(),
            "y // Inspection"
                :: "D' L' // Cross"
                :: "U R' F' R2 F2 // First pair"
                :: Nil);
        let p = parsed(text);
        Assert.assertEqWithMsg(expected = 3, List.length(p#steps), "three steps");
        Assert.assertEq(expected = "Inspection" :: "Cross" :: "First pair" :: Nil,
            p#steps |> List.map(s -> s#label));
        Assert.assertEq(expected = "y" :: "D' L'" :: "U R' F' R2 F2" :: Nil,
            p#steps |> List.map(s -> s#sequence))

    ///
    /// A rotation stays a rotation.
    ///
    /// `y` is a frame operation, and it has to remain one: it changes how every
    /// later move name resolves, so treating it as a note would quietly change
    /// what the rest of the plan does. Checked by replaying the flattened ops
    /// and comparing with the same moves applied directly.
    ///
    @Test
    def aRotationInAPlanIsAMoveNotAnAnnotation(): Unit \ Assert =
        let p = parsed("y // Inspection${String.lineSeparator()}R // then a turn");
        let byPlan = Cube.solved(3) |> Result.flatMap(c ->
            List.foldLeft((acc, op) -> Result.flatMap(x -> Cube.applyOp(op, x), acc),
                Ok(c), Plan.ops(p)));
        let direct = Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation("y R", c));
        Assert.assertEqWithMsg(
            expected = direct |> Result.map(Cube.orbits),
            byPlan |> Result.map(Cube.orbits),
            "a plan's ops must do what the same moves do written out");
        // and the y really is a Frame op rather than something dropped
        Assert.assertEqWithMsg(expected = 2, List.length(Plan.ops(p)),
            "both the rotation and the turn are operations");
        Assert.assertEqWithMsg(expected = 1, List.length(Notation.layersOnly(Plan.ops(p))),
            "but only one of them turns a layer")

    ///
    /// `#` is read and `//` is written.
    ///
    @Test
    def hashIsAcceptedAndSlashesAreWritten(): Unit \ Assert =
        let p = parsed("R U R' # sexy");
        Assert.assertEq(expected = "sexy" :: Nil, p#steps |> List.map(s -> s#label));
        Assert.assertEqWithMsg(expected = "R U R' // sexy", Plan.render(p),
            "the written form uses //")

    ///
    /// A label with no moves is a step, and survives the round trip.
    ///
    @Test
    def aLabelWithNoMovesIsAStep(): Unit \ Assert =
        let p = parsed("// OLL skip");
        Assert.assertEqWithMsg(expected = 1, List.length(p#steps), "a note is a step");
        Assert.assertTrue(List.isEmpty(Plan.ops(p)));
        Assert.assertEq(expected = "// OLL skip", Plan.render(p))

    ///
    /// Rendering and parsing are inverse.
    ///
    @Test
    def renderingRoundTripsThroughParsing(): Unit \ Assert =
        Vector#{
            "y // Inspection",
            "R U R' U' // sexy${String.lineSeparator()}// OLL skip",
            "D' L'${String.lineSeparator()}U R' F' R2 F2 // pair"
        } |> Vector.forEach(text -> {
            let once = Plan.render(parsed(text));
            let twice = Plan.render(parsed(once));
            Assert.assertEqWithMsg(expected = once, twice,
                "rendering a parsed plan should be stable")
        })

    ///
    /// A scramble is context and never part of the answer.
    ///
    /// Concatenating it would return a sequence that scrambles the cube before
    /// solving it, which is the one thing a solution must not do.
    ///
    @Test
    def aScrambleIsContextAndNotAStep(): Unit \ Assert =
        let text = List.join(String.lineSeparator(),
            "Scramble: R U R' U'" :: "" :: "U R U' R' // undo it" :: Nil);
        let p = parsed(text);
        Assert.assertEqWithMsg(expected = Some("R U R' U'"), p#scramble,
            "the scramble is recorded");
        Assert.assertEqWithMsg(expected = 1, List.length(p#steps),
            "and is not one of the steps");
        Assert.assertEqWithMsg(expected = "U R U' R'", Plan.sequenceOf(p),
            "nor part of the moves");
        Assert.assertTrueWithMsg(String.contains(substr = "Scramble: R U R' U'", Plan.render(p)),
            "but it is shown above the plan")

    ///
    /// A method's answer becomes a plan, skips included.
    ///
    @Test
    def aMethodAnswerRendersAsAPlanAndStillSolves(): Unit \ Assert =
        let oll = Vector.get(3, Oll.all());
        let pll = Vector.get(2, Pll.all());
        let c = made("(${Pll.algorithm(pll)})' (${Oll.algorithm(oll)})'");
        match Method.lastLayer(SourceFirst, c) |> Result.flatMap(Method.planOf) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "planning")
            case Ok(p)  =>
                Assert.assertEqWithMsg(expected = 2, List.length(p#steps), "two steps");
                Assert.assertTrueWithMsg(
                    String.contains(substr = "OLL: ${Oll.name(oll)}", Plan.render(p)),
                    "the label should name the case:\n${Plan.render(p)}");
                match Cube.applyNotation(Plan.sequenceOf(p), c) {
                    case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "replaying")
                    case Ok(after) =>
                        Assert.assertTrueWithMsg(Cube.isSolved(after),
                            "the plan should solve the cube")
                }
        };
        // a skip becomes a labelled line with no moves
        match Method.lastLayer(SourceFirst, made("")) |> Result.flatMap(Method.planOf) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "planning a solved cube")
            case Ok(p)  =>
                Assert.assertTrue(List.isEmpty(Plan.ops(p)));
                Assert.assertTrueWithMsg(String.contains(substr = "OLL skip", Plan.render(p)),
                    "a skip should be visible:\n${Plan.render(p)}")
        }

}
