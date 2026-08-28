mod TestStandardSearch {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Phase1
    use CubeSolve.Table.Standard.Tables

    /// Every phase-one table. Three breadth-first sweeps over 6.6 million
    /// states between them, so this is built once and asserted against
    /// thoroughly.
    def phase1(): Tables \ Assert =
        match CubeSolve.Table.Standard.build() {
            case Ok(p)  => p
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the phase-one tables");
                unreachable!()
        }

    def scrambled(notation: String): Sized.Standard \ Assert =
        let built = Cube.solved(3)
            |> Result.flatMap(c -> Cube.applyNotation(notation, c))
            |> Result.flatMap(Sized.standardOf);
        match built {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected a cube");
                unreachable!()
        }

    /// The packed state carries all three coordinates and gives them back.
    ///
    /// Twist x Flip x UDSlice is 2,217,093,120, which overflows Int32 -- the
    /// reason the search kernel is parameterised by state width at all. A
    /// packing that silently wrapped would fail here rather than in a search.
    @Test
    def thePackedStateRoundTripsAcrossTheWholeRange(): Unit \ Assert =
        Assert.assertEq(expected = 2217093120i64, Phase1.stateCount());
        let corners =
            (0, 0, 0) :: (2186, 2047, 494) :: (1, 2, 3)
                :: (2186, 0, 494) :: (0, 2047, 0) :: Nil;
        corners |> List.forEach(match (twist, flip, slice) -> {
            let packed = Phase1.pack(twist, flip, slice);
            Assert.assertTrueWithMsg(packed >= 0i64, "packing ${twist} ${flip} ${slice} wrapped");
            Assert.assertEqWithMsg(expected = twist, Phase1.twistOf(packed), "twist back");
            Assert.assertEqWithMsg(expected = flip, Phase1.flipOf(packed), "flip back");
            Assert.assertEqWithMsg(expected = slice, Phase1.sliceOf(packed), "slice back")
        })

    /// Phase one really does reach the subgroup, checked from decoded model
    /// state rather than from the coordinate the search wrote.
    ///
    /// That distinction is the whole point of keeping the two representations
    /// apart: a search bug that corrupted a coordinate would certify its own
    /// output if the coordinate were the thing asked.
    ///
    /// The solutions are also replayed through the model, so a sequence that
    /// reached the goal in coordinates but not on the cube fails here.
    @Test
    def phaseOneSolutionsReachTheSubgroupOnTheRealCube(): Unit \ Assert =
        let p = phase1();
        List.forEach(alg -> {
            let cube = scrambled(alg);
            match Phase1.phase1Solution(p, cube) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'")
                case Ok(ms) =>
                    Assert.assertTrueWithMsg(
                        List.length(ms) <= Phase1.maxDepth(),
                        "'${alg}' needed ${List.length(ms)} moves, over the bound");
                    let after = Cube.applyAll(ms, Sized.cubeOfStandard(cube));
                    match after {
                        case Err(e) =>
                            Assert.assertEqWithMsg(expected = "", e, "replay of '${alg}'")
                        case Ok(c)  =>
                            Assert.assertTrueWithMsg(
                                CubeSolve.Table.Standard.isPhase1Solved(c),
                                "'${alg}' plus its phase-one solution did not "
                                    + "reach the subgroup: "
                                    + Move.showAll(ms))
                    }
            }
        },
        "R" :: "R U F" :: "R U2 F' L D B2 R' U" :: "F U R2 B' L D2 F' U' R"
            :: "U2 D2 R2 L2 F2 B2" :: ""
            // The superflip: solved in permutation, every edge flipped. A good
            // case because the goal test must be "inside the subgroup" and not
            // "solved" -- a cube can be one without being the other.
            :: "R L U2 F U' D F2 R2 B2 L U2 F' B' U R2 D F2 U R2 U" :: Nil)

}
