///
/// The corner-and-edge pair coordinate.
///
/// Checked before it is ever used as a heuristic. A projection that is not a
/// bijection, or whose successor disagrees with the cube, produces a table of
/// wrong distances — and a wrong *lower* bound does not merely slow a search
/// down, it makes it return sequences that are not shortest while looking
/// perfectly healthy.
///
/// **Nothing here builds a table.** Every check below is arithmetic and the five
/// together cost about a tenth of a second; the 3.2-million-state construction
/// is asserted in `TestTwoLayers`, which builds it anyway. Building it twice
/// cost the suite seventy seconds to prove the same thing.
///
mod TestCornerEdgePair {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Solve.TwoLayers
    use CubeSolve.Table.CornerEdgePair.{designatedEdge, encode, rank, solvedIndex,
        stateCount, successor, unrank}
    use CubeSolve.Table.Cross
    use CubeSolve.Table.FirstLayer
    use CubeSolve.Table.MiddleEdges

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// All 3,265,920 coordinates round-trip.
    ///
    @Test
    def everyPairCoordinateRoundTrips(): Unit \ Assert =
        Assert.assertEqWithMsg(expected = 3265920, stateCount(),
            "136,080 corner states by twelve slots by two flips");
        let bad = Vector.range(0, stateCount()) |> Vector.count(i -> {
            let (corners, slot, flip) = unrank(i);
            rank(corners, slot, flip) != i
        });
        Assert.assertEqWithMsg(expected = 0, bad,
            "coordinates that do not survive unrank then rank")

    ///
    /// A solved cube sits at the solved coordinate, and the edge is where it
    /// says.
    ///
    @Test
    def aSolvedCubeSitsAtTheSolvedCoordinate(): Unit \ Assert =
        Assert.assertEq(expected = Ok(solvedIndex()), encode(made("")));
        let (_, slot, flip) = unrank(solvedIndex());
        Assert.assertEqWithMsg(expected = designatedEdge(), slot,
            "the designated edge is home when solved");
        Assert.assertEqWithMsg(expected = 0, flip, "and the right way round")

    ///
    /// The successor agrees with the model, for every move.
    ///
    /// Both halves at once: a fault in either would show here, and the corner
    /// half is shared with `Table.FirstLayer` so this also guards against the
    /// two coming apart.
    ///
    @Test
    def thePairSuccessorAgreesWithTheModel(): Unit \ Assert =
        Vector#{"", "R", "R U", "F2 L' D", "R U R' U' F2 L D B'", "D2 R2 L F B' U",
            "M2 E2 S2"}
            |> Vector.forEach(alg -> {
                let c = made(alg);
                match encode(c) {
                    case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "'${alg}'")
                    case Ok(here) =>
                        Move.all() |> Vector.forEach(m ->
                            Assert.assertEqWithMsg(
                                expected = Ok(successor(here, Move.index(m))),
                                Cube.apply(m, c) |> Result.flatMap(encode),
                                "'${alg}' then ${m}: the pair coordinate and the "
                                    + "model disagree"))
                }
            })

    ///
    /// `Cross.firstPiece` agrees with `unrank`, on every cross coordinate.
    ///
    /// The hot-path shortcut, isolated from everything it is used for. It reads
    /// the first piece's slot arithmetically -- the first placement digit
    /// indexes the full free list, so the digit is the slot -- and that is only
    /// true because nothing has been taken yet. All 190,080, because the claim
    /// is about the ranking scheme rather than about any particular state.
    ///
    @Test
    def firstPieceAgreesWithUnrankEverywhere(): Unit \ Assert =
        let bad = Vector.range(0, Cross.stateCount()) |> Vector.count(i -> {
            let (places, flips) = Cross.unrank(i);
            Cross.firstPiece(i) != (Vector.get(0, places), Vector.get(0, flips))
        });
        Assert.assertEqWithMsg(expected = 0, bad,
            "cross coordinates where the fast first-piece read disagrees with unrank")

    ///
    /// The pair coordinate the search derives is the one this module encodes.
    ///
    /// `TwoLayers` does not carry the pair in its state -- it reads the corner
    /// half and the designated edge out of the two halves it already has. That
    /// derivation assumes the middle-edge coordinate's first tracked piece is
    /// this module's designated edge, which is true and which nothing in the
    /// types enforces. If it stopped being true the search would read another
    /// state's distance, and one that is too large makes the heuristic
    /// inadmissible.
    ///
    /// That does not produce a wrong cube -- an inadmissible bound still yields
    /// a sequence that replays and solves. It produces a *longer* one, because
    /// the search prunes a branch holding the shorter answer, or a false report
    /// that the bounded search was exhausted. Neither shows up in a replay
    /// check, which is exactly why the coordinate is pinned here instead.
    ///
    @Test
    def theSearchDerivesThePairCoordinateThisModuleEncodes(): Unit \ Assert =
        Assert.assertEqWithMsg(expected = designatedEdge(),
            Vector.get(0, MiddleEdges.middleEdges()),
            "the pair's designated edge must be the middle-edge coordinate's first");
        Vector#{"", "R", "R U", "F2 L' D", "R U R' U' F2 L D B'", "D2 R2 L F B' U",
            "M2 E2 S2", "U R U' R' F' U F", "R2 D2 B L' F"}
            |> Vector.forEach(alg -> {
                let c = made(alg);
                match (Cross.encode(c), FirstLayer.encode(c), MiddleEdges.encode(c),
                        encode(c)) {
                    case (Ok(x), Ok(y), Ok(z), Ok(pair)) =>
                        Assert.assertEqWithMsg(expected = pair,
                            TwoLayers.pairedOf(TwoLayers.pack(x, y, z)),
                            "'${alg}': the search derives a different pair "
                                + "coordinate than the table was built over")
                    case _ =>
                        Assert.assertTrueWithMsg(false, "'${alg}' should encode")
                }
            })

}
