mod TestPocketScrambleUniform {

    use CubeSolve.Scramble.Pocket

    /// A uniform scramble is sound, and its difficulty follows the distribution
    /// rather than being fixed. Over 90% of states lie at distance 8, 9 or 10,
    /// so a handful of draws should land there.
    @Test
    def uniformScramblesAreSoundAndConcentrated(): Unit \ Assert =
        let t = PocketScrambleTestSupport.tables();
        def draw(i, seed, acc) =
            if (i <= 0) acc
            else match Pocket.uniform(t, seed) {
                case Err(_)        => acc
                case Ok((s, next)) => draw(i - 1, next, s :: acc)
            };
        let drawn = draw(25, 2026i64, Nil);
        Assert.assertEq(expected = 25, List.length(drawn));
        drawn |> List.forEach(PocketScrambleTestSupport.assertSound);
        let deep = drawn |> List.count(s -> Pocket.distance(s) >= 8);
        Assert.assertTrueWithMsg(deep >= 18,
            "over 90% of states lie at distance 8 or more, but only ${deep} of 25 did")

}
