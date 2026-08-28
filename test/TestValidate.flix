mod TestValidate {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Validate
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    /// `v` with entries `i` and `j` exchanged.
    def swap(i: Int32, j: Int32, v: Vector[Int32]): Vector[Int32] =
        Vector.init(k ->
            if (k == i) Vector.get(j, v)
            else if (k == j) Vector.get(i, v)
            else Vector.get(k, v), Vector.length(v))

    /// A 3x3x3 built from the given orbits, however illegal.
    def cube3(corners: Orbit64.Coord.Coord, midges: Orbit64.Coord.Coord): Cube.Cube \ Assert =
        match Cube.ofOrbits(3, corners :: midges :: Nil) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected a cube");
                unreachable!()
        }

    def solvedCorners(): Orbit64.Coord.Coord =
        CornerCoord(Vector.range(0, 8), Vector.repeat(8, 0))

    def solvedMidges(): Orbit64.Coord.Coord =
        MidgeCoord(Vector.range(0, 12), Vector.repeat(12, 0))

    /// Corners solved except that slots `i` and `j` hold each other's piece.
    def cornersSwapped(i: Int32, j: Int32): Orbit64.Coord.Coord =
        CornerCoord(swap(i, j, Vector.range(0, 8)), Vector.repeat(8, 0))

    /// Midges solved except that slots `i` and `j` hold each other's piece.
    def midgesSwapped(i: Int32, j: Int32): Orbit64.Coord.Coord =
        MidgeCoord(swap(i, j, Vector.range(0, 12)), Vector.repeat(12, 0))

    /// One corner twisted in place, which no cube can be.
    def oneCornerTwisted(): Orbit64.Coord.Coord =
        CornerCoord(Vector.range(0, 8), Vector.init(i -> if (i == 0) 1 else 0, 8))

    /// One edge flipped in place, which no cube can be.
    def oneEdgeFlipped(): Orbit64.Coord.Coord =
        MidgeCoord(Vector.range(0, 12), Vector.init(i -> if (i == 0) 1 else 0, 12))

    // ---------- what turning can reach ----------

    @Test
    def aSolvedCubeIsReachable(): Unit \ Assert =
        Assert.assertEq(expected = Ok(true), Cube.solved(2) |> Result.map(Validate.isReachable));
        Assert.assertEq(expected = Ok(true), Cube.solved(3) |> Result.map(Validate.isReachable))

    /// Turning cannot leave the reachable set, so a long random walk stays in it.
    @Test
    def everyStateReachedByTurningIsReachable(): Unit \ Assert =
        let walk = "R U2 F' L D B2 R' U L2 D' F B U' R2 D F2 L' B' U D2";
        List.forEach(n ->
            match Cube.solved(n) |> Result.flatMap(c -> Cube.applyNotation(walk, c)) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "walk applies")
                case Ok(c)  => Assert.assertEqWithMsg(
                    expected = None, Validate.faultOf(c), "a turned cube is reachable")
            },
            2 :: 3 :: Nil)

    // ---------- the 3x3x3 parity coupling ----------

    /// Exchanging two corners makes the corner permutation odd while the edge
    /// permutation stays even. No sequence of turns does that -- every face
    /// turn is a 4-cycle on corners and a 4-cycle on edges, so it flips both
    /// parities together.
    @Test
    def swappingTwoCornersAloneIsUnreachableOnAThreeCube(): Unit \ Assert =
        let c = cube3(cornersSwapped(0, 1), solvedMidges());
        Assert.assertFalse(Validate.isReachable(c));
        match Validate.faultOf(c) {
            case None    => Assert.assertTrueWithMsg(false, "should name a fault")
            case Some(w) => Assert.assertTrue(String.contains(substr = "parity", w))
        }

    @Test
    def swappingTwoEdgesAloneIsUnreachableOnAThreeCube(): Unit \ Assert =
        Assert.assertFalse(
            Validate.isReachable(cube3(solvedCorners(), midgesSwapped(0, 1))))

    /// Both swapped together is reachable: the parities agree again.
    @Test
    def swappingTwoCornersAndTwoEdgesIsReachable(): Unit \ Assert =
        Assert.assertTrue(
            Validate.isReachable(cube3(cornersSwapped(0, 1), midgesSwapped(0, 1))))

    /// The same swap on a 2x2x2 is perfectly reachable. A face turn there is a
    /// 4-cycle of corners with nothing to pair it against, so corner parity is
    /// unconstrained. Treating the 3x3x3 rule as generic is a classic error.
    @Test
    def swappingTwoCornersIsReachableOnAPocketCube(): Unit \ Assert =
        match Cube.ofOrbits(2, cornersSwapped(0, 1) :: Nil) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "is a cube")
            case Ok(c)  => Assert.assertTrue(Validate.isReachable(c))
        }

    // ---------- faults orbit64 already knows about ----------

    /// A single twisted corner is not a cube at all, and the reason comes from
    /// the codec rather than being restated here.
    @Test
    def aSingleTwistedCornerIsRejectedWithTheCodecsReason(): Unit \ Assert =
        match Cube.ofOrbits(3, oneCornerTwisted() :: solvedMidges() :: Nil) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "one twisted corner is illegal")
            case Err(e) => Assert.assertTrue(String.contains(substr = "sum to 0 mod 3", e))
        }

    @Test
    def aSingleFlippedEdgeIsRejected(): Unit \ Assert =
        Assert.assertErr(Cube.ofOrbits(3, solvedCorners() :: oneEdgeFlipped() :: Nil))

    // ---------- sizes whose invariants are not implemented ----------

    /// A 4x4x4 has invariants this engine has not derived, so it says so rather
    /// than reporting no fault and implying the cube is fine.
    @Test
    def unimplementedSizesAreNotSilentlyDeclaredReachable(): Unit \ Assert =
        match Cube.solved(4) |> Result.map(Validate.faultOf) {
            case Ok(Some(w)) => Assert.assertTrue(String.contains(substr = "4x4x4", w))
            case _ => Assert.assertTrueWithMsg(false, "should refuse to certify a 4x4x4")
        }

}
