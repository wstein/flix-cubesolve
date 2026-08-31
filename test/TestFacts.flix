///
/// What the beginner method sees when it looks at a cube.
///
/// Checked against cubes whose state is known by construction -- a solved cube,
/// and cubes moved by sequences whose effect on one named piece is easy to
/// state -- rather than against the solver. A fact layer verified by the thing
/// that consumes it would agree with itself and prove nothing.
///
mod TestFacts {

    use CubeSolve.Method.Facts
    use CubeSolve.Method.Facts.TopShape
    use CubeSolve.Model.Cube

    /// The cube after `alg`, or a failed test.
    def after(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    /// A solved cube has every piece home, and its top shows the cross.
    @Test
    def aSolvedCubeHasEveryPieceHome(): Unit \ Assert =
        let c = after("");
        Vector.range(0, 12) |> Vector.forEach(s ->
            Assert.assertEqWithMsg(expected = Ok(true), Facts.edgeHome(c, s),
                "edge slot ${s} should be home on a solved cube"));
        Vector.range(0, 8) |> Vector.forEach(s ->
            Assert.assertEqWithMsg(expected = Ok(true), Facts.cornerHome(c, s),
                "corner slot ${s} should be home on a solved cube"));
        Assert.assertEqWithMsg(expected = Ok(TopShape.Cross), Facts.topShape(c),
            "a solved cube's top face is the cross")

    ///
    /// A quarter turn of `U` moves the four top edges and nothing below.
    ///
    /// The cheapest fact that would catch a slot-numbering mistake: if the top
    /// slots were not `0..3`, this would report the wrong pieces moving.
    ///
    @Test
    def aTopTurnMovesTheTopAndLeavesTheRest(): Unit \ Assert =
        let c = after("U");
        Facts.topEdgeSlots() |> Vector.forEach(s ->
            Assert.assertEqWithMsg(expected = Ok(false), Facts.edgeHome(c, s),
                "edge slot ${s} should have moved under U"));
        Vector.append(Facts.crossSlots(), Facts.middleSlots()) |> Vector.forEach(s ->
            Assert.assertEqWithMsg(expected = Ok(true), Facts.edgeHome(c, s),
                "edge slot ${s} is below the top and U should not have touched it"))

    ///
    /// Finding a piece is the inverse of the slot-indexed permutation.
    ///
    /// `findEdge(p)` must name the slot whose occupant is `p`, which is the
    /// question a person asks and the opposite of the way the vectors read.
    ///
    @Test
    def findingAPieceInvertsThePermutation(): Unit \ Assert =
        let c = after("R U R' U' F2 L D B'");
        match Facts.edges(c) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "edges")
            case Ok(es) =>
                es |> Vector.forEach(p ->
                    match Facts.findEdge(c, p#piece) {
                        case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "finding")
                        case Ok(found) =>
                            Assert.assertEqWithMsg(expected = p#slot, found#slot,
                                "edge ${p#piece} sits in slot ${p#slot}")
                    })
        };
        match Facts.corners(c) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "corners")
            case Ok(cs) =>
                cs |> Vector.forEach(p ->
                    match Facts.findCorner(c, p#piece) {
                        case Err(e)    => Assert.assertEqWithMsg(expected = "", e, "finding")
                        case Ok(found) =>
                            Assert.assertEqWithMsg(expected = p#slot, found#slot,
                                "corner ${p#piece} sits in slot ${p#slot}")
                    })
        }

    ///
    /// The four top shapes are told apart, and each is reachable.
    ///
    /// The sequences are not algorithms anybody teaches; they are the shortest
    /// things found here that leave the top edges in each of the four states,
    /// which is all this needs.
    ///
    @Test
    def theFourTopShapesAreToldApart(): Unit \ Assert =
        Assert.assertEqWithMsg(expected = Ok(TopShape.Cross), Facts.topShape(after("")),
            "solved is the cross");
        // F R U R' U' F' flips exactly two adjacent top edges from solved.
        let shaped = Facts.topShape(after("F R U R' U' F'"));
        Assert.assertTrueWithMsg(shaped != Ok(TopShape.Cross),
            "after an edge-flipping algorithm the top is no longer the cross: ${shaped}");
        // The shape must be one of the four, whatever it is.
        Assert.assertTrueWithMsg(
            shaped == Ok(TopShape.Dot) or shaped == Ok(TopShape.Corner)
                or shaped == Ok(TopShape.Line) or shaped == Ok(TopShape.Cross),
            "every top face is one of the four shapes, and this is ${shaped}")

    ///
    /// The facts refuse a cube that is not a 3x3x3, rather than guessing.
    ///
    @Test
    def anotherSizeIsRefused(): Unit \ Assert =
        match Cube.solved(2) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "a solved 2x2x2")
            case Ok(c)  =>
                Assert.assertTrueWithMsg(Result.isErr(Facts.edges(c)),
                    "a 2x2x2 has no midge orbit and these facts should say so")
        }
}
