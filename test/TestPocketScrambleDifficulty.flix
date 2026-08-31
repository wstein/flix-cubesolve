mod TestPocketScrambleDifficulty {

    use CubeSolve.Scramble.Pocket

    /// Everything about exact-difficulty sampling, over one build of the tables
    /// and one sweep for the index.
    ///
    /// Kept as one test for cost rather than taste: building the tables and
    /// indexing the sparse classes takes seconds, and paying it five times to
    /// gain five test names is a bad trade in a gate that runs on every commit.
    /// Each assertion names what it is checking.
    ///
    /// - **Every class gives exactly the length asked for**, across all twelve.
    /// - **Distance zero is the solved state.**
    /// - **Beyond the diameter is refused by name.**
    /// - **The index covers exactly the sparse classes**, completely.
    /// - **Sampling within a class is uniform**, checked where it can be seen.
    @Test
    def exactDifficultySamplingIsExactUniformAndComplete(): Unit \ Assert + IO =
        let testName = "TestPocketScrambleDifficulty." +
            "exactDifficultySamplingIsExactUniformAndComplete";
        if (Slow.skip(testName,
                "enumerates the 2x2x2 distance classes"))
            ()
        else {
            let t = PocketScrambleTestSupport.tables();
            let ix = Pocket.indexOf(t);
            Vector.range(0, Pocket.diameter() + 1) |> Vector.forEach(d ->
                match Pocket.atDistance(t, ix, d, 1000i64 + Int32.toInt64(d)) {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e, "distance ${d}")
                    case Ok((s, _)) =>
                        Assert.assertEqWithMsg(expected = d, Pocket.distance(s),
                            "asked for distance ${d} and got ${Pocket.distance(s)}");
                        Assert.assertEqWithMsg(expected = d, List.length(Pocket.moves(s)),
                            "distance ${d} should give ${d} moves");
                        PocketScrambleTestSupport.assertSound(s)
                });

            match Pocket.atDistance(t, ix, 0, 5i64) {
                case Err(e)     => Assert.assertEqWithMsg(expected = "", e, "distance 0")
                case Ok((s, _)) =>
                    Assert.assertEq(expected = Nil, Pocket.moves(s));
                    Assert.assertTrue(PocketScrambleTestSupport.isSolved(s))
            };

            match Pocket.atDistance(t, ix, 12, 1i64) {
                case Ok(_)  => Assert.assertTrueWithMsg(false, "no state is 12 moves away")
                case Err(e) => Assert.assertTrueWithMsg(String.contains(substr = "11", e),
                    "the refusal should name the diameter, but said: ${e}")
            };
            Assert.assertErr(Pocket.atDistance(t, ix, -1, 1i64));

            let sizes = Vector#{1, 9, 54, 321, 1847, 9992, 50136, 0, 0, 0, 0, 2644};
            Vector.range(0, 12) |> Vector.forEach(d ->
                Assert.assertEqWithMsg(expected = Vector.get(d, sizes),
                    Vector.length(Pocket.statesAt(ix, d)), "the index at distance ${d}"));
            let indexed = Vector.range(0, 12)
                |> Vector.map(d -> Vector.length(Pocket.statesAt(ix, d)))
                |> Vector.sum;
            Assert.assertEqWithMsg(expected = 65004, indexed,
                "the sparse classes hold 65,004 states between them");

            def draw(i, seed, seen) =
                if (i <= 0) seen
                else match Pocket.atDistance(t, ix, 1, seed) {
                    case Err(_)        => seen
                    case Ok((s, next)) => draw(i - 1, next, Pocket.show(s) :: seen)
                };
            let distinct = draw(300, 77i64, Nil) |> List.distinct;
            Assert.assertEqWithMsg(expected = 9, List.length(distinct),
                "300 draws at distance 1 reached ${List.length(distinct)} of the 9 states")
        }

}
