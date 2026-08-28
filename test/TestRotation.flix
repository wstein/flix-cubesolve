mod TestRotation {

    use CubeSolve.Model.Move
    use CubeSolve.Model.Rotation
    use CubeSolve.Model.Move.Face.{U, R, F, D, L, B}

    /// The rotation group of the cube has 24 elements, and the closure of the
    /// three axis rotations is the whole of it -- not a subgroup and not more.
    @Test
    def theRotationGroupHasExactlyTwentyFourElements(): Unit \ Assert =
        Assert.assertEq(expected = 24, Vector.length(Rotation.all()))

    @Test
    def theGeneratorsAreDistinctAndNoneIsTheIdentity(): Unit \ Assert =
        let i = Rotation.identity();
        Assert.assertNeq(unexpected = i, Rotation.x());
        Assert.assertNeq(unexpected = i, Rotation.y());
        Assert.assertNeq(unexpected = i, Rotation.z());
        Assert.assertNeq(unexpected = Rotation.x(), Rotation.y());
        Assert.assertNeq(unexpected = Rotation.y(), Rotation.z())

    @Test
    def everyGeneratorHasOrderFour(): Unit \ Assert =
        Vector#{Rotation.x(), Rotation.y(), Rotation.z()} |> Vector.forEach(g -> {
            let g2 = Rotation.andThen(g, g);
            let g4 = Rotation.andThen(g2, g2);
            Assert.assertNeq(unexpected = Rotation.identity(), g2);
            Assert.assertEq(expected = Rotation.identity(), g4)
        })

    @Test
    def identityIsNeutralOnBothSides(): Unit \ Assert =
        let i = Rotation.identity();
        Rotation.all() |> Vector.forEach(r -> {
            Assert.assertEq(expected = r, Rotation.andThen(r, i));
            Assert.assertEq(expected = r, Rotation.andThen(i, r))
        })

    @Test
    def everyRotationHasAnInverse(): Unit \ Assert =
        Rotation.all() |> Vector.forEach(r -> {
            let inv = Rotation.inverse(r);
            Assert.assertEq(expected = Rotation.identity(), Rotation.andThen(r, inv));
            Assert.assertEq(expected = Rotation.identity(), Rotation.andThen(inv, r));
            Assert.assertEq(expected = r, Rotation.inverse(Rotation.inverse(r)))
        })

    /// Composition stays inside the group. A face map that escaped would mean
    /// the generators were wrong.
    @Test
    def compositionIsClosed(): Unit \ Assert =
        Rotation.all() |> Vector.forEach(a ->
            Rotation.all() |> Vector.forEach(b ->
                Assert.assertTrue(Vector.memberOf(Rotation.andThen(a, b), Rotation.all()))))

    /// The action on the six faces is faithful: only the identity fixes every
    /// face. This is what lets a rotation be represented by its face map alone.
    @Test
    def onlyTheIdentityFixesEveryFace(): Unit \ Assert =
        Rotation.all() |> Vector.forEach(r ->
            Assert.assertEq(
                expected = r == Rotation.identity(),
                Rotation.faceMap(r) == Vector.range(0, 6)
            ))

    /// A rotation never turns a face into a face it is not adjacent to in the
    /// right way: opposite faces stay opposite.
    @Test
    def rotationsPreserveOppositeFacePairs(): Unit \ Assert =
        Rotation.all() |> Vector.forEach(r -> {
            let m = Rotation.faceMap(r);
            Vector.range(0, 6) |> Vector.forEach(i ->
                Assert.assertEq(
                    expected = Int32.modulo(Vector.get(i, m) + 3, 6),
                    Vector.get(Int32.modulo(i + 3, 6), m)
                ))
        })

    /// x carries the front face onto the top, which is the direction an R turn
    /// goes. Pins the generator's sense, which the group laws cannot.
    @Test
    def xCarriesFrontToTopAndFixesTheRightAndLeftFaces(): Unit \ Assert =
        let m = Rotation.faceMap(Rotation.x());
        Assert.assertEq(expected = Move.faceIndex(F), Vector.get(0, m));
        Assert.assertEq(expected = Move.faceIndex(R), Vector.get(1, m));
        Assert.assertEq(expected = Move.faceIndex(L), Vector.get(4, m))

    /// y carries the right face onto the front, the direction a U turn goes.
    @Test
    def yCarriesRightToFrontAndFixesTopAndBottom(): Unit \ Assert =
        let m = Rotation.faceMap(Rotation.y());
        Assert.assertEq(expected = Move.faceIndex(R), Vector.get(2, m));
        Assert.assertEq(expected = Move.faceIndex(U), Vector.get(0, m));
        Assert.assertEq(expected = Move.faceIndex(D), Vector.get(3, m))

    /// z carries the left face onto the top, the direction an F turn goes.
    @Test
    def zCarriesLeftToTopAndFixesFrontAndBack(): Unit \ Assert =
        let m = Rotation.faceMap(Rotation.z());
        Assert.assertEq(expected = Move.faceIndex(L), Vector.get(0, m));
        Assert.assertEq(expected = Move.faceIndex(F), Vector.get(2, m));
        Assert.assertEq(expected = Move.faceIndex(B), Vector.get(5, m))

    /// Turning a face named in the rotated frame is turning a different face in
    /// the original one. This is the whole point of tracking the frame: it is
    /// how a solution found after a rotation is expressed back to the caller.
    @Test
    def reframingRenamesTheFaceButKeepsTheAmount(): Unit \ Assert =
        use CubeSolve.Model.Move.Move.Turn;
        let m = Rotation.reframe(Turn(U, 2), Rotation.x());
        Assert.assertEq(expected = F, Move.face(m));
        Assert.assertEq(expected = 2, Move.amount(m));
        Rotation.all() |> Vector.forEach(r ->
            Move.all() |> Vector.forEach(mv ->
                Assert.assertEq(
                    expected = Move.amount(mv),
                    Move.amount(Rotation.reframe(mv, r))
                )))

    /// Reframing by a rotation and then by its inverse is a no-op.
    @Test
    def reframingRoundTrips(): Unit \ Assert =
        Rotation.all() |> Vector.forEach(r ->
            Move.all() |> Vector.forEach(mv ->
                Assert.assertEq(
                    expected = mv,
                    Rotation.reframe(Rotation.reframe(mv, r), Rotation.inverse(r))
                )))

}
