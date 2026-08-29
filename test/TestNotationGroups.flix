///
/// Bracketed groups, repeat counts and postfix inverses.
///
/// Published algorithms are written this way as a matter of course, not as an
/// edge case: the speedsolving PLL pages are full of `(R U R' U')` for finger
/// grouping and `(M z)4` for repetition, and the two look alike while meaning
/// different things. Treating a bracket as decoration turns the second into the
/// first and loses the count without complaining, which is why this is grammar
/// and not a tidying pass.
///
mod TestNotationGroups {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation

    ///
    /// Two written forms reach the same cube.
    ///
    def sameCube(a: String, b: String): Bool \ Assert =
        let of = alg -> match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => Some(Cube.orbits(c))
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); None
        };
        of(a) == of(b)

    def agree(a: String, b: String): Unit \ Assert =
        Assert.assertTrueWithMsg(sameCube(a, b), "'${a}' should reach the same cube as '${b}'")

    ///
    /// A repeat count on a group is the group written that many times.
    ///
    /// These four are the ones that had to be expanded by hand to get the
    /// pattern corpus in, which is the clearest evidence they were missing.
    ///
    @Test
    def aCountedGroupIsTheGroupRepeated(): Unit \ Assert =
        agree("(M z)4", "M z M z M z M z");
        agree("(L2 F2 R2 B2)3", "L2 F2 R2 B2 L2 F2 R2 B2 L2 F2 R2 B2");
        agree("(M2 U2)2 z (M2 U2)2", "M2 U2 M2 U2 z M2 U2 M2 U2");
        agree("((M' U)4 x' z)3",
            "M' U M' U M' U M' U x' z M' U M' U M' U M' U x' z "
                + "M' U M' U M' U M' U x' z")

    ///
    /// Nested groups, and a count on a group that already contains one.
    ///
    @Test
    def groupsNest(): Unit \ Assert =
        agree("((R U)2 F')2", "R U R U F' R U R U F'");
        agree("(R (U R')2)", "R U R' U R'");
        agree("((R)2)2", "R2 R2")

    ///
    /// Brackets with no count change nothing at all.
    ///
    /// The common case in published algorithms: they mark where a hand
    /// regrips, and the cube cannot tell.
    ///
    @Test
    def bracketsWithoutACountAreOnlyGrouping(): Unit \ Assert =
        agree("(R U R' U') R' F R2 U' R' U' R U R' F'",
            "R U R' U' R' F R2 U' R' U' R U R' F'");
        agree("(R U R' U')", "R U R' U'");
        agree("(y) R U R' U'", "y R U R' U'")

    ///
    /// A prime after a count inverts what the count produced.
    ///
    /// `R2'` is the inverse of `R2`, which is `R2` again -- a half turn is its
    /// own inverse. That it comes out the same is the point: the notation is
    /// redundant, not wrong, and refusing it would reject real algorithms.
    ///
    @Test
    def aPrimeAfterACountInvertsTheWhole(): Unit \ Assert =
        agree("R2'", "R2");
        agree("R2'", "R R");
        agree("y2'", "y2");
        agree("(R U)'", "U' R'");
        agree("(R U)2'", "U' R' U' R'");
        // and either written order means the same thing
        agree("R'2", "R2'")

    ///
    /// Inverting a group restores the frame as well as the pieces.
    ///
    /// A layer turn is named in whatever frame is current when it runs, so an
    /// inverse that did not put the frame back would undo the right pieces
    /// under the wrong names. A sequence followed by its own inverse is the
    /// identity, and that is what checks it.
    ///
    @Test
    def invertingAGroupWithRotationsIsItsUndo(): Unit \ Assert =
        Vector#{"(y R U' M x)", "(M' U)4 x' z", "(r U R' F) (y2)", "(R U R' U')2"}
            |> Vector.forEach(alg ->
                Assert.assertTrueWithMsg(
                    sameCube("${alg} (${alg})'", ""),
                    "'${alg}' followed by its inverse should solve"))

    ///
    /// Malformed writing is refused, and the refusal says which fault it is.
    ///
    @Test
    def malformedNotationIsRefusedByName(): Unit \ Assert =
        let refusedWith = (alg, expected) ->
            match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
                case Ok(_)    => Assert.assertTrueWithMsg(false, "'${alg}' should be refused")
                case Err(why) =>
                    Assert.assertTrueWithMsg(String.contains(substr = expected, why),
                        "'${alg}' should be refused for ${expected}, not: ${why}")
            };
        refusedWith("(R U", "unmatched '('");
        refusedWith("R U)", "unmatched ')'");
        refusedWith("()", "empty");
        refusedWith("(R U)0", "at least 1");
        refusedWith("(R U)999", "beyond");
        refusedWith("2 R", "stands on its own");
        refusedWith("' R", "stands on its own");
        // Whitespace does not end a suffix, so this is one move with two
        // counts rather than a move and a stray number. Either way it is
        // refused; the message says which reading it took.
        refusedWith("R2 3", "two repeat counts");
        refusedWith("R''", "inverted twice");
        refusedWith("R2 2", "two repeat counts");
        refusedWith("R $ U", "no meaning")

    ///
    /// Real published algorithms parse, with their brackets and rotations
    /// exactly as written.
    ///
    /// A small provenance-labelled sample rather than the whole database: the
    /// grammar is what is under test, so the fixtures are chosen for the shapes
    /// they contain -- groups, rotations, wide turns, slice moves and counted
    /// inverses -- not for coverage of the cases.
    ///
    /// Source: <https://www.speedsolving.com/wiki/index.php?title=PLL>,
    /// retrieved 2026-08-30. Each is a published PLL algorithm; the third and
    /// fourth are listed as optimal rather than speed-oriented, which is the
    /// distinction that page draws throughout.
    ///
    @Test
    def publishedAlgorithmsParseAsWritten(): Unit \ Assert =
        Vector#{
            ("T-PLL, speed", "(R U R' U') R' F R2 U' R' U' R U R' F'"),
            ("F-PLL, speed", "(y) R' U' F' (R U R' U') R' F R2 (U' R' U') R U R' U R"),
            ("F-PLL, speed, wide", "M' U2 L F' R U2 r' U r' R2 U2 R2"),
            ("F-PLL, optimal HTM 13", "(y) R2 B2 R2 L U' L F2 R' D L' F2 R L'"),
            ("Ga-PLL, optimal HTM 12", "(y) F B U2 F' B' L' U R' U2 L U' R"),
            ("Ga-PLL, speed, counted", "(y) R2' u (R' U R' U' R) u' R2 (y') R' U R"),
            ("Gb-PLL, speed", "(y2) L' U' L (y') R2' u (R' U R U' R) u' R2")
        } |> Vector.forEach(match (name, alg) ->
            match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
                case Ok(_)  => ()
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "${name}: '${alg}'")
            })

}
