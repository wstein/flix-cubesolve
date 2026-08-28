mod TestCube {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face.{U, R, F, D, L, B}
    use CubeSolve.Model.Move.Move.Turn
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    /// Applies `notation` to a solved `n`, failing the test if anything refuses.
    def scrambled(n: Int32, notation: String): Cube.Cube \ Assert =
        match Result.flatMap(c -> Cube.applyNotation(notation, c), Cube.solved(n)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a cube"); unreachable!()
        }

    // ---------- construction ----------

    @Test
    def solvedCubesAreSolvedAndCarryTheRightOrbits(): Unit \ Assert =
        Assert.assertEq(expected = Ok(true), Cube.solved(2) |> Result.map(Cube.isSolved));
        Assert.assertEq(expected = Ok(true), Cube.solved(3) |> Result.map(Cube.isSolved));
        Assert.assertEq(expected = Ok(1), Cube.solved(2) |> Result.map(c -> List.length(Cube.orbits(c))));
        Assert.assertEq(expected = Ok(2), Cube.solved(3) |> Result.map(c -> List.length(Cube.orbits(c))))

    @Test
    def solvedRefusesSizesWithNoOrbits(): Unit \ Assert =
        Assert.assertErr(Cube.solved(1));
        Assert.assertErr(Cube.solved(0))

    @Test
    def aSolvedCubeIsInTheCanonicalFrame(): Unit \ Assert =
        Assert.assertEq(expected = Ok(0), Cube.solved(3) |> Result.map(Cube.orientation))

    // ---------- group laws ----------

    /// Four quarter turns of any face is the identity. The single cheapest
    /// check that a permutation table was transcribed correctly.
    @Test
    def fourQuarterTurnsIsTheIdentity(): Unit \ Assert =
        List.forEach(n ->
            Move.faces() |> Vector.forEach(f ->
                Assert.assertTrue(Cube.isSolved(scrambled(n, "${f} ${f} ${f} ${f}")))),
            2 :: 3 :: Nil)

    /// True of every move, not only quarter turns: U2 four times is also solved.
    @Test
    def everyMoveHasOrderDividingFour(): Unit \ Assert =
        Move.all() |> Vector.forEach(m -> {
            let s = Move.show(m);
            Assert.assertTrue(Cube.isSolved(scrambled(3, "${s} ${s} ${s} ${s}")))
        })

    /// Opposite faces commute. This is what the search's move-ordering rule
    /// depends on, so it is checked rather than assumed.
    @Test
    def oppositeFacesCommute(): Unit \ Assert =
        let pairs = (U, D) :: (R, L) :: (F, B) :: Nil;
        List.forEach(match (a, b) ->
            List.forEach(ka ->
                List.forEach(kb -> {
                    let ma = Move.show(Turn(a, ka));
                    let mb = Move.show(Turn(b, kb));
                    Assert.assertEq(
                        expected = Cube.orbits(scrambled(3, "${ma} ${mb}")),
                        Cube.orbits(scrambled(3, "${mb} ${ma}"))
                    )
                }, 1 :: 2 :: 3 :: Nil),
                1 :: 2 :: 3 :: Nil),
            pairs)

    /// Adjacent faces do not commute -- otherwise the ordering rule above
    /// would be discarding real solutions.
    @Test
    def adjacentFacesDoNotCommute(): Unit \ Assert =
        Assert.assertNeq(
            unexpected = Cube.orbits(scrambled(3, "U R")),
            Cube.orbits(scrambled(3, "R U"))
        )

    /// A sequence followed by its inverse is the identity.
    @Test
    def aSequenceFollowedByItsInverseSolves(): Unit \ Assert =
        let scramble = "R U2 D' B D'";
        match Move.parse(scramble) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "scramble parses")
            case Ok(ms) =>
                let undo = Move.showAll(Move.inverseOf(ms));
                Assert.assertTrue(Cube.isSolved(scrambled(3, "${scramble} ${undo}")))
        }

    /// The sexy move has order six.
    @Test
    def sexyMoveHasOrderSix(): Unit \ Assert =
        let sexy = "R U R' U'";
        Assert.assertFalse(Cube.isSolved(scrambled(3, "${sexy} ${sexy} ${sexy}")));
        Assert.assertTrue(Cube.isSolved(
            scrambled(3, "${sexy} ${sexy} ${sexy} ${sexy} ${sexy} ${sexy}")))

    // ---------- turn direction, checked against orbit64's facelets ----------

    /// Group laws are blind to direction: a table with every cycle reversed
    /// still satisfies all of them. This pins the direction against an
    /// independent implementation of the same convention.
    ///
    /// A clockwise U seen from above carries the front face's top row to the
    /// left, so after `U` the front face's top row holds what the right face
    /// had -- three facelets of colour R.
    @Test
    def aClockwiseUCarriesTheRightFaceToTheFront(): Unit \ Assert =
        match Cube.facelets(scrambled(3, "U")) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "facelets render")
            case Ok(fs) =>
                let rightColour = Move.faceIndex(R);
                let frontTopRow = 18 :: 19 :: 20 :: Nil;
                List.forEach(i -> Assert.assertEq(expected = rightColour, Vector.get(i, fs)),
                             frontTopRow);
                // and the U face itself is untouched
                List.range(0, 9) |> List.forEach(i ->
                    Assert.assertEq(expected = Move.faceIndex(U), Vector.get(i, fs)))
        }

    /// Round-tripping through the facelet layer is the identity. orbit64's
    /// facelet code shares nothing with the move tables here, so agreement is
    /// a genuine second derivation rather than a restatement.
    @Test
    def stateSurvivesARoundTripThroughFacelets(): Unit \ Assert =
        let c = scrambled(3, "R U2 F' L D B2 R' U");
        match Cube.facelets(c) |> Result.flatMap(fs -> Cube.ofFacelets(3, fs)) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "round trips")
            case Ok(back) => Assert.assertEq(expected = Cube.orbits(c), Cube.orbits(back))
        }

    // ---------- superflip ----------

    /// The superflip: every edge flipped in place, everything else solved. It
    /// is the deepest state on a 3x3x3 at 20 moves, and reaching it from a
    /// published algorithm exercises direction, twist and flip together in a
    /// way no group law does.
    @Test
    def thePublishedSuperflipAlgorithmProducesSuperflip(): Unit \ Assert =
        let alg = "R L U2 F U' D F2 R2 B2 L U2 F' B' U R2 D F2 U R2 U";
        match Cube.orbits(scrambled(3, alg)) {
            case CornerCoord(cp, co) :: MidgeCoord(ep, eo) :: Nil =>
                Assert.assertEq(expected = Vector.range(0, 8), cp);
                Assert.assertEq(expected = Vector.repeat(8, 0), co);
                Assert.assertEq(expected = Vector.range(0, 12), ep);
                Assert.assertEq(expected = Vector.repeat(12, 1), eo)
            case _ => Assert.assertTrueWithMsg(false, "a 3x3x3 has corner and midge orbits")
        }

    /// Superflip is an involution.
    @Test
    def superflipIsItsOwnInverse(): Unit \ Assert =
        let alg = "R L U2 F U' D F2 R2 B2 L U2 F' B' U R2 D F2 U R2 U";
        Assert.assertTrue(Cube.isSolved(scrambled(3, "${alg} ${alg}")))

    // ---------- legality is preserved ----------

    /// Turning never leaves the set of legal cubes. Checked against orbit64's
    /// validator, which knows nothing about moves.
    @Test
    def turningPreservesCubeLegality(): Unit \ Assert =
        let c = scrambled(3, "B U2 R' F D2 L B' R U F2 D L' U2 B2 R");
        Cube.orbits(c) |> List.forEach(o ->
            Assert.assertEq(expected = None, Orbit64.Coord.faultOf(o)))

    // ---------- sizes this engine cannot yet turn ----------

    /// A 4x4x4 has wing and centre orbits and no move tables for them yet. The
    /// refusal names the size rather than failing somewhere downstream.
    @Test
    def turningAnUnimplementedSizeIsRefusedByName(): Unit \ Assert =
        match Result.flatMap(c -> Cube.apply(Turn(U, 1), c), Cube.solved(4)) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "a 4x4x4 cannot be turned yet")
            case Err(e) => Assert.assertTrue(String.contains(substr = "4x4x4", e))
        }

    // ---------- failure reproducibility ----------

    /// Every state can name itself, so a failing test can report the state it
    /// failed on rather than only the seed that produced it.
    @Test
    def everyCubeCanNameItself(): Unit \ Assert =
        Assert.assertOk(Cube.token(scrambled(3, "R U R'")));
        Assert.assertNeq(
            unexpected = Cube.token(scrambled(3, "R U R'")),
            Cube.solved(3) |> Result.flatMap(Cube.token)
        )

}
