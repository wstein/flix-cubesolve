mod TestSolveEndToEnd {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Pocket

    @Test
    def aCubeScrambledByNotationIsSolvedBackThroughTheModel(): Unit \ Assert =
        let t = match CubeSolve.Table.Pocket.build() {
            case Ok(x)  => x
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        };
        List.forEach(scramble ->
            match Cube.solved(2) |> Result.flatMap(c -> Cube.applyNotation(scramble, c)) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "scramble applies")
                case Ok(c)  =>
                    let solved = Sized.pocketOf(c)
                        |> Result.flatMap(p -> Pocket.solution(t, p))
                        |> Result.flatMap(ms -> Cube.applyAll(ms, c))
                        |> Result.map(Cube.isSolved);
                    Assert.assertEqWithMsg(
                        expected = Ok(true), solved,
                        "the solution for '${scramble}' did not solve it")
            },
            "R U F" :: "R U2 F' R' U F2" :: "U R' F U2 R F' U' R2" :: "F" :: Nil)

}
