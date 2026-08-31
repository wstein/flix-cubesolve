///
/// Prints the source of `CubeSolve.Method.Beginner.Routines`.
///
/// Not a gate. It is run by hand when a routine family is added or the
/// derivation policy changes, and its output is committed. `TestRoutines` is
/// the authority that the committed file still says what derivation says.
///
mod GenerateRoutines {

    use CubeSolve.Method.Derive
    use CubeSolve.Method.Facts
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    def alphabet(letters: List[String]): Vector[Move.Move] \ Assert =
        letters
            |> List.flatMap(l -> (l :: "${l}2" :: "${l}'" :: Nil))
            |> List.map(t -> match Move.parseMove(t) {
                case Ok(m)  => m
                case Err(e) =>
                    Assert.assertEqWithMsg(expected = "", e, "'${t}'"); unreachable!()
            })
            |> List.toVector

    def restIsSolved(c: Cube.Cube): Bool =
        let ok = r -> Result.getWithDefault(false, r);
        ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, false))
            and ok(Facts.allHome(c, Vector#{5, 6, 7}, true))

    def caseGoal(t: Int32): Cube.Cube -> Bool =
        c ->
            restIsSolved(c) and (match Facts.findCorner(c, 4) {
                case Ok(p)  => p#slot == 0 and p#turn == t
                case Err(_) => false
            })

    @Test
    def printTheModule(): Unit \ Assert + IO =
        let ru = alphabet("R" :: "U" :: Nil);
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                println("=== BEGIN GENERATED ===");
                Vector.range(0, 3) |> Vector.forEach(t ->
                    match Derive.shortest(solved, caseGoal(t), ru, 8) {
                        case None => println("        // twist ${t}: none within eight")
                        case Some(setup) =>
                            let routine = Move.inverseOf(setup);
                            println("        { name = \"corner-insert-right-twist-${t}\",");
                            println("          alphabet = \"R U\",");
                            println("          goal = \"the DFR corner is home and untwisted\",");
                            println("          preserves = \"cross; corners DLF, DBL, DRB\",");
                            println("          setup = \"${Move.showAll(setup)}\",");
                            println("          sequence = \"${Move.showAll(routine)}\",");
                            println("          length = ${List.length(routine)} } ::")
                    });
                println("=== END GENERATED ===")
        }
}
