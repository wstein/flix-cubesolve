///
/// The layer-by-layer ladder.
///
/// The ladder is what every later step will be checked against, so its own
/// properties have to hold first: that it is monotone, that it agrees with the
/// predicates the other methods already use, and that it is not satisfied by
/// accident.
///
mod TestBeginner {

    use CubeSolve.Method.Beginner
    use CubeSolve.Method.Beginner.Stage.{Nothing, Cross, FirstLayer, TwoLayers,
        TopCross, TopEdgesPlaced, TopCornersPlaced, Solved}
    use CubeSolve.Method.LastLayer
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Random

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// Each stage includes the one before it, on every cube tried.
    ///
    /// Monotonicity is what `reached` relies on and what makes a stage a
    /// milestone rather than a coincidence. Checked over a fixed sample of
    /// random states and over cubes built to sit at each rung.
    ///
    @Test
    def theLadderIsMonotone(): Unit \ Assert =
        let cubes = Vector.append(
            Vector#{made(""), made("R"), made("U"), made("R U R' U'"),
                made("(R U R' U' R' F R2 U' R' U' R U R' F')'"),
                made("(r U R' U R U2 r')'")},
            Vector.range(0, 24) |> Vector.map(i ->
                match Random.sampleDeterministic(Int32.toInt64(i) + 51000i64, 3)
                    |> Result.map(fst) {
                    case Ok(c)  => c
                    case Err(_) => made("")
                }));
        cubes |> Vector.forEach(c ->
            Beginner.ladder() |> List.forEach(s ->
                if (Beginner.isComplete(s, c))
                    Beginner.ladder() |> List.forEach(earlier ->
                        if (earlier <= s)
                            Assert.assertTrueWithMsg(Beginner.isComplete(earlier, c),
                                "a cube at ${s} must also be at ${earlier}")
                        else ())
                else ()))

    ///
    /// The rungs are reached by cubes built to sit on them.
    ///
    @Test
    def eachRungIsReachedByACubeThatSitsOnIt(): Unit \ Assert =
        Assert.assertEq(expected = Solved, Beginner.reached(made("")));
        // Turning the top disturbs nothing below it, and leaves the top
        // oriented but its pieces out of place.
        Assert.assertEq(expected = TopCross, Beginner.reached(made("U")));
        // A PLL case: everything below solved, top oriented, top pieces astray.
        Assert.assertEq(expected = TopCross,
            Beginner.reached(made("(R U R' U' R' F R2 U' R' U' R U R' F')'")));
        // An OLL case: two layers done, top not oriented.
        Assert.assertEq(expected = TwoLayers,
            Beginner.reached(made("(r U R' U R U2 r')'")));
        // One turn of a side face breaks the cross.
        Assert.assertEq(expected = Nothing, Beginner.reached(made("F")))

    ///
    /// The ladder agrees with the predicates the other methods use.
    ///
    /// `TwoLayers` is exactly OLL's precondition and `TopCross` exactly PLL's.
    /// Two spellings of one rule would be two rules eventually.
    ///
    @Test
    def theLadderAgreesWithTheLastLayerPredicates(): Unit \ Assert =
        Vector.range(0, 30) |> Vector.forEach(i ->
            match Random.sampleDeterministic(Int32.toInt64(i) + 52000i64, 3)
                |> Result.map(fst) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "sampling")
                case Ok(c)  =>
                    Assert.assertEqWithMsg(
                        expected = Option.isEmpty(LastLayer.faultBelowTheTop(c)),
                        Beginner.isComplete(TwoLayers, c),
                        "TwoLayers should be OLL's precondition");
                    Assert.assertEqWithMsg(
                        expected = Option.isEmpty(LastLayer.faultBelowTheTop(c))
                            and LastLayer.topIsOriented(c),
                        Beginner.isComplete(TopCross, c),
                        "TopCross should be PLL's precondition")
            })

    ///
    /// Every stage says what it is for, and no two say the same thing.
    ///
    @Test
    def everyStageIsDescribedDistinctly(): Unit \ Assert =
        let said = Beginner.ladder() |> List.map(Beginner.describe);
        Assert.assertEqWithMsg(expected = List.length(said),
            List.length(List.distinct(said)), "two stages share a description");
        said |> List.forEach(d ->
            Assert.assertTrueWithMsg(String.length(d) > 10, "'${d}' says too little"))

}
