mod TestPocketPatternOptimality {

    use CubeSolve.Patterns
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
    ///
    /// It also means the solver can never need more moves than a published
    /// algorithm, which is a stronger statement than the 3x3x3 can make: there
    /// the solver is longer than the publication on 32 of 102 patterns, and
    /// here it cannot be longer than any of them. Every published algorithm
    /// that is *not* already shortest is counted, so the collection says how
    /// much slack the publications carry: **63 of the 89 published algorithms
    /// are already the shortest possible**, and the remaining 26 are longer by
    /// at most 4 moves -- 752 moves published against 702 needed.
    @Test
    def everyRecordedSequenceIsProvablyTheShortest(): Unit \ Assert =
        match CubeSolve.Table.Pocket.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected the tables")
            case Ok(t)  =>
                let deepest = Patterns.Pocket.all() |> Vector.foldLeft((worst, p) -> {
                    let name = Patterns.Pocket.name(p);
                    let moves = Patterns.Pocket.optimal(p);
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
                    "the deepest pattern should sit at the 2x2x2 diameter");

                // and no published algorithm beats the exact solver
                let slack = Patterns.Pocket.all() |> Vector.foldLeft((acc, p) -> {
                    let (looser, most) = acc;
                    let name = Patterns.Pocket.name(p);
                    let shortest = List.length(
                        Move.parse(Patterns.Pocket.optimal(p))
                            |> Result.getWithDefault(Nil));
                    let published = List.length(
                        Move.parse(Patterns.Pocket.notation(p))
                            |> Result.getWithDefault(Nil));
                    Assert.assertTrueWithMsg(published >= shortest,
                        "'${name}' is published in ${published} moves, shorter than the "
                            + "${shortest} an exact solver needs -- one of them is wrong");
                    if (published > shortest) (looser + 1, Int32.max(most, published - shortest))
                    else (looser, most)
                }, (0, 0));
                let (looser, most) = slack;
                Assert.assertTrueWithMsg(looser <= 26,
                    "${looser} published pocket-cube algorithms are longer than "
                        + "necessary, up from the recorded 26");
                Assert.assertTrueWithMsg(most <= 4,
                    "a published algorithm carries ${most} moves of slack, over the "
                        + "recorded 4")
        }

}
