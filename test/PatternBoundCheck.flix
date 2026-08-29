///
/// The shared check behind the two pattern-bound gates.
///
/// Solving a pattern is the most expensive thing this suite does -- 110 of them
/// is roughly half the total runtime -- so the check is run two ways: over a
/// named subset on every commit, and over the whole collection when asked for.
/// `TestPatternBoundsFast` and `TestPatternBoundsExhaustive` are those two, and
/// the logic they share lives here so neither can drift from the other.
///
mod PatternBoundCheck {

    use CubeSolve.Patterns
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard

    ///
    /// The patterns the fast gate covers.
    ///
    /// Chosen by the rules below rather than by taste or by sampling, so the
    /// list can be rebuilt and argued with. Each rule is its own definition,
    /// because a rule stated in code is harder to quietly abandon than one
    /// stated in a comment.
    ///
    /// Twenty-seven patterns spanning 4 to 22 moves, all three sources and every
    /// published-length band. This is a stratification, not a sample: nothing is
    /// random and nothing is quietly dropped -- `TestPatternBoundsExhaustive`
    /// runs the other 83.
    ///
    pub def stratum(): Vector[String] =
        Vector.flatten(Vector#{
            namedHardCases(),
            worstAgainstPublication(),
            atThePublishedBound(),
            sourceCoverage(),
            publishedWithSliceMoves(),
            extremesOfLength()
        })
            |> Vector.toList |> List.distinct |> List.toVector

    ///
    /// The two patterns named as hard cases.
    ///
    /// Superflip is the deepest state on a 3x3x3 and fully symmetric, so all six
    /// of the solver's views of it are the same cube. Tetris is where the solver
    /// loses to its publication by the widest margin, 8 moves against 15.
    ///
    def namedHardCases(): Vector[String] = Vector#{
        "Superflip",
        "Tetris"
    }

    ///
    /// Every pattern the solver loses to its publication by four moves or more.
    ///
    /// Not a sample of them -- all of them. These have the least headroom, so a
    /// regression shows here before anywhere else.
    ///
    def worstAgainstPublication(): Vector[String] = Vector#{
        "Green mamba",
        "Pyraminx",
        "Spiral pattern",
        "Black mamba",
        "Python",
        "Twisted chicken feet",
        "Twisted rings",
        "Vertical stripes"
    }

    ///
    /// Two per published-length band, from those the solver matches exactly.
    ///
    /// Bands are eight moves or fewer, 9 to 12, 13 to 16, 17 to 20, and 21 and
    /// over. A pattern the solver matches exactly has no slack at all: one move
    /// worse and it fails.
    ///
    def atThePublishedBound(): Vector[String] = Vector#{
        "Hi Ohio",
        "Hi all around",
        "\"Plus\"",
        "4 T",
        "Cube in the cube",
        "Weirdo",
        "Checkerboard in the cube",
        "Displaced Motif",
        "( ! ) (ˆ⌣ˆԅ)"
    }

    ///
    /// Two per source, so no collection goes unchecked.
    ///
    def sourceCoverage(): Vector[String] = Vector#{
        "4-Spot",
        "6-Spot",
        "3 sides solved",
        "3C3W",
        "3T",
        "4 crosses (second list)"
    }

    ///
    /// Patterns published with slice moves.
    ///
    /// These reach the solver by a different path than face turns do -- the
    /// notation rotates the frame -- and they document no half-turn count, so
    /// they exercise the gate rather than the comparison.
    ///
    def publishedWithSliceMoves(): Vector[String] = Vector#{
        "Don't cross line"
    }

    ///
    /// The shortest and longest documented solutions.
    ///
    def extremesOfLength(): Vector[String] = Vector#{
        "The pillars"
    }

    ///
    /// Check every pattern in `only`, or all of them when `only` is empty.
    ///
    /// Two bars at once. The **gate** is the collection's own documented
    /// half-turn count, which the solver must not exceed and which is checked
    /// per pattern. The **comparison** is against the published algorithm,
    /// tallied and returned for the caller to bound, because the solver loses
    /// some of those and that is expected rather than a defect.
    ///
    /// Every solution is replayed, so a length that matched without solving
    /// would fail here rather than pass quietly.
    ///
    /// Returns how many patterns documented a published half-turn count, how
    /// many of those the solver took longer on, and the worst excess.
    ///
    pub def check(
        t: Standard.Tables,
        budget: Standard.Budget,
        only: Vector[String]
    ): (Int32, Int32, Int32) \ Assert =
        let wanted = p ->
            Vector.isEmpty(only) or Vector.memberOf(Patterns.Standard.name(p), only);
        Patterns.Standard.all() |> Vector.filter(wanted) |> Vector.foldLeft((acc, p) -> {
            let (comparable, longer, worst) = acc;
            let name = Patterns.Standard.name(p);
            let documented = List.length(
                Move.parse(Patterns.Standard.faceTurns(p)) |> Result.getWithDefault(Nil));
            let cube = made(name, Patterns.Standard.notation(p));
            match Sized.standardOf(cube)
                    |> Result.flatMap(s -> Standard.solutionWith(t, budget, s)) {
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e, "solving '${name}'");
                    acc
                case Ok(ms) =>
                    let got = List.length(ms);
                    Assert.assertTrueWithMsg(got <= documented,
                        "'${name}' is documented at ${documented} moves but the "
                            + "solver took ${got}");
                    Assert.assertEqWithMsg(
                        expected = Ok(true),
                        Cube.applyAll(ms, cube) |> Result.map(Cube.isSolved),
                        "the solution for '${name}' did not solve it");
                    match Move.parse(Patterns.Standard.notation(p)) {
                        case Err(_) => acc
                        case Ok(published) =>
                            let want = List.length(published);
                            if (got > want)
                                (comparable + 1, longer + 1, Int32.max(worst, got - want))
                            else
                                (comparable + 1, longer, worst)
                    }
            }
        }, (0, 0, 0))

    ///
    /// Every table a 3x3x3 solve needs.
    ///
    pub def tables(): Standard.Tables \ Assert =
        match Standard.buildTables() {
            case Ok(x)  => x
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    ///
    /// The cube a pattern's published algorithm makes.
    ///
    def made(name: String, alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "${name}: '${alg}'");
                unreachable!()
        }

}
