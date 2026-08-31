mod TestDerive {

    use CubeSolve.Method.Derive
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    def after(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    /// The moves a routine is allowed to use, by face letter.
    def alphabet(letters: List[String]): Vector[Move.Move] \ Assert =
        letters
            |> List.flatMap(l -> (l :: "${l}2" :: "${l}'" :: Nil))
            |> List.map(t -> match Move.parseMove(t) {
                case Ok(m)  => m
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${t}'"); unreachable!()
            })
            |> List.toVector

    /// It finds the shortest undo of a short sequence.
    @Test
    def itFindsTheShortestUndo(): Unit \ Assert + IO =
        let c = after("R U R'");
        match Derive.shortest(c, Cube.isSolved, alphabet("R" :: "U" :: Nil), 4) {
            case None    => Assert.assertTrueWithMsg(false, "should have found R U' R'")
            case Some(ms) =>
                println("  derive: undo of 'R U R'' is '${Move.showAll(ms)}'");
                Assert.assertEqWithMsg(expected = 3, List.length(ms),
                    "the shortest undo is three moves")
        }

    /// How deep it can go, and how long that takes.
    @Test
    def itSearchesDeepEnoughForARoutine(): Unit \ Assert + IO =
        // Six moves, and nothing shorter solves it.
        let c = after("F R U R' U' F'");
        match Derive.shortest(c, Cube.isSolved, alphabet("F" :: "R" :: "U" :: Nil), 6) {
            case None     => Assert.assertTrueWithMsg(false, "six moves should be reachable")
            case Some(ms) =>
                println("  derive: six-move case answered in ${List.length(ms)}");
                Assert.assertTrueWithMsg(List.length(ms) <= 6, "at most six")
        }
}
