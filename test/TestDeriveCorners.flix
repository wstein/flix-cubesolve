mod TestDeriveCorners {

    use CubeSolve.Method.Derive
    use CubeSolve.Method.Facts
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    def alphabet(letters: List[String]): Vector[Move.Move] \ Assert =
        letters
            |> List.flatMap(l -> (l :: "${l}2" :: "${l}'" :: Nil))
            |> List.map(t -> match Move.parseMove(t) {
                case Ok(m)  => m
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${t}'"); unreachable!()
            })
            |> List.toVector

    /// Cross home, the other three bottom corners home.
    def restIsSolved(c: Cube.Cube): Bool =
        let ok = r -> Result.getWithDefault(false, r);
        ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, false))
            and ok(Facts.allHome(c, Vector#{5, 6, 7}, true))

    /// The DFR piece sits at URF with twist `t`, and the rest of the layer is in.
    def caseGoal(t: Int32): Cube.Cube -> Bool =
        c ->
            restIsSolved(c) and (match Facts.findCorner(c, 4) {
                case Ok(p)  => p#slot == 0 and p#turn == t
                case Err(_) => false
            })

    /// The corner is in its slot, untwisted, and the rest is still in.
    def inserted(c: Cube.Cube): Bool =
        restIsSolved(c) and Result.getWithDefault(false, Facts.cornerHome(c, 4))

    ///
    /// A right-hand insertion routine for each way the corner can be twisted.
    ///
    /// Derived, not transcribed: a setup is searched for over `R` and `U`, and
    /// the routine is its inverse. Then the routine is replayed against the case
    /// to check it does what it claims -- the corner in, and nothing that was
    /// already solved disturbed.
    ///
    @Test
    def eachTwistHasARoutine(): Unit \ Assert + IO =
        let ru = alphabet("R" :: "U" :: Nil);
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                Vector.range(0, 3) |> Vector.forEach(t ->
                    match Derive.shortest(solved, caseGoal(t), ru, 8) {
                        case None =>
                            Assert.assertTrueWithMsg(false,
                                "no setup within eight moves reaches twist ${t}")
                        case Some(setup) =>
                            let routine = Move.inverseOf(setup);
                            match Cube.applyAll(setup, solved) {
                                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "setup")
                                case Ok(caseCube) =>
                                    println("  twist ${t}: case '${Move.showAll(setup)}'"
                                        + " routine '${Move.showAll(routine)}'");
                                    Assert.assertTrueWithMsg(caseGoal(t)(caseCube),
                                        "the setup should reach the case");
                                    match Cube.applyAll(routine, caseCube) {
                                        case Err(e) =>
                                            Assert.assertEqWithMsg(expected = "", e, "replay")
                                        case Ok(done) =>
                                            Assert.assertTrueWithMsg(inserted(done),
                                                "twist ${t}: the routine should insert the "
                                                    + "corner and disturb nothing")
                                    }
                            }
                    })
        }
}
