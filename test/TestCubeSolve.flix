mod TestCubeSolve {

    /// The list says what is implemented, not what is planned. A size listed
    /// here must be one every layer can actually handle, because callers branch
    /// on it.
    @Test
    def supportsTheSizesThatAreImplemented(): Unit \ Assert =
        Assert.assertEq(expected = Vector#{2, 3}, CubeSolve.supportedSizes());
        Assert.assertEq(expected = true, CubeSolve.supports(2));
        Assert.assertEq(expected = true, CubeSolve.supports(3))

    @Test
    def doesNotClaimToSolveSizesItCannot(): Unit \ Assert =
        Assert.assertEq(expected = false, CubeSolve.supports(1));
        Assert.assertEq(expected = false, CubeSolve.supports(4));
        Assert.assertEq(expected = false, CubeSolve.supports(5))

    /// Turning is a weaker claim than solving, and the two lists say so.
    ///
    /// Every size that can be solved can be turned, and the 4x4x4 and 5x5x5 can
    /// be turned without being solvable. Were these ever to coincide, one of the
    /// two questions would have stopped being asked, and callers branching on
    /// the wrong one would go unnoticed.
    @Test
    def turningIsAWeakerClaimThanSolving(): Unit \ Assert =
        Assert.assertEq(expected = Vector#{2, 3, 4, 5}, CubeSolve.turnableSizes());
        CubeSolve.supportedSizes() |> Vector.forEach(n ->
            Assert.assertTrueWithMsg(CubeSolve.canTurn(n),
                "a ${n}x${n}x${n} is solvable but not turnable, which is impossible"));
        Assert.assertTrue(CubeSolve.canTurn(4) and not CubeSolve.supports(4));
        Assert.assertTrue(CubeSolve.canTurn(5) and not CubeSolve.supports(5));
        Assert.assertFalse(CubeSolve.canTurn(1));
        Assert.assertFalse(CubeSolve.canTurn(6))

    /// Every turnable size can actually be built and turned, so that list
    /// cannot drift ahead of the implementation either.
    @Test
    def everyTurnableSizeCanBeBuiltAndTurned(): Unit \ Assert =
        CubeSolve.turnableSizes() |> Vector.forEach(n ->
            Assert.assertOk(
                CubeSolve.Model.Cube.solved(n)
                    |> Result.flatMap(c -> CubeSolve.Model.Cube.applyNotation("R U F' D2", c))
            ))

    /// Every supported size is one the model can actually build and turn --
    /// the list cannot drift ahead of the implementation without failing here.
    @Test
    def everySupportedSizeCanBeBuiltAndTurned(): Unit \ Assert =
        CubeSolve.supportedSizes() |> Vector.forEach(n ->
            Assert.assertOk(
                CubeSolve.Model.Cube.solved(n)
                    |> Result.flatMap(c -> CubeSolve.Model.Cube.applyNotation("R U F' D2", c))
            ))

    ///
    /// The dependency is reachable and agrees with the arithmetic the plan
    /// records: `Orbit64.stateCount(3)` counts every encodable state, which is
    /// exactly twice the classic figure because the classic figure excludes the
    /// unreachable half that the coupled permutation parity rules out.
    ///
    @Test
    def orbit64IsOnTheClasspath(): Unit \ Assert =
        Assert.assertEq(
            expected = 2ii * 43252003274489856000ii,
            Orbit64.stateCount(3)
        )

}
