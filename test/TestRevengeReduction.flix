///
/// Tests for 4x4x4 reduction model, parity detection, and 3x3x3 equivalence mapping.
///
mod TestRevengeReduction {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Revenge

    def made(n: Int32, notation: String): Cube.Cube =
        match Cube.solved(n) {
            case Ok(sol) =>
                Cube.applyNotation(notation, sol) |> Result.getWithDefault(sol)
            case Err(_)  => unreachable!()
        }

    /// Solved 4x4 is recognized as reduced.
    @Test
    def solvedFourByFourIsReduced(): Unit \ Assert = {
        let c = made(4, "");
        Assert.assertTrue(Revenge.isCentersSolved(c));
        Assert.assertTrue(Revenge.isWingsPaired(c));
        Assert.assertTrue(Revenge.isReduced(c))
    }

    /// Solved 4x4 maps to solved 3x3.
    @Test
    def solvedFourByFourMapsToSolvedThreeByThree(): Unit \ Assert = {
        let c4 = made(4, "");
        let res3 = Revenge.toStandard(c4);
        match res3 {
            case Err(why) => Assert.assertEqWithMsg(expected = "", why, "failed to map")
            case Ok(c3)   => Assert.assertTrue(Cube.isSolved(c3))
        }
    }

    /// Outer face turns preserve 4x4 reduced status.
    @Test
    def outerFaceTurnsPreserveReducedStatus(): Unit \ Assert = {
        let c = made(4, "R U F2 D' L' B2");
        Assert.assertTrue(Revenge.isCentersSolved(c));
        Assert.assertTrue(Revenge.isWingsPaired(c));
        Assert.assertTrue(Revenge.isReduced(c));
        let res3 = Revenge.toStandard(c);
        let exp3 = made(3, "R U F2 D' L' B2");
        match res3 {
            case Err(why) => Assert.assertEqWithMsg(expected = "", why, "failed to map")
            case Ok(c3)   => Assert.assertEq(expected = exp3, c3)
        }
    }

    /// Inner slice turn breaks reduced status.
    @Test
    def innerSliceTurnBreaksReducedStatus(): Unit \ Assert = {
        let c = made(4, "2R");
        Assert.assertFalse(Revenge.isCentersSolved(c));
        Assert.assertFalse(Revenge.isWingsPaired(c));
        Assert.assertFalse(Revenge.isReduced(c));
        Assert.assertErr(Revenge.toStandard(c))
    }

    /// OLL parity algorithm creates wing parity.
    @Test
    def ollParityAlgorithmCreatesWingParity(): Unit \ Assert = {
        let c = made(4, Revenge.ollParity());
        Assert.assertEq(expected = Ok(true), Revenge.hasWingParity(c))
    }

    /// PLL parity algorithm creates corner parity.
    @Test
    def pllParityAlgorithmCreatesCornerParity(): Unit \ Assert = {
        let c = made(4, Revenge.pllParity());
        Assert.assertEq(expected = Ok(true), Revenge.hasCornerParity(c))
    }

    /// Reduced scrambled 4x4 is solved back to identity through 3x3 reduction.
    @Test
    def reducedScrambledFourByFourIsSolvedBackToIdentity(): Unit \ Assert =
        CubeSolve.Table.Cache.withoutCache(() -> {
            let c = made(4, "R U F2 D' L' B2");
            match CubeSolve.Solve.Revenge.solution(c) {
                case Err(why) => Assert.assertEqWithMsg(expected = "", why, "failed to solve")
                case Ok(ops) =>
                    let step = (acc, op) -> Result.flatMap(x -> Cube.applyOp(op, x), acc);
                    let solved = List.foldLeft(step, Ok(c), ops) |> Result.getWithDefault(c);
                    Assert.assertTrue(Cube.isSolved(solved))
            }
        })

    /// Reduced 4x4 with OLL wing parity is solved back to identity.
    @Test
    def reducedWithOllParityIsSolvedBackToIdentity(): Unit \ Assert =
        CubeSolve.Table.Cache.withoutCache(() -> {
            let c = made(4, "R U " + Revenge.ollParity() + " U' R'");
            match CubeSolve.Solve.Revenge.solution(c) {
                case Err(why) => Assert.assertEqWithMsg(expected = "", why, "failed to solve")
                case Ok(ops) =>
                    let step = (acc, op) -> Result.flatMap(x -> Cube.applyOp(op, x), acc);
                    let solved = List.foldLeft(step, Ok(c), ops) |> Result.getWithDefault(c);
                    Assert.assertTrue(Cube.isSolved(solved))
            }
        })

    /// Reduced 4x4 with PLL corner/edge parity is solved back to identity.
    @Test
    def reducedWithPllParityIsSolvedBackToIdentity(): Unit \ Assert =
        CubeSolve.Table.Cache.withoutCache(() -> {
            let c = made(4, "R2 U2 " + Revenge.pllParity() + " U2 R2");
            match CubeSolve.Solve.Revenge.solution(c) {
                case Err(why) => Assert.assertEqWithMsg(expected = "", why, "failed to solve")
                case Ok(ops) =>
                    let step = (acc, op) -> Result.flatMap(x -> Cube.applyOp(op, x), acc);
                    let solved = List.foldLeft(step, Ok(c), ops) |> Result.getWithDefault(c);
                    Assert.assertTrue(Cube.isSolved(solved))
            }
        })

}
