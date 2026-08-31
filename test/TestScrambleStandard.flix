mod TestScrambleStandard {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized
    use CubeSolve.Model.Validate
    use CubeSolve.Scramble.Standard
    use CubeSolve.Solve.Standard.Tables

    /// Every table a 3x3x3 solve needs. Built once; the whole file shares it.
    def tables(): Tables \ Assert =
        match CubeSolve.Solve.Standard.buildTables() {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    /// A scramble must produce the state it reports, and that state must be one
    /// turning can reach.
    def assertSound(s: Standard.Scramble): Unit \ Assert =
        let built = Cube.solved(3)
            |> Result.flatMap(c -> Cube.applyAll(Standard.moves(s), c));
        Assert.assertEqWithMsg(
            expected = Ok(Cube.orbits(Sized.cubeOfStandard(Standard.state(s)))),
            built |> Result.map(Cube.orbits),
            "the scramble did not produce the state it reports");
        Assert.assertEqWithMsg(
            expected = None,
            Validate.faultOf(Sized.cubeOfStandard(Standard.state(s))),
            "the scramble produced an unreachable state")

    /// Everything the 3x3x3 scrambler must do, over one build of the tables.
    ///
    /// - **Uniform scrambles are sound**, and report bounds that bracket the
    ///   truth: the certified lower bound never exceeds the certified upper one.
    /// - **The bounds are honest about what they are.** The upper bound is a
    ///   real solution and so is exact as a *bound*; the lower bound comes from
    ///   the pruning tables and is weak by construction.
    /// - **`atMost` delivers what it promises**, certified by an actual
    ///   solution rather than by a claim.
    /// - **`atLeast` refuses what it cannot certify.** Its ceiling is 9,
    ///   because a pruning value cannot exceed its own table's maximum, and the
    ///   refusal says so rather than looping.
    /// - **Seeding is deterministic**, or no scramble could ever be reproduced.
    @Test
    def theStandardScramblerIsSoundCertifiedAndHonest(): Unit \ Assert + IO =
        if (Slow.skip("TestScrambleStandard.theStandardScramblerIsSoundCertifiedAndHonest",
                "certifies scrambles through the solver"))
            ()
        else {
            let t = tables();
            let budget = CubeSolve.Solve.Standard.fastBudget();

            // uniform
            def draw(i, seed, acc) =
                if (i <= 0) acc
                else match Standard.uniform(t, budget, seed) {
                    case Err(e) =>
                        Assert.assertEqWithMsg(expected = "", e, "uniform scramble");
                        acc
                    case Ok((s, next)) => draw(i - 1, next, s :: acc)
                };
            let drawn = draw(6, 31337i64, Nil);
            Assert.assertEq(expected = 6, List.length(drawn));
            drawn |> List.forEach(s -> {
                assertSound(s);
                Assert.assertEqWithMsg(
                    expected = Standard.atMostMoves(s), List.length(Standard.moves(s)),
                    "the upper bound should be the length of the solution that certified it");
                Assert.assertTrueWithMsg(
                    Standard.atLeastMoves(s) <= Standard.atMostMoves(s),
                    "the bounds cross: at least ${Standard.atLeastMoves(s)} but at most "
                        + "${Standard.atMostMoves(s)}");
                Assert.assertTrueWithMsg(
                    Standard.atLeastMoves(s) >= 0 and Standard.atLeastMoves(s) <= 9,
                    "the lower bound ${Standard.atLeastMoves(s)} is outside what the "
                        + "phase-one tables can certify")
            });

            // atMost
            match Standard.atMost(t, budget, 22, 99i64) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "atMost 22")
                case Ok((s, _)) =>
                    assertSound(s);
                    Assert.assertTrueWithMsg(
                        Standard.atMostMoves(s) <= 22,
                        "atMost(22) returned a scramble certified at "
                            + "${Standard.atMostMoves(s)}")
            };

            // atLeast, and its ceiling
            match Standard.atLeast(t, 7, 7i64) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "atLeast 7")
                case Ok((s, _)) =>
                    Assert.assertTrueWithMsg(
                        Standard.atLeastMoves(s) >= 7,
                        "atLeast(7) returned a scramble certified at only "
                            + "${Standard.atLeastMoves(s)}")
            };
            match Standard.atLeast(t, 10, 1i64) {
                case Ok(_)  => Assert.assertTrueWithMsg(false, "10 is above the ceiling")
                case Err(e) =>
                    Assert.assertTrueWithMsg(String.contains(substr = "9", e),
                        "the refusal should name the ceiling, but said: ${e}");
                    Assert.assertTrueWithMsg(String.contains(substr = "pruning", e),
                        "the refusal should say why the ceiling is where it is")
            };

            // determinism
            let once = Standard.uniform(t, budget, 2024i64)
                |> Result.map(match (s, _) -> Standard.show(s));
            let twice = Standard.uniform(t, budget, 2024i64)
                |> Result.map(match (s, _) -> Standard.show(s));
            Assert.assertEqWithMsg(
                expected = once, twice, "the same seed should give the same scramble")

    }
        }
