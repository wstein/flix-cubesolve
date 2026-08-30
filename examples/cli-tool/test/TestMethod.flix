///
/// The `pll` command's wiring.
///
/// The method itself is tested in the library, across all 21 cases and all four
/// approaches. What is left to check here is that the command reaches it, shows
/// the parts a person needs, and passes the method's refusals through rather
/// than replacing them with something vaguer.
///
mod TestMethod {

    use CubeSolve.Method.Profile
    use CubeSolve.Method.Profile.Profile.{SourceFirst, NoRotations}
    use CubeSolve.Model.Cube

    def made(size: Int32, alg: String): Cube.Cube \ Assert =
        match Cube.solved(size) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// A recognised case shows everything needed to act on it.
    ///
    /// The profile lines are part of that: which rule was asked for and what it
    /// selected, so a caller can see the answer was chosen rather than fixed.
    ///
    @Test
    def aRecognisedCaseShowsCaseAufAlgorithmAndProvenance(): Unit \ Assert =
        let tperm = made(3, "(R U R' U' R' F R2 U' R' U' R U R' F')'");
        match Method.pll(SourceFirst, tperm) {
            case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "a T-perm")
            case Ok(text) =>
                Vector#{"T-PLL", "setup", "algorithm", "finish", "sequence",
                        "optimal", "profile", "selected", "speedsolving.com"}
                    |> Vector.forEach(part ->
                        Assert.assertTrueWithMsg(String.contains(substr = part, text),
                            "the report should mention '${part}':\n${text}"))
        }

    ///
    /// The method's own refusals reach the caller unchanged.
    ///
    /// Each names a different fault, and flattening them into one message would
    /// lose the only thing that tells a person what to do next.
    ///
    @Test
    def refusalsArePassedThroughWithTheirReasons(): Unit \ Assert =
        let refused = (alg, expected) ->
            match Method.pll(SourceFirst, made(3, alg)) {
                case Ok(_)    => Assert.assertTrueWithMsg(false, "'${alg}' is not PLL")
                case Err(why) =>
                    Assert.assertTrueWithMsg(String.contains(substr = expected, why),
                        "'${alg}' should be refused for ${expected}, not: ${why}")
            };
        refused("R", "first two layers");
        refused("(R U R' U R U2 R')'", "not oriented")

    ///
    /// A size with no last layer to permute is refused by the method, not by
    /// the argument parser.
    ///
    /// `pll` is gated on turning rather than solving, so a 4x4x4 reaches the
    /// method and gets its specific answer instead of a general one about
    /// unsupported sizes.
    ///
    @Test
    def aSizeWithNoPllIsRefusedByTheMethod(): Unit \ Assert =
        match Method.pll(SourceFirst, made(4, "R U")) {
            case Ok(_)    => Assert.assertTrueWithMsg(false, "a 4x4x4 has no PLL step")
            case Err(why) =>
                // The wording comes from CubeSolve.Method.LastLayer, which both
                // steps share; what matters is that it names the size rather
                // than being the parser's general answer about sizes.
                Assert.assertTrueWithMsg(String.contains(substr = "4x4x4", why),
                    "the refusal should name the size it was given: ${why}");
                Assert.assertTrueWithMsg(String.contains(substr = "3x3x3", why),
                    "and the size the method is for: ${why}")
        }

    ///
    /// A profile reaches the method, and what it did is printed.
    ///
    @Test
    def theProfileAskedForIsReported(): Unit \ Assert =
        let tperm = made(3, "(R U R' U' R' F R2 U' R' U' R U R' F')'");
        match Method.pll(NoRotations, tperm) {
            case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "a T-perm")
            case Ok(text) =>
                Assert.assertTrueWithMsg(
                    String.contains(substr = "no-rotations", text),
                    "the profile asked for should be named:\n${text}");
                Assert.assertTrueWithMsg(String.contains(substr = "selected", text),
                    "what it selected should be reported:\n${text}")
        }

    ///
    /// A fallback is printed, not swallowed.
    ///
    /// It has to be an OLL case: every PLL case has a rotation-free algorithm
    /// recorded, so `no-rotations` never falls back there. Sixteen of the 57 OLL
    /// cases have none, and this is one -- every algorithm for it uses a wide
    /// turn, which is a rotation whatever it looks like.
    ///
    @Test
    def aFallbackIsPrintedRatherThanSwallowed(): Unit \ Assert =
        let lightning = made(3, "(r U R' U R U2 r')'");
        match Method.oll(NoRotations, lightning) {
            case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "wide sune")
            case Ok(text) =>
                Assert.assertTrueWithMsg(String.contains(substr = "default variant", text),
                    "a fallback should say it used the default:\n${text}");
                Assert.assertTrueWithMsg(
                    String.contains(substr = "no rotation-free variant", text),
                    "and say why:\n${text}")
        }

}
