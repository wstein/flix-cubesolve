mod PocketScrambleTestSupport {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized
    use CubeSolve.Model.Validate
    use CubeSolve.Scramble.Pocket

    /// Every 2x2x2 table.
    pub def tables(): CubeSolve.Table.Pocket.Tables \ Assert =
        match CubeSolve.Table.Pocket.build() {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    /// A scramble must actually produce the state it claims, and that state must
    /// be one turning can reach.
    pub def assertSound(s: Pocket.Scramble): Unit \ Assert =
        let apply = c -> Cube.applyAll(Pocket.moves(s), c);
        let built = Cube.solved(2) |> Result.flatMap(apply);
        Assert.assertEqWithMsg(
            expected = Ok(Cube.orbits(Sized.cubeOfPocket(Pocket.state(s)))),
            built |> Result.map(Cube.orbits),
            "the scramble '${Pocket.show(s)}' did not produce the state it reports");
        Assert.assertEqWithMsg(
            expected = None, Validate.faultOf(Sized.cubeOfPocket(Pocket.state(s))),
            "the scramble '${Pocket.show(s)}' produced an unreachable state")

    /// Whether a scramble names the solved cube.
    pub def isSolved(s: Pocket.Scramble): Bool =
        Cube.isSolved(Sized.cubeOfPocket(Pocket.state(s)))

}
