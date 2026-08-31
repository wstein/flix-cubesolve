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
    use CubeSolve.Method.Beginner.Spec
    use CubeSolve.Method.Beginner.Spec.Situation

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

    def caseGoal(slot: Int32, t: Int32): Cube.Cube -> Bool =
        c ->
            restIsSolved(c) and (match Facts.findCorner(c, 4) {
                case Ok(p)  => p#slot == slot and p#turn == t
                case Err(_) => false
            })

    /// The first layer and the other three middle edges are home.
    def belowTheTopIsSolved(c: Cube.Cube): Bool =
        let ok = r -> Result.getWithDefault(false, r);
        ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, false))
            and ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, true))
            and ok(Facts.allHome(c, Vector#{9, 10, 11}, false))

    /// The FR edge sits in top slot `slot` with flip `f`, everything else in.
    def middleCase(slot: Int32, f: Int32): Cube.Cube -> Bool =
        c ->
            belowTheTopIsSolved(c) and (match Facts.findEdge(c, 8) {
                case Ok(p)  => p#slot == slot and p#turn == f
                case Err(_) => false
            })

    @Test
    def printTheMiddleEdges(): Unit \ Assert + IO =
        let right = alphabet("R" :: "U" :: "F" :: Nil);
        let left = alphabet("L" :: "U" :: "F" :: Nil);
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                println("=== BEGIN MIDDLE ===");
                Vector.range(0, 4) |> Vector.forEach(slot ->
                    Vector.range(0, 2) |> Vector.forEach(f -> {
                        let goal = middleCase(slot, f);
                        let found = match Derive.shortest(solved, goal, right, 8) {
                            case Some(setup) => Some(("R U F", setup))
                            case None        => match Derive.shortest(solved, goal, left, 8) {
                                case Some(setup) => Some(("L U F", setup))
                                case None        => None
                            }
                        };
                        match found {
                            case None =>
                                println("        // middle slot ${slot} flip ${f}: none found")
                            case Some((letters, setup)) =>
                                let routine = Move.inverseOf(setup);
                                println("        { name = "
                                    + "\"middle-insert-slot-${slot}-flip-${f}\",");
                                println("          situation = "
                                    + "Situation.MiddleInsert(${slot}, ${f}), // ${letters}");
                                println("          setup = \"${Move.showAll(setup)}\",");
                                println("          sequence = \"${Move.showAll(routine)}\",");
                                println("          length = ${List.length(routine)} } ::")
                        }
                    }));
                println("=== END MIDDLE ===")
        }

    @Test
    def printTheModule(): Unit \ Assert + IO =
        let ru = alphabet("R" :: "U" :: Nil);
        match Cube.solved(3) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved")
            case Ok(solved) =>
                println("=== BEGIN GENERATED ===");
                Spec.cornerSituations() |> List.forEach(sit ->
                    match sit {
                        case Situation.CornerInsertion(slot, t) =>
                    match Derive.shortest(solved, caseGoal(slot, t), ru,
                            Spec.maxDepth(sit)) {
                        case None =>
                            println("        // slot ${slot} twist ${t}: none found")
                        case Some(setup) =>
                            let routine = Move.inverseOf(setup);
                            println("        { name = "
                                + "\"corner-insertion-slot-${slot}-twist-${t}\",");
                            println("          situation = "
                                + "Situation.CornerInsertion(${slot}, ${t}),");
                            println("          setup = \"${Move.showAll(setup)}\",");
                            println("          sequence = \"${Move.showAll(routine)}\",");
                            println("          length = ${List.length(routine)} } ::")
                    }
                        case _ => ()
                    });
                println("=== END GENERATED ===")
        }
}
