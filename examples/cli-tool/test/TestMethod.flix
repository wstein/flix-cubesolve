///
/// The `pll` command's wiring.
///
/// The method itself is tested in the library, across all 21 cases and all four
/// approaches. What is left to check here is that the command reaches it, shows
/// the parts a person needs, and passes the method's refusals through rather
/// than replacing them with something vaguer.
///
mod TestMethod {

    use CubeSolve.Model.Cube

    def made(size: Int32, alg: String): Cube.Cube \ Assert =
        match Cube.solved(size) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// A recognised case shows everything needed to act on it.
    ///
    /// The optimal length carries its caveat with it: without that line the
    /// number reads as a claim about the algorithm printed above it, which it
    /// is not.
    ///
    @Test
    def aRecognisedCaseShowsCaseAufAlgorithmAndProvenance(): Unit \ Assert =
        let tperm = made(3, "(R U R' U' R' F R2 U' R' U' R U R' F')'");
        match Method.pll(tperm) {
            case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "a T-perm")
            case Ok(text) =>
                Vector#{"T-PLL", "setup", "algorithm", "finish", "sequence",
                        "speed-oriented, not shortest", "speedsolving.com"}
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
            match Method.pll(made(3, alg)) {
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
        match Method.pll(made(4, "R U")) {
            case Ok(_)    => Assert.assertTrueWithMsg(false, "a 4x4x4 has no PLL step")
            case Err(why) =>
                Assert.assertTrueWithMsg(String.contains(substr = "3x3x3 step", why),
                    "the refusal should come from the method: ${why}")
        }

}
