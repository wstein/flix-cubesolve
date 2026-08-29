mod TestRandom {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Random
    use CubeSolve.Model.Validate
    use Orbit64.Coord.Coord.CornerCoord

    /// `count` cubes drawn in sequence from `seed`, each seeded by the last.
    def draw(n: Int32, count: Int32, seed: Int64): List[Cube.Cube] \ Assert =
        if (count <= 0) Nil
        else match Random.sampleDeterministic(seed, n) {
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected a sample");
                Nil
            case Ok((c, next)) => c :: draw(n, count - 1, next)
        }

    // ---------- determinism ----------

    /// The same seed gives the same cube, every time and on every machine.
    /// Every checked-in fixture depends on this.
    @Test
    def theSameSeedGivesTheSameCube(): Unit \ Assert =
        List.forEach(n ->
            Assert.assertEq(
                expected = Random.sampleDeterministic(20260828i64, n)
                    |> Result.flatMap(match (c, _) -> Facelets.token(c)),
                Random.sampleDeterministic(20260828i64, n)
                    |> Result.flatMap(match (c, _) -> Facelets.token(c))
            ),
            2 :: 3 :: Nil)

    /// The generator hands back the next seed, which is what keeps it pure and
    /// still threadable.
    @Test
    def theReturnedSeedAdvances(): Unit \ Assert =
        match Random.sampleDeterministic(7i64, 3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a sample")
            case Ok((_, next)) =>
                Assert.assertNeq(unexpected = 7i64, next);
                Assert.assertNeq(
                    unexpected = Random.sampleDeterministic(7i64, 3)
                        |> Result.flatMap(match (c, _) -> Facelets.token(c)),
                    Random.sampleDeterministic(next, 3)
                        |> Result.flatMap(match (c, _) -> Facelets.token(c))
                )
        }

    /// Distinct seeds give distinct cubes. A generator stuck on one value would
    /// pass every determinism test above.
    @Test
    def distinctSeedsGiveDistinctCubes(): Unit \ Assert =
        let tokens = draw(3, 40, 1i64) |> List.map(Facelets.token) |> List.distinct;
        Assert.assertTrueWithMsg(List.length(tokens) >= 38,
            "40 draws gave only ${List.length(tokens)} distinct cubes")

    // ---------- legality ----------

    /// Every sample is a state turning can reach. This is the property the
    /// whole rejection loop exists for.
    @Test
    def everySampleIsReachable(): Unit \ Assert =
        List.forEach(n ->
            draw(n, 60, 99i64) |> List.forEach(c ->
                Assert.assertEqWithMsg(expected = None, Validate.faultOf(c),
                    "sampled cube ${Facelets.token(c)} is not reachable")),
            2 :: 3 :: Nil)

    @Test
    def samplingRefusesSizesItCannotCertify(): Unit \ Assert =
        Assert.assertErr(Random.sampleDeterministic(1i64, 4));
        Assert.assertErr(Random.sampleDeterministic(1i64, 1))

    // ---------- spread ----------

    /// A marginal check, not a check of flatness over the whole state space --
    /// that is untestable at 4.3 x 10^19. Every value of one corner's twist
    /// should turn up, and roughly equally often.
    @Test
    def oneCoordinateIsSpreadAcrossItsValues(): Unit \ Assert =
        let twists = draw(3, 300, 5i64) |> List.filterMap(c ->
            match Cube.orbits(c) {
                case CornerCoord(_, t) :: _ => Some(Vector.get(0, t))
                case _                      => None
            });
        List.forEach(v -> {
            let seen = List.count(x -> x == v, twists);
            Assert.assertTrueWithMsg(seen > 60 and seen < 140,
                "twist ${v} appeared ${seen} times in 300 draws, expected about 100")
        }, 0 :: 1 :: 2 :: Nil)

    /// The bounded draw is uniform over its range and never escapes it.
    @Test
    def boundedDrawsStayInRangeAndCoverIt(): Unit \ Assert =
        def loop(i, s, acc) =
            if (i <= 0) acc
            else {
                let (v, next) = Random.nextBelow(5, s);
                Assert.assertTrueWithMsg(v >= 0 and v < 5, "draw ${v} escaped 0..4");
                loop(i - 1, next, v :: acc)
            };
        let drawn = loop(200, 42i64, Nil);
        List.forEach(v ->
            Assert.assertTrueWithMsg(List.memberOf(v, drawn), "value ${v} never drawn"),
            0 :: 1 :: 2 :: 3 :: 4 :: Nil)

    // ---------- the secure variant ----------

    /// The two generators differ in their effect, and that difference is the
    /// point: one is pure and reproducible, the other reads the platform's
    /// entropy source and carries IO.
    @Test
    def theSecureSamplerProducesAReachableCube(): Unit \ Assert + IO =
        match Random.sampleSecure(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a sample")
            case Ok(c)  => Assert.assertEq(expected = None, Validate.faultOf(c))
        }

}
