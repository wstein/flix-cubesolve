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
    def doesNotClaimSizesItCannotTurn(): Unit \ Assert =
        Assert.assertEq(expected = false, CubeSolve.supports(1));
        Assert.assertEq(expected = false, CubeSolve.supports(4));
        Assert.assertEq(expected = false, CubeSolve.supports(5))

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
