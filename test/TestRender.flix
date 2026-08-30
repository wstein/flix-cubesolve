///
/// Drawing a cube as a net.
///
mod TestRender {

    use CubeSolve.Model.Cube
    use CubeSolve.Render

    def made(size: Int32, alg: String): Cube.Cube \ Assert =
        match Cube.solved(size) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    def drawn(f: Cube.Cube -> Result[String, String], c: Cube.Cube): String \ Assert =
        match f(c) {
            case Ok(text) => text
            case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "rendering"); ""
        }

    ///
    /// A solved cube draws as the net everyone prints: `U` above, `L F R B`
    /// around, `D` below.
    ///
    @Test
    def aSolvedCubeDrawsAsTheFamiliarCross(): Unit \ Assert =
        let expected = List.join(String.lineSeparator(),
            "            ┌───┬───┬───┐"
                :: "            │ U │ U │ U │"
                :: "            ├───┼───┼───┤"
                :: "            │ U │ U │ U │"
                :: "            ├───┼───┼───┤"
                :: "            │ U │ U │ U │"
                :: "┌───┬───┬───┼───┼───┼───┼───┬───┬───┬───┬───┬───┐"
                :: "│ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "└───┴───┴───┼───┼───┼───┼───┴───┴───┴───┴───┴───┘"
                :: "            │ D │ D │ D │"
                :: "            ├───┼───┼───┤"
                :: "            │ D │ D │ D │"
                :: "            ├───┼───┼───┤"
                :: "            │ D │ D │ D │"
                :: "            └───┴───┴───┘" :: Nil);
        Assert.assertEq(expected = expected, drawn(Render.net, made(3, "U U'")))

    ///
    /// A 2x2x2 draws the same shape, two stickers to a side.
    ///
    @Test
    def aSolvedPocketCubeDrawsTheSameShapeSmaller(): Unit \ Assert =
        let expected = List.join(String.lineSeparator(),
            "        ┌───┬───┐"
                :: "        │ U │ U │"
                :: "        ├───┼───┤"
                :: "        │ U │ U │"
                :: "┌───┬───┼───┼───┼───┬───┬───┐"
                :: "│ L │ L │ F │ F │ R │ R │ B │ B │"
                :: "├───┼───┼───┼───┼───┼───┼───┤"
                :: "│ L │ L │ F │ F │ R │ R │ B │ B │"
                :: "└───┴───┼───┼───┼───┴───┴───┘"
                :: "        │ D │ D │"
                :: "        ├───┼───┤"
                :: "        │ D │ D │"
                :: "        └───┴───┘" :: Nil);
        Assert.assertEq(expected = expected, drawn(Render.net, made(2, "U U'")))

    ///
    /// One quarter turn moves exactly the stickers it should.
    ///
    /// `U` takes the top row of each side face to the next one round. Checking a
    /// move rather than only the solved cube is what pins the facelet order: a
    /// renderer that read the faces in the wrong order would still draw a solved
    /// cube perfectly.
    ///
    @Test
    def aQuarterTurnMovesTheStickersItShould(): Unit \ Assert =
        let expected = List.join(String.lineSeparator(),
            "            ┌───┬───┬───┐"
                :: "            │ U │ U │ U │"
                :: "            ├───┼───┼───┤"
                :: "            │ U │ U │ U │"
                :: "            ├───┼───┼───┤"
                :: "            │ U │ U │ U │"
                :: "┌───┬───┬───┼───┼───┼───┼───┬───┬───┬───┬───┬───┐"
                :: "│ F │ F │ F │ R │ R │ R │ B │ B │ B │ L │ L │ L │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "└───┴───┴───┼───┼───┼───┼───┴───┴───┴───┴───┴───┘"
                :: "            │ D │ D │ D │"
                :: "            ├───┼───┼───┤"
                :: "            │ D │ D │ D │"
                :: "            ├───┼───┼───┤"
                :: "            │ D │ D │ D │"
                :: "            └───┴───┴───┘" :: Nil);
        Assert.assertEq(expected = expected, drawn(Render.net, made(3, "U")))

    ///
    /// Colour is added over the plain drawing and changes nothing else.
    ///
    /// Stripping the escapes must give back the plain net exactly. That is what
    /// makes the coloured form safe to pipe into a file or read without colour:
    /// the answer is in the letters, and the colour is decoration.
    ///
    @Test
    def colourIsDecorationOverTheSameLetters(): Unit \ Assert =
        Vector#{"U U'", "R U R' U'", "F2 B2 L2"} |> Vector.forEach(alg -> {
            let c = made(3, alg);
            let plain = drawn(Render.net, c);
            let coloured = drawn(Render.colouredNet, c);
            Assert.assertTrueWithMsg(String.length(coloured) > String.length(plain),
                "'${alg}': the coloured form should carry escapes");
            Assert.assertEqWithMsg(expected = plain, stripped(coloured),
                "'${alg}': stripping the colour should give back the plain net")
        })

    ///
    /// `text` with every ANSI escape sequence removed.
    ///
    /// An escape runs from the escape character to the `m` that ends it, which
    /// is the only form this renderer emits.
    ///
    def stripped(text: String): String =
        String.split(regex = Render.escape() + "\\[[0-9;]*m", text) |> List.join("")

}
