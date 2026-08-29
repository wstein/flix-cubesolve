mod TestPocketPatternOptimality {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Pocket

    /// The cube `alg` makes from a solved 2x2x2.
    def made(what: String, alg: String): Cube.Cube \ Assert =
        match Cube.solved(2) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "${what}: '${alg}'");
                unreachable!()
        }

    /// The recorded sequences really are the shortest, checked against the
    /// exact oracle rather than against the generator that produced them.
    ///
    /// The 2x2x2's whole state space fits in a table, so "shortest" is a fact
    /// that can be looked up rather than a claim. The deepest patterns here sit
    /// exactly at the puzzle's diameter of 11 -- as far from solved as a pocket
    /// cube gets.
    @Test
    def everyRecordedSequenceIsProvablyTheShortest(): Unit \ Assert =
        match CubeSolve.Table.Pocket.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected the tables")
            case Ok(t)  =>
                let deepest = PocketPatternFixtures.all() |> Vector.foldLeft((worst, p) -> {
                    let name = PocketPatternFixtures.name(p);
                    let moves = PocketPatternFixtures.optimal(p);
                    let stated = List.length(Move.parse(moves) |> Result.getWithDefault(Nil));
                    Assert.assertTrueWithMsg(stated >= 1 and stated <= Pocket.diameter(),
                        "'${name}' is ${stated} moves, outside 1 to ${Pocket.diameter()}");
                    let c = made(name, moves);
                    match Sized.pocketOf(c) |> Result.flatMap(x -> Pocket.solution(t, x)) {
                        case Err(e) =>
                            Assert.assertEqWithMsg(expected = "", e, "'${name}'");
                            worst
                        case Ok(ms) =>
                            Assert.assertEqWithMsg(
                                expected = List.length(ms), stated,
                                "'${name}' is stated in ${stated} moves but its exact "
                                    + "distance is ${List.length(ms)}");
                            Int32.max(worst, stated)
                    }
                }, 0);
                Assert.assertEqWithMsg(expected = Pocket.diameter(), deepest,
                    "the deepest pattern should sit at the 2x2x2 diameter")
        }

}
