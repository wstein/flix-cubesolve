mod TestSized {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized

    @Test
    def aCubeOfTheRightSizeIsAccepted(): Unit \ Assert =
        Assert.assertOk(Cube.solved(2) |> Result.flatMap(Sized.pocketOf));
        Assert.assertOk(Cube.solved(3) |> Result.flatMap(Sized.standardOf));
        Assert.assertOk(Sized.solvedPocket());
        Assert.assertOk(Sized.solvedStandard())

    /// The mismatch that the wrappers exist to catch. At run time it is a named
    /// refusal; at compile time the two are different types, so a caller cannot
    /// hand one to a solver written for the other at all.
    @Test
    def aCubeOfTheWrongSizeIsRefusedByName(): Unit \ Assert =
        match Cube.solved(3) |> Result.flatMap(Sized.pocketOf) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "a 3x3x3 is not a pocket cube")
            case Err(e) =>
                Assert.assertTrue(String.contains(substr = "2x2x2", e));
                Assert.assertTrue(String.contains(substr = "3x3x3", e))
        };
        Assert.assertErr(Cube.solved(2) |> Result.flatMap(Sized.standardOf));
        Assert.assertErr(Cube.solved(4) |> Result.flatMap(Sized.standardOf))

    /// Wrapping and unwrapping is the identity: there is one representation,
    /// not two, so nothing can be lost between them.
    @Test
    def wrappingIsLossless(): Unit \ Assert =
        match Cube.solved(2) |> Result.flatMap(c -> Cube.applyNotation("R U F'", c)) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "scramble applies")
            case Ok(c)  =>
                Assert.assertEq(
                    expected = Ok(c),
                    Sized.pocketOf(c) |> Result.map(Sized.cubeOfPocket)
                )
        }

}
