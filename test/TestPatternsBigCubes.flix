///
/// The 4x4x4 and 5x5x5 pattern catalogues.
///
/// Split from `TestPatterns`, which checks the 3x3x3 collection, because the
/// two share no helper and no corpus: the 3x3x3 tests work through identity up
/// to holding and the solver, while these two replay a recorded algorithm and
/// compare a facelet token. One module reaching into six library modules to do
/// both was coupling with nothing behind it.
///
/// Cheap, both of them -- a fifth of a second together. They are separate for
/// the coupling, not for the cost.
///
pub mod TestPatternsBigCubes {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Patterns

    /// The 4x4x4 catalogue has one record per token, and every row replays to it.
    @Test
    def fourByFourPatternsApplySoundly(): Unit \ Assert =
        let all = Patterns.Revenge.all();
        let ids = all |> Vector.map(Patterns.Revenge.canonical) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(ids),
            List.length(List.distinct(ids)),
            "two 4x4x4 entries describe the same state"
        );
        Vector.forEach(
            p -> {
                let res = Patterns.Revenge.cube(p);
                let name = Patterns.Revenge.name(p);
                Assert.assertTrueWithMsg(
                    Patterns.Revenge.url(Patterns.Revenge.source(p)) != "unknown",
                    "4x4 pattern '${name}' has no provenance URL"
                );
                match (res, Cube.solved(4)) {
                    case (Ok(c), Ok(solved)) =>
                        Assert.assertEqWithMsg(
                            expected = Ok(Patterns.Revenge.canonical(p)),
                            Facelets.token(c),
                            "4x4 pattern '${name}' does not reach its recorded state"
                        );
                        Assert.assertTrueWithMsg(
                            Facelets.token(c) != Facelets.token(solved),
                            "4x4 pattern '${name}' is the solved cube"
                        )
                    case (Err(why), _) =>
                        Assert.assertEqWithMsg(
                            expected = "",
                            why,
                            "4x4 pattern '${name}' failed to apply"
                        )
                    case (_, Err(why)) =>
                        Assert.assertEqWithMsg(
                            expected = "",
                            why,
                            "4x4 solved cube could not be built"
                        )
                }
            },
            all
        )

    /// The 5x5x5 catalogue has one record per token, and every row replays to it.
    @Test
    def fiveByFivePatternsApplySoundly(): Unit \ Assert =
        let all = Patterns.Professor.all();
        let ids = all |> Vector.map(Patterns.Professor.canonical) |> Vector.toList;
        Assert.assertEqWithMsg(
            expected = List.length(ids),
            List.length(List.distinct(ids)),
            "two 5x5x5 entries describe the same state"
        );
        Vector.forEach(
            p -> {
                let res = Patterns.Professor.cube(p);
                let name = Patterns.Professor.name(p);
                Assert.assertTrueWithMsg(
                    Patterns.Professor.url(Patterns.Professor.source(p)) != "unknown",
                    "5x5 pattern '${name}' has no provenance URL"
                );
                match (res, Cube.solved(5)) {
                    case (Ok(c), Ok(solved)) =>
                        Assert.assertEqWithMsg(
                            expected = Ok(Patterns.Professor.canonical(p)),
                            Facelets.token(c),
                            "5x5 pattern '${name}' does not reach its recorded state"
                        );
                        Assert.assertTrueWithMsg(
                            Facelets.token(c) != Facelets.token(solved),
                            "5x5 pattern '${name}' is the solved cube"
                        )
                    case (Err(why), _) =>
                        Assert.assertEqWithMsg(
                            expected = "",
                            why,
                            "5x5 pattern '${name}' failed to apply"
                        )
                    case (_, Err(why)) =>
                        Assert.assertEqWithMsg(
                            expected = "",
                            why,
                            "5x5 solved cube could not be built"
                        )
                }
            },
            all
        )
}
