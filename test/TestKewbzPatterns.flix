mod TestKewbzPatterns {

    use CubeSolve.Model.Facelets
    use CubeSolve.Patterns.Kewbz

    /// Each recorded source variant replays to its own state token. This checks
    /// the notation and fixture independently: a token that merely looks like
    /// an Orbit64 token cannot pass unless the published algorithm reaches it.
    @Test
    def everyKewbzVariantReplaysToItsRecordedState(): Unit \ Assert =
        let all = Kewbz.all();
        Assert.assertEq(expected = 36, Vector.length(all));
        Vector.forEach(p -> {
            let name = Kewbz.name(p);
            Assert.assertTrueWithMsg(Kewbz.url(p) != "unknown",
                "'${name}' has no provenance URL");
            match Kewbz.cube(p) |> Result.flatMap(Facelets.token) {
                case Ok(token) => Assert.assertEqWithMsg(expected = Kewbz.canonical(p), token,
                    "'${name}' does not reach its recorded state")
                case Err(why) => Assert.assertEqWithMsg(expected = "", why,
                    "'${name}' does not apply")
            }
        }, all)

    /// Variants identify their source pages instead of inheriting provenance
    /// from a similarly named pattern in another collection.
    @Test
    def everyKewbzVariantNamesItsExactSourcePage(): Unit \ Assert =
        Kewbz.all() |> Vector.forEach(p -> {
            let s = Kewbz.source(p);
            let validSource = s == "kewbz3" or s == "kewbz4" or s == "kewbz5";
            Assert.assertTrueWithMsg(validSource,
                "'${Kewbz.name(p)}' has an unexpected source '${s}'")
        })

}
