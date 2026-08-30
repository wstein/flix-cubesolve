///
/// The bottom-corner coordinate itself.
///
/// Separate from the solver's tests for the same reason the cross's are: this
/// asks whether the numbering describes a set of corners, not whether a search
/// can place them.
///
mod TestFirstLayerCoordinate {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Table.FirstLayer.{encode, rank, stateCount, successor, unrank}

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// All 136,080 coordinates round-trip.
    ///
    @Test
    def everyCornerCoordinateRoundTrips(): Unit \ Assert =
        let bad = Vector.range(0, stateCount()) |> Vector.count(i -> {
            let (places, twists) = unrank(i);
            rank(places, twists) != i
        });
        Assert.assertEqWithMsg(expected = 0, bad,
            "coordinates that do not survive unrank then rank");
        Assert.assertEqWithMsg(expected = 136080, stateCount(),
            "8 x 7 x 6 x 5 placements, each with four twists")

    ///
    /// The coordinate agrees with the model about what a move does.
    ///
    @Test
    def theCornerSuccessorAgreesWithTheModel(): Unit \ Assert =
        Vector#{"", "R", "R U", "F2 L' D", "R U R' U' F2 L D B'", "D2 R2 L F B' U"}
            |> Vector.forEach(alg -> {
                let c = made(alg);
                match encode(c) {
                    case Err(e)  => Assert.assertEqWithMsg(expected = "", e, "'${alg}'")
                    case Ok(here) =>
                        Move.all() |> Vector.forEach(m ->
                            Assert.assertEqWithMsg(
                                expected = Ok(successor(here, Move.index(m))),
                                Cube.apply(m, c) |> Result.flatMap(encode),
                                "'${alg}' then ${m}: the coordinate and the model "
                                    + "disagree about where the corners went"))
                }
            })

}
