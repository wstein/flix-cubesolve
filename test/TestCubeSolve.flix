mod TestCubeSolve {

    @Test
    def supportsTheImplementedSizes(): Unit \ Assert =
        Assert.assertEq(expected = true, CubeSolve.supports(2));
        Assert.assertEq(expected = true, CubeSolve.supports(5))

    @Test
    def rejectsSizesWithNoReduction(): Unit \ Assert =
        Assert.assertEq(expected = false, CubeSolve.supports(1));
        Assert.assertEq(expected = false, CubeSolve.supports(6))

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
