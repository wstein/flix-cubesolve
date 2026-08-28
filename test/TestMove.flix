mod TestMove {

    use CubeSolve.Model.Move.{Face, Move}
    use CubeSolve.Model.Move.Face.{U, R, F, D, L, B}
    use CubeSolve.Model.Move.Move.Turn

    /// Every move survives being written down and read back.
    @Test
    def notationRoundTripsForEveryMove(): Unit \ Assert =
        CubeSolve.Model.Move.all() |> Vector.forEach(m ->
            Assert.assertEq(
                expected = Ok(m),
                CubeSolve.Model.Move.parseMove(CubeSolve.Model.Move.show(m))
            ))

    /// The index is a bijection onto 0..17, which the flat move tables rely on.
    @Test
    def moveIndexRoundTripsOverTheWholeAlphabet(): Unit \ Assert =
        Vector.range(0, 18) |> Vector.forEach(i ->
            Assert.assertEq(
                expected = Some(i),
                CubeSolve.Model.Move.ofIndex(i) |> Option.map(CubeSolve.Model.Move.index)
            ))

    /// Faces are contiguous in the alphabet, so a face can be skipped by range.
    @Test
    def movesOfOneFaceAreContiguous(): Unit \ Assert =
        CubeSolve.Model.Move.all() |> Vector.forEach(m ->
            Assert.assertEq(
                expected = CubeSolve.Model.Move.faceIndex(CubeSolve.Model.Move.face(m)),
                CubeSolve.Model.Move.index(m) / 3
            ))

    @Test
    def notationIsTheConventionalOne(): Unit \ Assert =
        Assert.assertEq(expected = "U", CubeSolve.Model.Move.show(Turn(U, 1)));
        Assert.assertEq(expected = "U2", CubeSolve.Model.Move.show(Turn(U, 2)));
        Assert.assertEq(expected = "U'", CubeSolve.Model.Move.show(Turn(U, 3)));
        Assert.assertEq(expected = "B'", CubeSolve.Model.Move.show(Turn(B, 3)))

    @Test
    def inverseIsAnInvolutionAndUndoesTheAmount(): Unit \ Assert =
        CubeSolve.Model.Move.all() |> Vector.forEach(m -> {
            let inv = CubeSolve.Model.Move.inverse(m);
            Assert.assertEq(expected = m, CubeSolve.Model.Move.inverse(inv));
            Assert.assertEq(expected = CubeSolve.Model.Move.face(m), CubeSolve.Model.Move.face(inv));
            Assert.assertEq(
                expected = 4,
                CubeSolve.Model.Move.amount(m) + CubeSolve.Model.Move.amount(inv)
            )
        })

    /// A half turn is its own inverse; nothing else is.
    @Test
    def onlyHalfTurnsAreSelfInverse(): Unit \ Assert =
        CubeSolve.Model.Move.all() |> Vector.forEach(m ->
            Assert.assertEq(
                expected = CubeSolve.Model.Move.amount(m) == 2,
                CubeSolve.Model.Move.inverse(m) == m
            ))

    @Test
    def inverseOfASequenceReversesAndInverts(): Unit \ Assert =
        match CubeSolve.Model.Move.parse("R U R' U'") {
            case Err(e) => Assert.assertEq(expected = "parses", e)
            case Ok(ms) =>
                Assert.assertEq(
                    expected = "U R U' R'",
                    CubeSolve.Model.Move.showAll(CubeSolve.Model.Move.inverseOf(ms))
                )
        }

    /// Opposite faces are three apart, which is what makes axis arithmetic.
    @Test
    def oppositeFacesAreThreeApartAndPairUp(): Unit \ Assert =
        Assert.assertEq(expected = D, CubeSolve.Model.Move.opposite(U));
        Assert.assertEq(expected = U, CubeSolve.Model.Move.opposite(D));
        Assert.assertEq(expected = L, CubeSolve.Model.Move.opposite(R));
        Assert.assertEq(expected = B, CubeSolve.Model.Move.opposite(F));
        CubeSolve.Model.Move.faces() |> Vector.forEach(f ->
            Assert.assertEq(
                expected = f,
                CubeSolve.Model.Move.opposite(CubeSolve.Model.Move.opposite(f))
            ))

    /// Exactly the opposite-face pairs commute -- the search's ordering rule
    /// is only sound because this holds.
    @Test
    def exactlyOppositeFacesShareAnAxis(): Unit \ Assert =
        CubeSolve.Model.Move.faces() |> Vector.forEach(a ->
            CubeSolve.Model.Move.faces() |> Vector.forEach(b ->
                Assert.assertEq(
                    expected = a == b or a == CubeSolve.Model.Move.opposite(b),
                    CubeSolve.Model.Move.commutes(a, b)
                )))

    @Test
    def parseAcceptsAnyWhitespaceAndIgnoresRuns(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("R U2 F'"),
            CubeSolve.Model.Move.parse("  R\tU2\n F'  ") |> Result.map(CubeSolve.Model.Move.showAll)
        )

    @Test
    def parseNamesTheTokenItRejected(): Unit \ Assert =
        Assert.assertErr(CubeSolve.Model.Move.parseMove("X"));
        Assert.assertErr(CubeSolve.Model.Move.parseMove("U3"));
        Assert.assertErr(CubeSolve.Model.Move.parseMove("u"));
        Assert.assertErr(CubeSolve.Model.Move.parse("R U Q"))

    @Test
    def parseOfEmptyInputIsTheEmptySequence(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Nil), CubeSolve.Model.Move.parse("   "))

    // ---------- the cubie tables ----------

    /// Every permutation table really is a permutation of its slots. A
    /// transcription slip that duplicates an entry fails here rather than
    /// silently losing a piece a thousand states into a search.
    @Test
    def everyMoveTableIsAPermutation(): Unit \ Assert =
        CubeSolve.Model.Move.faces() |> Vector.forEach(f -> {
            let cp = CubeSolve.Model.Move.cornerPermutation(f);
            let ep = CubeSolve.Model.Move.edgePermutation(f);
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
        CubeSolve.Model.Move.faces() |> Vector.forEach(f -> {
            let cp = CubeSolve.Model.Move.cornerPermutation(f);
            let ep = CubeSolve.Model.Move.edgePermutation(f);
            Assert.assertEq(expected = 4, Vector.count(i -> Vector.get(i, cp) != i, Vector.range(0, 8)));
            Assert.assertEq(expected = 4, Vector.count(i -> Vector.get(i, ep) != i, Vector.range(0, 12)))
        })

    /// Twists and flips a single turn adds must themselves be legal, or the
    /// sum rules break after one move.
    @Test
    def orientationDeltasSumToZeroAndStayInRange(): Unit \ Assert =
        CubeSolve.Model.Move.faces() |> Vector.forEach(f -> {
            let co = CubeSolve.Model.Move.cornerTwist(f);
            let eo = CubeSolve.Model.Move.edgeFlip(f);
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
        let twists = f -> Vector.sum(CubeSolve.Model.Move.cornerTwist(f)) != 0;
        let flips = f -> Vector.sum(CubeSolve.Model.Move.edgeFlip(f)) != 0;
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
