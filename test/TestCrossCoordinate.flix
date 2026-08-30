///
/// The cross coordinate itself.
///
/// Kept apart from the solver's tests because it answers a different question:
/// not "does the search find a cross" but "does this numbering describe one".
/// A ranking that collides puts two crosses at one table entry and makes every
/// distance below it a lie, so it is checked exhaustively rather than sampled.
///
mod TestCrossCoordinate {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Table.Cross.{encode, rank, stateCount, successor, unrank}

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// Every one of the 190,080 coordinates round-trips through `unrank` and
    /// `rank`.
    ///
    /// Exhaustive because the space allows it. A ranking that collides on even
    /// one pair would put two different crosses at one table entry, and the
    /// distance stored there would be wrong for one of them.
    ///
    @Test
    def everyCoordinateRoundTrips(): Unit \ Assert =
        let bad = Vector.range(0, stateCount()) |> Vector.count(i -> {
            let (places, flips) = unrank(i);
            rank(places, flips) != i
        });
        Assert.assertEqWithMsg(expected = 0, bad,
            "coordinates that do not survive unrank then rank");
        // and no two coordinates decode to the same arrangement
        Assert.assertEqWithMsg(expected = 190080, stateCount(),
            "12 x 11 x 10 x 9 arrangements, each with four flips")

    ///
    /// The coordinate agrees with the model about what a move does.
    ///
    /// The successor is arithmetic on four slots; the model turns a whole cube.
    /// They are independent derivations of the same thing, and this is where
    /// they are made to agree -- every move, from a fixed sample of states.
    ///
    @Test
    def theSuccessorAgreesWithTheModel(): Unit \ Assert =
        let seeds = Vector#{"", "R", "R U", "F2 L' D", "R U R' U' F2 L D B'",
            "M2 E2 S2", "D2 R2 L F B' U"};
        seeds |> Vector.forEach(alg -> {
            let c = made(alg);
            match encode(c) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'")
                case Ok(here) =>
                    Move.all() |> Vector.forEach(m -> {
                        let byModel = Cube.apply(m, c) |> Result.flatMap(encode);
                        let byCoord = successor(here, Move.index(m));
                        Assert.assertEqWithMsg(expected = Ok(byCoord), byModel,
                            "'${alg}' then ${m}: the coordinate and the model "
                                + "disagree about where the cross went")
                    })
            }
        })

}
