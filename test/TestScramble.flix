mod TestScramble {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized
    use CubeSolve.Model.Validate
    use CubeSolve.Scramble.Pocket
    use CubeSolve.Table

    def tables(): CubeSolve.Table.Pocket.Tables \ Assert =
        match CubeSolve.Table.Pocket.build() {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    /// A scramble must actually produce the state it claims, and that state must
    /// be one turning can reach.
    def assertSound(s: Pocket.Scramble): Unit \ Assert =
        let apply = c -> Cube.applyAll(Pocket.moves(s), c);
        let built = Cube.solved(2) |> Result.flatMap(apply);
        Assert.assertEqWithMsg(
            expected = Ok(Cube.orbits(Sized.cubeOfPocket(Pocket.state(s)))),
            built |> Result.map(Cube.orbits),
            "the scramble '${Pocket.show(s)}' did not produce the state it reports");
        Assert.assertEqWithMsg(
            expected = None, Validate.faultOf(Sized.cubeOfPocket(Pocket.state(s))),
            "the scramble '${Pocket.show(s)}' produced an unreachable state")

    // ---------- exact difficulty ----------

    /// Everything about exact-difficulty sampling, over one build of the tables
    /// and one sweep for the index.
    ///
    /// Kept as one test for cost rather than taste: building the tables and
    /// indexing the sparse classes takes seconds, and paying it five times to
    /// gain five test names is a bad trade in a gate that runs on every commit.
    /// Each assertion names what it is checking.
    ///
    /// - **Every class gives exactly the length asked for**, across all twelve,
    ///   which exercises both sampling paths -- the indexed sparse classes and
    ///   the four dense ones left to rejection. The two must be
    ///   indistinguishable in their result and differ only in cost.
    /// - **Distance zero is the solved state**, the degenerate case a rejection
    ///   sampler would spend 3,674,160 draws on and the index answers at once.
    /// - **Beyond the diameter is refused by name.**
    /// - **The index covers exactly the sparse classes**, completely: 65,004
    ///   states rather than 3,674,160, which is the whole reason it exists.
    /// - **Sampling within a class is uniform**, checked where it can be seen:
    ///   distance 1 has nine states and a few hundred draws should reach them
    ///   all.
    @Test
    def exactDifficultySamplingIsExactUniformAndComplete(): Unit \ Assert =
        let t = tables();
        let ix = Pocket.indexOf(t);

        Vector.range(0, Pocket.diameter() + 1) |> Vector.forEach(d ->
            match Pocket.atDistance(t, ix, d, 1000i64 + Int32.toInt64(d)) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "distance ${d}")
                case Ok((s, _)) =>
                    Assert.assertEqWithMsg(
                        expected = d, Pocket.distance(s),
                        "asked for distance ${d} and got ${Pocket.distance(s)}");
                    Assert.assertEqWithMsg(
                        expected = d, List.length(Pocket.moves(s)),
                        "distance ${d} should give ${d} moves");
                    assertSound(s)
            });

        match Pocket.atDistance(t, ix, 0, 5i64) {
            case Err(e)     => Assert.assertEqWithMsg(expected = "", e, "distance 0")
            case Ok((s, _)) =>
                Assert.assertEq(expected = Nil, Pocket.moves(s));
                Assert.assertTrue(Cube.isSolved(Sized.cubeOfPocket(Pocket.state(s))))
        };

        match Pocket.atDistance(t, ix, 12, 1i64) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "no state is 12 moves away")
            case Err(e) => Assert.assertTrueWithMsg(
                String.contains(substr = "11", e),
                "the refusal should name the diameter, but said: ${e}")
        };
        Assert.assertErr(Pocket.atDistance(t, ix, -1, 1i64));

        let sizes = Vector#{1, 9, 54, 321, 1847, 9992, 50136, 0, 0, 0, 0, 2644};
        Vector.range(0, 12) |> Vector.forEach(d ->
            Assert.assertEqWithMsg(
                expected = Vector.get(d, sizes),
                Vector.length(Pocket.statesAt(ix, d)),
                "the index at distance ${d}"));
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

    // ---------- uniform ----------

    /// A uniform scramble is sound, and its difficulty follows the distribution
    /// rather than being fixed. Over 90% of states lie at distance 8, 9 or 10,
    /// so a handful of draws should land there.
    @Test
    def uniformScramblesAreSoundAndConcentrated(): Unit \ Assert =
        let t = tables();
        def draw(i, seed, acc) =
            if (i <= 0) acc
            else match Pocket.uniform(t, seed) {
                case Err(_)        => acc
                case Ok((s, next)) => draw(i - 1, next, s :: acc)
            };
        let drawn = draw(25, 2026i64, Nil);
        Assert.assertEq(expected = 25, List.length(drawn));
        drawn |> List.forEach(assertSound);
        let deep = drawn |> List.count(s -> Pocket.distance(s) >= 8);
        Assert.assertTrueWithMsg(deep >= 18,
            "over 90% of states lie at distance 8 or more, but only ${deep} of 25 did")

}
