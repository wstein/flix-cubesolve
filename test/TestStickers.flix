///
/// Turning a cube as stickers.
///
/// The 2x2x2 and 3x3x3 turn through per-orbit move tables; everything larger
/// turns through this geometry. Where both exist they must agree, and that
/// agreement is the whole reason to trust the larger sizes -- there is no
/// independent implementation to check a 4x4x4 against, so the check has to be
/// that the same formula reproduces the sizes that are already trusted.
///
mod TestStickers {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Move.Turn
    use CubeSolve.Model.Random
    use CubeSolve.Model.Stickers

    def cubeAt(seed: Int64, n: Int32): Cube.Cube \ Assert =
        match Random.sampleDeterministic(seed, n) {
            case Ok((c, _)) => c
            case Err(e)     =>
                Assert.assertEqWithMsg(expected = "", e, "seed ${seed}");
                unreachable!()
        }

    def faceletsOf(c: Cube.Cube): Vector[Int32] \ Assert =
        match Facelets.of(c) {
            case Ok(fs) => fs
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "unfolding"); Vector#{}
        }

    def turned(m: Move.Move, c: Cube.Cube): Cube.Cube \ Assert =
        match Cube.apply(m, c) {
            case Ok(x)  => x
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "${m}"); c
        }

    ///
    /// The sticker geometry reproduces the orbit tables, move for move.
    ///
    /// Every one of the eighteen face turns, on the solved cube and on a fixed
    /// sample of random ones, at both sizes the orbit tables cover. A wrong
    /// strip or a strip read backwards shows up here as a specific move on a
    /// specific seed.
    ///
    @Test
    def theStickerGeometryAgreesWithTheOrbitTables(): Unit \ Assert =
        Vector#{2, 3} |> Vector.forEach(n ->
            Vector.range(0, 12) |> Vector.forEach(i -> {
                let seed = Int32.toInt64(i) + 70000i64;
                let c = if (i == 0) solvedAt(n) else cubeAt(seed, n);
                Move.all() |> Vector.forEach(m -> {
                    let byTable = faceletsOf(turned(m, c));
                    let byStickers =
                        Stickers.turn(n, Move.faceIndex(Move.face(m)),
                            Move.amount(m), faceletsOf(c));
                    Assert.assertEqWithMsg(expected = byTable, byStickers,
                        "${n}x${n}x${n}, seed ${seed}, move ${m}: the sticker "
                            + "geometry and the orbit tables disagree")
                })
            }))

    def solvedAt(n: Int32): Cube.Cube \ Assert =
        match Cube.solved(n) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "solved"); unreachable!()
        }

    ///
    /// The group laws hold at every size this engine can turn.
    ///
    /// `m^4 = id` for every move, opposite faces commute, and a sequence
    /// followed by its inverse is the identity. These are the laws that caught
    /// the half-turn bug on the 3x3x3, and they do not become less useful at
    /// 4x4x4 -- they become the only check there is.
    ///
    @Test
    def theGroupLawsHoldAtEverySizeThatTurns(): Unit \ Assert =
        Vector#{2, 3, 4, 5} |> Vector.forEach(n -> {
            let solved = solvedAt(n);
            Move.all() |> Vector.forEach(m -> {
                let fourTimes = List.foldLeft((c, _) -> turned(m, c), solved,
                    List.range(0, 4));
                Assert.assertEqWithMsg(
                    expected = Cube.orbits(solved), Cube.orbits(fourTimes),
                    "${n}x${n}x${n}: ${m} four times is not the identity");
                let opposite = Turn(Move.opposite(Move.face(m)), Move.amount(m));
                let oneWay = turned(opposite, turned(m, solved));
                let theOther = turned(m, turned(opposite, solved));
                Assert.assertEqWithMsg(
                    expected = Cube.orbits(oneWay), Cube.orbits(theOther),
                    "${n}x${n}x${n}: ${m} and ${opposite} do not commute")
            })
        })

    ///
    /// A scramble and its inverse return every size to solved.
    ///
    /// The round trip a solver's answer has to survive. It also exercises the
    /// fold back into orbits on states a random walk reaches, which is where a
    /// sticker arrangement no cube can be in would be refused.
    ///
    @Test
    def aScrambleAndItsInverseReturnEverySizeToSolved(): Unit \ Assert =
        let written = "R U R' U' F2 L D B' R2 F L' U2 D B";
        Vector#{2, 3, 4, 5} |> Vector.forEach(n ->
            match Move.parse(written) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "parsing")
                case Ok(ms) =>
                    let solved = solvedAt(n);
                    let there = List.foldLeft((c, m) -> turned(m, c), solved, ms);
                    Assert.assertTrueWithMsg(
                        Cube.orbits(there) != Cube.orbits(solved) or n == 2,
                        "${n}x${n}x${n}: the scramble changed nothing");
                    let back = List.foldLeft((c, m) -> turned(m, c), there,
                        Move.inverseOf(ms));
                    Assert.assertEqWithMsg(
                        expected = Cube.orbits(solved), Cube.orbits(back),
                        "${n}x${n}x${n}: the scramble and its inverse did not cancel")
            })

}
