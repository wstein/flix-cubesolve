mod TestNotation {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation
    use CubeSolve.Model.Rotation
    use CubeSolve.Model.Move.Face.{U, R, F, D, L, B}

    /// The cube `notation` produces from a solved `n`, failing the test if
    /// anything refuses.
    def afterMoves(n: Int32, notation: String): Cube.Cube \ Assert =
        match Result.flatMap(c -> Cube.applyNotation(notation, c), Cube.solved(n)) {
            case Ok(c)  => c
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected a cube");
                unreachable!()
        }

    /// Two notations describe the same cube when they agree on both the piece
    /// arrangement and the frame. Comparing only the arrangement would let a
    /// wrong slice expansion pass.
    def same(n: Int32, a: String, b: String): Unit \ Assert =
        let x = afterMoves(n, a);
        let y = afterMoves(n, b);
        Assert.assertEqWithMsg(expected = Cube.orbits(x), Cube.orbits(y),
            "'${a}' and '${b}' should arrange the pieces alike");
        Assert.assertEqWithMsg(expected = Cube.orientation(x), Cube.orientation(y),
            "'${a}' and '${b}' should leave the same frame")

    // ---------- rotations ----------

    /// A whole-cube rotation moves no piece relative to any other, so a solved
    /// cube stays solved. It is the frame that changed.
    @Test
    def rotatingASolvedCubeLeavesItSolved(): Unit \ Assert =
        List.forEach(r -> Assert.assertTrue(Cube.isSolved(afterMoves(3, r))),
            "x" :: "y" :: "z" :: "x2" :: "y'" :: "z2 y x'" :: Nil)

    @Test
    def rotatingChangesTheFrame(): Unit \ Assert =
        Assert.assertEq(expected = Rotation.x(), Cube.orientation(afterMoves(3, "x")));
        Assert.assertEq(expected = Rotation.y(), Cube.orientation(afterMoves(3, "y")));
        Assert.assertEq(expected = Rotation.z(), Cube.orientation(afterMoves(3, "z")));
        Assert.assertEq(expected = Rotation.identity(), Cube.orientation(afterMoves(3, "x x x x")))

    /// Conjugating a turn by a rotation renames the face. After `y` the face on
    /// the right is the one that was at the back, so `y R y'` is `B`. This is
    /// the property a frame-blind model gets wrong, and it gets it wrong
    /// silently.
    @Test
    def conjugatingATurnByARotationRenamesTheFace(): Unit \ Assert =
        same(3, "y R y'", "B");
        same(3, "y' R y", "F");
        same(3, "x U x'", "F");
        same(3, "z R z'", "U")

    /// Rotations are available on a 2x2x2 too -- it has no fixed centres, but
    /// the frame is still meaningful to a caller who reads facelets.
    @Test
    def rotationsWorkOnAPocketCube(): Unit \ Assert =
        Assert.assertTrue(Cube.isSolved(afterMoves(2, "x y z")));
        Assert.assertEq(expected = Rotation.x(), Cube.orientation(afterMoves(2, "x")))

    // ---------- slice moves ----------

    /// The identity that defines the M slice: turning the R layer, the middle
    /// slice the other way, and the L layer the other way is exactly a
    /// whole-cube rotation.
    @Test
    def theSliceIdentitiesHold(): Unit \ Assert =
        same(3, "R M' L'", "x");
        same(3, "U E' D'", "y");
        same(3, "F S B'", "z")

    /// Wide turns are a layer turn and a slice turn together.
    @Test
    def theWideTurnIdentitiesHold(): Unit \ Assert =
        same(3, "r", "R M'");
        same(3, "l", "L M");
        same(3, "u", "U E'");
        same(3, "d", "D E");
        same(3, "f", "F S");
        same(3, "b", "B S'")

    /// The WCA spelling and the lowercase spelling are the same move.
    @Test
    def wideTurnsAcceptBothSpellings(): Unit \ Assert =
        same(3, "Rw", "r");
        same(3, "Uw2", "u2");
        same(3, "Fw'", "f'")

    @Test
    def sliceAndWideMovesHaveOrderFour(): Unit \ Assert =
        List.forEach(t -> {
            let c = afterMoves(3, "${t} ${t} ${t} ${t}");
            Assert.assertTrueWithMsg(Cube.isSolved(c), "${t} four times should solve");
            Assert.assertEqWithMsg(expected = Rotation.identity(), Cube.orientation(c),
                "${t} four times should restore the frame")
        }, "M" :: "E" :: "S" :: "r" :: "u" :: "f" :: Nil)

    @Test
    def aSliceMoveAndItsInverseCancel(): Unit \ Assert =
        List.forEach(t -> Assert.assertTrue(Cube.isSolved(afterMoves(3, "${t} ${t}'"))),
            "M" :: "E" :: "S" :: "r" :: "l" :: "u" :: "d" :: "f" :: "b" :: "x" :: "y" :: "z" :: Nil)

    /// A slice move really does disturb the cube -- a wrong expansion that
    /// cancelled to nothing would pass every test above.
    @Test
    def aSliceMoveIsNotTheIdentity(): Unit \ Assert =
        Assert.assertFalse(Cube.isSolved(afterMoves(3, "M")));
        Assert.assertFalse(Cube.isSolved(afterMoves(3, "E")));
        Assert.assertFalse(Cube.isSolved(afterMoves(3, "S")))

    /// A slice move shows up in the coordinates as two *outer* layer turns, and
    /// that is not a bug.
    ///
    /// Physically M moves four edges and four centres and no corner at all. But
    /// coordinates describe the cube rotated back upright, and a slice move
    /// rotates the frame; undoing that rotation carries the two outer layers
    /// with it. So in canonical coordinates M is `R L'` -- all eight corners
    /// move -- while the frame carries the difference. The faithful thing is
    /// the pair, never the arrangement alone.
    ///
    /// Pinned here so that a future reader who notices the surprising corner
    /// motion and "fixes" it fails this test and reads this comment.
    @Test
    def aSliceMoveShowsAsOuterLayersInCanonicalCoordinates(): Unit \ Assert =
        use Orbit64.Coord.Coord.CornerCoord;
        same(3, "M", "R L' x'");
        // the arrangement alone does not identify the move: M and R L' agree on
        // it and differ only in the frame.
        Assert.assertEq(
            expected = Cube.orbits(afterMoves(3, "R L'")),
            Cube.orbits(afterMoves(3, "M"))
        );
        Assert.assertNeq(
            unexpected = Cube.orientation(afterMoves(3, "R L'")),
            Cube.orientation(afterMoves(3, "M"))
        );
        // and all eight corners really have moved in this representation
        match Cube.orbits(afterMoves(3, "M")) {
            case CornerCoord(cp, _) :: _ =>
                Assert.assertEq(
                    expected = 8,
                    Vector.count(i -> Vector.get(i, cp) != i, Vector.range(0, 8))
                )
            case _ => Assert.assertTrueWithMsg(false, "a 3x3x3 has a corner orbit")
        }

    // ---------- sizes without a middle slice ----------

    /// A 2x2x2 has no middle layer, so M names nothing. Saying that is better
    /// than inventing an interpretation.
    @Test
    def sliceMovesAreRefusedWhereThereIsNoMiddleLayer(): Unit \ Assert =
        match Cube.solved(2) |> Result.flatMap(c -> Cube.applyNotation("M", c)) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "a 2x2x2 has no middle slice")
            case Err(e) => Assert.assertTrue(String.contains(substr = "2x2x2", e))
        }

    @Test
    def parseRejectsUnknownTokensByName(): Unit \ Assert =
        Assert.assertErr(Notation.parse(3, "R U Q"));
        Assert.assertErr(Notation.parse(3, "M0"));
        Assert.assertErr(Notation.parse(3, "Rw-1"));
        // `M3` and `Rw3` were refused while a suffix could only be `2` or `'`.
        // A repeat count is now a count, so three of a quarter turn is three of
        // a quarter turn -- the same relaxation that lets `(M z)4` be written.
        Assert.assertOk(Notation.parse(3, "M3"));
        Assert.assertOk(Notation.parse(3, "Rw3"))

    // ---------- expressing a solution in the caller's frame ----------

    /// A sequence applied after a rotation, then re-expressed in the frame the
    /// caller started in, must have the same effect as applying it there. This
    /// is the whole reason the frame is tracked.
    @Test
    def aSequenceReExpressedInTheInitialFrameHasTheSameEffect(): Unit \ Assert =
        let rotated = afterMoves(3, "y");
        match Notation.parse(3, "R U2 F'") |> Result.map(Notation.layersOnly) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "parses")
            case Ok(ms) =>
                // applied in the rotated frame
                let after = Cube.applyAll(ms, rotated);
                // the same moves renamed into the initial frame, applied there
                let renamed = ms |> List.map(m -> Rotation.reframe(m, Cube.orientation(rotated)));
                let direct = Cube.solved(3) |> Result.flatMap(c -> Cube.applyAll(renamed, c));
                Assert.assertEq(
                    expected = after |> Result.map(Cube.orbits),
                    direct |> Result.map(Cube.orbits)
                )
        }

}
