///
/// Which sizes each command accepts, and what it says when it will not.
///
/// The command line asks three different questions of a size -- can this be
/// turned, solved, or looked up in the pattern corpora -- and they have three
/// different answers. Getting them confused is how `show` ends up refusing a
/// 4x4x4 it could draw perfectly well, which is what it did before this.
///
mod TestArgs {

    use cubesolve::CubeSolve

    use Args.Needs.{Turning, Solving, Corpus}

    ///
    /// `show` renders every size the model can turn, including the two it
    /// cannot solve.
    ///
    @Test
    def drawingAcceptsEverySizeTheModelCanTurn(): Unit \ Assert =
        CubeSolve.turnableSizes() |> Vector.forEach(n ->
            Assert.assertEqWithMsg(expected = None, Args.refusal(Turning, n),
                "a ${n}x${n}x${n} can be turned, so it can be drawn"));
        Assert.assertTrueWithMsg(Option.isEmpty(Args.refusal(Turning, 4)),
            "a 4x4x4 should be drawable");
        Assert.assertTrueWithMsg(Option.isEmpty(Args.refusal(Turning, 5)),
            "a 5x5x5 should be drawable")

    ///
    /// Solving refuses the sizes with no solver, and says that is what is
    /// missing rather than implying the cube itself is unknown.
    ///
    /// The distinction matters to whoever reads it: "there is no solver for it
    /// yet" is a different message from "this engine does not know that size",
    /// and only one of them is true of a 4x4x4.
    ///
    @Test
    def solvingRefusesTheSizesWithNoSolverAndSaysWhy(): Unit \ Assert =
        CubeSolve.supportedSizes() |> Vector.forEach(n ->
            Assert.assertEqWithMsg(expected = None, Args.refusal(Solving, n),
                "a ${n}x${n}x${n} is solvable"));
        Vector#{4, 5} |> Vector.forEach(n ->
            match Args.refusal(Solving, n) {
                case None      =>
                    Assert.assertTrueWithMsg(false,
                        "a ${n}x${n}x${n} cannot be solved and should be refused")
                case Some(why) =>
                    Assert.assertTrueWithMsg(String.contains(substr = "not solved", why),
                        "the refusal should name the missing solver: ${why}");
                    Assert.assertTrueWithMsg(String.contains(substr = "turned", why),
                        "and should say the cube itself is fine: ${why}")
            });
        // A size the model cannot even turn is refused differently, because
        // nothing about it works rather than one capability being absent.
        match Args.refusal(Solving, 7) {
            case None      => Assert.assertTrueWithMsg(false, "a 7x7x7 is not solvable")
            case Some(why) =>
                Assert.assertFalse(String.contains(substr = "turned and drawn", why))
        }

    ///
    /// Pattern lookup refuses the sizes with no collection, naming the corpus.
    ///
    @Test
    def patternLookupRefusesTheSizesWithNoCollection(): Unit \ Assert =
        Vector#{2, 3} |> Vector.forEach(n ->
            Assert.assertEqWithMsg(expected = None, Args.refusal(Corpus, n),
                "there is a collection for the ${n}x${n}x${n}"));
        Vector#{4, 5} |> Vector.forEach(n ->
            match Args.refusal(Corpus, n) {
                case None      =>
                    Assert.assertTrueWithMsg(false,
                        "there is no ${n}x${n}x${n} collection")
                case Some(why) =>
                    Assert.assertTrueWithMsg(String.contains(substr = "pattern", why),
                        "the refusal should name the missing collection: ${why}")
            })

    ///
    /// `--size` reaches the command, and a size it will not take is refused
    /// before the command runs at all.
    ///
    @Test
    def theSizeFlagIsReadAndCheckedBeforeTheCommandRuns(): Unit \ Assert =
        let echo = (n, _rest) -> Ok("size ${n}");
        Assert.assertEq(expected = Ok("size 4"),
            Args.withSize("--size" :: "4" :: Nil, Turning, echo));
        Assert.assertEq(expected = Ok("size 3"), Args.withSize(Nil, Solving, echo));
        Assert.assertErr(Args.withSize("--size" :: "4" :: Nil, Solving, echo));
        Assert.assertErr(Args.withSize("--size" :: "banana" :: Nil, Turning, echo))

    ///
    /// onCube parses move notation, tokens, and URLs, autodetecting the size where appropriate.
    ///
    @Test
    def onCubeAutodetectsNotationTokensAndUrls(): Unit \ Assert = {
        let inspect = (size, c) -> Ok("size=${size},cubeSize=${CubeSolve.Model.Cube.size(c)}");

        // Notation
        let resNot = Args.onCube(3, "R" :: "U" :: "R'" :: "U'" :: Nil, inspect);
        Assert.assertEq(expected = Ok("size=3,cubeSize=3"), resNot);

        // Tokens come from the library, so the test follows the V2 lengths
        // rather than a string frozen from the previous format.
        let resTok3 = Args.onCube(3, solvedToken(3) :: Nil, inspect);
        Assert.assertEq(expected = Ok("size=3,cubeSize=3"), resTok3);

        // 4x4 token (auto-detected size 4 without --size)
        let resTok4 = Args.onCube(3, solvedToken(4) :: Nil, inspect);
        Assert.assertEq(expected = Ok("size=4,cubeSize=4"), resTok4);

        // URL containing a 5x5 token
        let url = "https://cubesolve.org/#${solvedToken(5)}";
        let resUrl = Args.onCube(3, url :: Nil, inspect);
        Assert.assertEq(expected = Ok("size=5,cubeSize=5"), resUrl);

        // Empty input
        Assert.assertErr(Args.onCube(3, Nil, inspect))
    }

    /// A solved cube's V2 color token, in the pose the engine writes.
    def solvedToken(n: Int32): String =
        CubeSolve.Model.Cube.solved(n)
            |> Result.flatMap(CubeSolve.Model.Facelets.token)
            |> Result.getWithDefault("")

    /// Solving a cube whose corner and edge permutations have opposite parity
    /// returns that reason. A V2 token cannot carry the state: the codec
    /// refuses it, so the cube is built from its orbits.
    @Test
    def unreachableCubeIsRejectedWhenSolving(): Unit \ {Assert, IO} =
        let corners = CubeSolve.Model.Pieces.Coord.CornerCoord(
            Vector#{1, 0, 2, 3, 4, 5, 6, 7},
            Vector#{0, 0, 0, 0, 0, 0, 0, 0}
        );
        let edges = CubeSolve.Model.Pieces.Coord.MidgeCoord(
            Vector#{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
            Vector#{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        );
        match CubeSolve.Model.Cube.ofOrbits(3, corners :: edges :: Nil) {
            case Err(why) =>
                Assert.assertTrueWithMsg(false, "the swapped-corner cube is a legal coordinate: ${why}")
            case Ok(c) =>
                match Engine.solveCube(Budgets.standard(), 3, c) {
                    case Ok(_) =>
                        Assert.assertTrueWithMsg(false, "unreachable cube should fail to solve")
                    case Err(why) =>
                        Assert.assertTrue(String.contains(substr = "parity", why))
                }
        }

    /// `--budget` is read, defaults to `default`, and refuses an unknown name.
    ///
    /// The refusal matters as much as the parse: a caller who misspells a budget
    /// and is quietly given another gets a different answer with no way to see
    /// why, which is the failure `--profile` was given the same treatment for.
    @Test
    def budgetIsReadAndAnUnknownOneIsRefused(): Unit \ Assert = {
        let echo = (b, rest) -> Ok("${Budgets.nameOf(b)}:${List.length(rest)}");
        Assert.assertEq(expected = Ok("deep:1"),
            Args.withBudget("--budget" :: "deep" :: "R" :: Nil, echo));
        Assert.assertEq(expected = Ok("deep:1"),
            Args.withBudget("R" :: "--budget" :: "deep" :: Nil, echo));
        Assert.assertEq(expected = Ok("deep:1"),
            Args.withBudget("R" :: "--budget=deep" :: Nil, echo));
        Assert.assertEq(expected = Ok("default:1"),
            Args.withBudget("R" :: Nil, echo));
        Assert.assertEq(expected = Ok("max:0"),
            Args.withBudget("--budget" :: "max" :: Nil, echo));
        match Args.withBudget("--budget" :: "fastest" :: Nil, echo) {
            case Ok(_)    => Assert.assertTrueWithMsg(false, "'fastest' is not a budget")
            case Err(why) =>
                Assert.assertTrueWithMsg(String.contains(substr = "fast, default", why),
                    "the refusal should list the real ones: ${why}")
        };
        // every name round-trips
        Budgets.all() |> Vector.forEach(b ->
            Assert.assertEqWithMsg(expected = Some(b), Budgets.ofName(Budgets.nameOf(b)),
                "${Budgets.nameOf(b)} should round-trip"))
    }

    /// `--no-net` is parsed for the solve command.
    @Test
    def noNetOptionIsParsed(): Unit \ Assert = {
        match Options.parse("solve", "--no-net" :: "R" :: Nil) {
            case Ok(r) =>
                Assert.assertTrue(Options.has(r#flags, Options.Flag.NoNet));
                Assert.assertEq(expected = "R" :: Nil, r#operands)
            case Err(why) =>
                Assert.assertTrueWithMsg(false, "failed to parse --no-net: ${why}")
        }
    }

}
