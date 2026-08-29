mod TestPatternBounds {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard

    /// The cube a pattern's published algorithm makes.
    def made(name: String, alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "${name}: '${alg}'");
                unreachable!()
        }

    /// How many moves `alg` is, when it is written in face turns.
    ///
    /// `Move.parse` accepts nothing else, so this is `None` exactly when the
    /// published algorithm leans on slice moves and therefore documents no
    /// half-turn count to compare against.
    def halfTurnLength(alg: String): Option[Int32] =
        Move.parse(alg) |> Result.toOption |> Option.map(List.length)

    ///
    /// The solver never needs more moves than the collection documents, and how
    /// it compares with the published algorithms.
    ///
    /// Two different bars, and the difference matters.
    ///
    /// **The gate** is the `htm` column: 110 structured states, each with a
    /// recorded half-turn move count, and the solver must not exceed any of
    /// them. Structured states are not random ones -- these are symmetric,
    /// hand-designed positions -- so this catches regressions the sixteen-sample
    /// random baseline would not.
    ///
    /// **The comparison** is against the published algorithms, and the solver
    /// loses some of them. That is expected rather than a defect: a pattern is
    /// designed, its algorithm is built to exploit the symmetry that makes it
    /// look good, and a two-phase solver reaches every state the same way --
    /// through the domino subgroup -- with no idea that this one is special.
    /// Measured at the default budget over the 102 patterns published in face
    /// turns:
    ///
    /// ```
    /// fast              37 of 102 longer than published
    /// default           32 of 102 longer, worst excess 7, solver total 1467
    /// thorough          31 of 102 longer,                 solver total 1456
    /// 6000 probes       28 of 102 longer,                 solver total 1441
    /// ```
    ///
    /// The worst is Tetris: published in 8 moves, solved in 15. More probes
    /// barely move it, because the gap is structural rather than a matter of
    /// search effort.
    ///
    @Test
    def theSolverStaysWithinTheDocumentedMoveCount(): Unit \ Assert =
        let t = match Standard.buildTables() {
            case Ok(x)  => x
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        };
        let budget = Standard.defaultBudget();

        let tally = PatternFixtures.all() |> Vector.foldLeft((acc, p) -> {
            let (comparable, longer, worst) = acc;
            let name = PatternFixtures.name(p);
            let documented = List.length(
                Move.parse(PatternFixtures.htm(p)) |> Result.getWithDefault(Nil));
            let cube = made(name, PatternFixtures.notation(p));
            match Sized.standardOf(cube)
                    |> Result.flatMap(s -> Standard.solutionWith(t, budget, s)) {
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e, "solving '${name}'");
                    acc
                case Ok(ms) =>
                    let got = List.length(ms);
                    // the gate
                    Assert.assertTrueWithMsg(got <= documented,
                        "'${name}' is documented at ${documented} moves but the "
                            + "solver took ${got}");
                    // and it really solves it
                    Assert.assertEqWithMsg(
                        expected = Ok(true),
                        Cube.applyAll(ms, cube) |> Result.map(Cube.isSolved),
                        "the solution for '${name}' did not solve it");
                    // the comparison, where the publication documents a count
                    match halfTurnLength(PatternFixtures.notation(p)) {
                        case None => acc
                        case Some(published) =>
                            if (got > published)
                                (comparable + 1, longer + 1, Int32.max(worst, got - published))
                            else
                                (comparable + 1, longer, worst)
                    }
            }
        }, (0, 0, 0));

        let (comparable, longer, worst) = tally;
        Assert.assertEqWithMsg(expected = 102, comparable,
            "102 of the patterns are published in face turns and so document a count");
        Assert.assertTrueWithMsg(longer <= 32,
            "the solver is longer than the published algorithm on ${longer} patterns, "
                + "up from the recorded 32");
        Assert.assertTrueWithMsg(worst <= 7,
            "the solver's worst excess over a published algorithm is ${worst} moves, "
                + "over the recorded 7")

}
