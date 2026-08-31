///
/// Which sizes each command accepts, and what it says when it will not.
///
/// The command line asks three different questions of a size -- can this be
/// turned, solved, or looked up in the pattern corpora -- and they have three
/// different answers. Getting them confused is how `show` ends up refusing a
/// 4x4x4 it could draw perfectly well, which is what it did before this.
///
mod TestArgs {

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

        // 3x3 Orbit64 Token
        let resTok3 = Args.onCube(3, "AAAAAAAAAAf_" :: Nil, inspect);
        Assert.assertEq(expected = Ok("size=3,cubeSize=3"), resTok3);

        // 4x4 Orbit64 Token (auto-detected size 4 without --size)
        let resTok4 = Args.onCube(3, "AH0Hmo16YfPV7lTF3_VGkq_Ontg" :: Nil, inspect);
        Assert.assertEq(expected = Ok("size=4,cubeSize=4"), resTok4);

        // URL containing 5x5 token
        let url = "https://cubesolve.org/#FAMMxrnAODxtJQkle0CmnHZ3c8_Wiv8A78pj8T9iIN";
        let resUrl = Args.onCube(3, url :: Nil, inspect);
        Assert.assertEq(expected = Ok("size=5,cubeSize=5"), resUrl);

        // Empty input
        Assert.assertErr(Args.onCube(3, Nil, inspect))
    }

    /// Solving an unreachable cube state returns an Err with the reachability reason.
    @Test
    def unreachableTokenIsRejectedWhenSolving(): Unit \ {Assert, IO} = {
        let solving = (n, c) -> Engine.solveCube(Budgets.standard(), n, c);
        let res = Args.onCube(3, "AK-bRtpiQ000" :: Nil, solving);
        match res {
            case Ok(_) => Assert.assertTrueWithMsg(false, "unreachable cube should fail to solve")
            case Err(why) => Assert.assertTrue(String.contains(substr = "parity", why))
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
        Assert.assertEq(expected = Ok("exhaustive:0"),
            Args.withBudget("--budget" :: "exhaustive" :: Nil, echo));
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

}
