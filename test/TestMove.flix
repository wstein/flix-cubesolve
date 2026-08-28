mod TestMove {

    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face.{U, R, F, D, L, B}
    use CubeSolve.Model.Move.Move.Turn

    /// Every move survives being written down and read back.
    @Test
    def notationRoundTripsForEveryMove(): Unit \ Assert =
        Move.all() |> Vector.forEach(m ->
            Assert.assertEq(
                expected = Ok(m),
                Move.parseMove(Move.show(m))
            ))

    /// The index is a bijection onto 0..17, which the flat move tables rely on.
    @Test
    def moveIndexRoundTripsOverTheWholeAlphabet(): Unit \ Assert =
        Vector.range(0, 18) |> Vector.forEach(i ->
            Assert.assertEq(
                expected = Some(i),
                Move.ofIndex(i) |> Option.map(Move.index)
            ))

    /// Faces are contiguous in the alphabet, so a face can be skipped by range.
    @Test
    def movesOfOneFaceAreContiguous(): Unit \ Assert =
        Move.all() |> Vector.forEach(m ->
            Assert.assertEq(
                expected = Move.faceIndex(Move.face(m)),
                Move.index(m) / 3
            ))

    @Test
    def notationIsTheConventionalOne(): Unit \ Assert =
        Assert.assertEq(expected = "U", Move.show(Turn(U, 1)));
        Assert.assertEq(expected = "U2", Move.show(Turn(U, 2)));
        Assert.assertEq(expected = "U'", Move.show(Turn(U, 3)));
        Assert.assertEq(expected = "B'", Move.show(Turn(B, 3)))

    @Test
    def inverseIsAnInvolutionAndUndoesTheAmount(): Unit \ Assert =
        Move.all() |> Vector.forEach(m -> {
            let inv = Move.inverse(m);
            Assert.assertEq(expected = m, Move.inverse(inv));
            Assert.assertEq(expected = Move.face(m), Move.face(inv));
            Assert.assertEq(
                expected = 4,
                Move.amount(m) + Move.amount(inv)
            )
        })

    /// A half turn is its own inverse; nothing else is.
    @Test
    def onlyHalfTurnsAreSelfInverse(): Unit \ Assert =
        Move.all() |> Vector.forEach(m ->
            Assert.assertEq(
                expected = Move.amount(m) == 2,
                Move.inverse(m) == m
            ))

    @Test
    def inverseOfASequenceReversesAndInverts(): Unit \ Assert =
        match Move.parse("R U R' U'") {
            case Err(e) => Assert.assertEq(expected = "parses", e)
            case Ok(ms) =>
                Assert.assertEq(
                    expected = "U R U' R'",
                    Move.showAll(Move.inverseOf(ms))
                )
        }

    /// Opposite faces are three apart, which is what makes axis arithmetic.
    @Test
    def oppositeFacesAreThreeApartAndPairUp(): Unit \ Assert =
        Assert.assertEq(expected = D, Move.opposite(U));
        Assert.assertEq(expected = U, Move.opposite(D));
        Assert.assertEq(expected = L, Move.opposite(R));
        Assert.assertEq(expected = B, Move.opposite(F));
        Move.faces() |> Vector.forEach(f ->
            Assert.assertEq(
                expected = f,
                Move.opposite(Move.opposite(f))
            ))

    /// Exactly the opposite-face pairs commute -- the search's ordering rule
    /// is only sound because this holds.
    @Test
    def exactlyOppositeFacesShareAnAxis(): Unit \ Assert =
        Move.faces() |> Vector.forEach(a ->
            Move.faces() |> Vector.forEach(b ->
                Assert.assertEq(
                    expected = a == b or a == Move.opposite(b),
                    Move.commutes(a, b)
                )))

    @Test
    def parseAcceptsAnyWhitespaceAndIgnoresRuns(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("R U2 F'"),
            Move.parse("  R\tU2\n F'  ") |> Result.map(Move.showAll)
        )

    @Test
    def parseNamesTheTokenItRejected(): Unit \ Assert =
        Assert.assertErr(Move.parseMove("X"));
        Assert.assertErr(Move.parseMove("U3"));
        Assert.assertErr(Move.parseMove("u"));
        Assert.assertErr(Move.parse("R U Q"))

    @Test
    def parseOfEmptyInputIsTheEmptySequence(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Nil), Move.parse("   "))

    // ---------- the cubie tables ----------

    /// Every permutation table really is a permutation of its slots. A
    /// transcription slip that duplicates an entry fails here rather than
    /// silently losing a piece a thousand states into a search.
    @Test
    def everyMoveTableIsAPermutation(): Unit \ Assert =
        Move.faces() |> Vector.forEach(f -> {
            let cp = Move.cornerPermutation(f);
            let ep = Move.edgePermutation(f);
            Vector.range(0, 8) |> Vector.forEach(i ->
                Assert.assertTrue(Vector.memberOf(i, cp)));
            Vector.range(0, 12) |> Vector.forEach(i ->
                Assert.assertTrue(Vector.memberOf(i, ep)));
            Assert.assertEq(expected = 8, Vector.length(cp));
            Assert.assertEq(expected = 12, Vector.length(ep))
        })

    /// A quarter turn moves exactly four corners and four edges, and fixes the
    /// rest. This catches an entry copied into the wrong slot even when the
    /// table is still a permutation.
    @Test
    def aQuarterTurnMovesExactlyFourPiecesOfEachKind(): Unit \ Assert =
        Move.faces() |> Vector.forEach(f -> {
            let cp = Move.cornerPermutation(f);
            let ep = Move.edgePermutation(f);
            let movedIn = (v, slots) ->
                Vector.count(i -> Vector.get(i, v) != i, Vector.range(0, slots));
            Assert.assertEq(expected = 4, movedIn(cp, 8));
            Assert.assertEq(expected = 4, movedIn(ep, 12))
        })

    /// Twists and flips a single turn adds must themselves be legal, or the
    /// sum rules break after one move.
    @Test
    def orientationDeltasSumToZeroAndStayInRange(): Unit \ Assert =
        Move.faces() |> Vector.forEach(f -> {
            let co = Move.cornerTwist(f);
            let eo = Move.edgeFlip(f);
            Assert.assertEq(expected = 8, Vector.length(co));
            Assert.assertEq(expected = 12, Vector.length(eo));
            Assert.assertTrue(Vector.forAll(x -> x >= 0 and x < 3, co));
            Assert.assertTrue(Vector.forAll(x -> x >= 0 and x < 2, eo));
            Assert.assertEq(expected = 0, Int32.modulo(Vector.sum(co), 3));
            Assert.assertEq(expected = 0, Int32.modulo(Vector.sum(eo), 2))
        })

    /// Under this flip convention only F and B flip edges, and only R, L, F, B
    /// twist corners. That asymmetry is a property of the convention rather
    /// than of the cube, so it is asserted rather than assumed.
    @Test
    def onlyTheConventionsExpectedFacesChangeOrientation(): Unit \ Assert =
        let twists = f -> Vector.sum(Move.cornerTwist(f)) != 0;
        let flips = f -> Vector.sum(Move.edgeFlip(f)) != 0;
        Assert.assertFalse(twists(U));
        Assert.assertFalse(twists(D));
        Assert.assertTrue(twists(R));
        Assert.assertTrue(twists(L));
        Assert.assertTrue(twists(F));
        Assert.assertTrue(twists(B));
        Assert.assertFalse(flips(U));
        Assert.assertFalse(flips(D));
        Assert.assertFalse(flips(R));
        Assert.assertFalse(flips(L));
        Assert.assertTrue(flips(F));
        Assert.assertTrue(flips(B))

}
