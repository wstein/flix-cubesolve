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
                :: "┌───┬───┼───┼───┼───┬───┬───┬───┐"
                :: "│ L │ L │ F │ F │ R │ R │ B │ B │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ L │ L │ F │ F │ R │ R │ B │ B │"
                :: "└───┴───┼───┼───┼───┴───┴───┴───┘"
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

    ///
    /// Rendered nets round-trip through `parse` identically for plain and coloured outputs.
    ///
    @Test
    def renderedNetsRoundTripThroughParse(): Unit \ Assert =
        let algs = "U U'" :: "U" :: "R U" :: "U R F" :: "R U R' U'" :: "F2 B2 L2 R2 U2 D2" :: Nil;
        algs |> List.forEach(alg -> {
            checkNetRoundTrip(3, alg);
            checkNetRoundTrip(2, alg)
        })

    ///
    /// Verify all 4 net formats round-trip through parse.
    ///
    def checkNetRoundTrip(size: Int32, alg: String): Unit \ Assert =
        let c = made(size, alg);
        Assert.assertEq(expected = Ok(c), Render.parse(drawn(Render.net, c)));
        Assert.assertEq(expected = Ok(c), Render.parse(drawn(Render.colouredNet, c)));
        Assert.assertEq(expected = Ok(c), Render.parse(drawn(Render.colorNet, c)));
        Assert.assertEq(expected = Ok(c), Render.parse(drawn(Render.colouredColorNet, c)))

    ///
    /// ASCII format nets parse identically to UTF-8 format.
    ///
    @Test
    def asciiNetsParseCorrectly(): Unit \ Assert =
        let asciiNet = List.join(String.lineSeparator(),
            "            +---+---+---+"
                :: "            | U | U | U |"
                :: "            +---+---+---+"
                :: "            | U | U | U |"
                :: "            +---+---+---+"
                :: "            | U | U | U |"
                :: "+---+---+---+---+---+---+---+---+---+---+---+---+"
                :: "| L | L | L | F | F | F | R | R | R | B | B | B |"
                :: "+---+---+---+---+---+---+---+---+---+---+---+---+"
                :: "| L | L | L | F | F | F | R | R | R | B | B | B |"
                :: "+---+---+---+---+---+---+---+---+---+---+---+---+"
                :: "| L | L | L | F | F | F | R | R | R | B | B | B |"
                :: "+---+---+---+---+---+---+---+---+---+---+---+---+"
                :: "            | D | D | D |"
                :: "            +---+---+---+"
                :: "            | D | D | D |"
                :: "            +---+---+---+"
                :: "            | D | D | D |"
                :: "            +---+---+---+" :: Nil);
        Assert.assertEq(expected = Ok(made(3, "U U'")), Render.parse(asciiNet))

    ///
    /// Standard color codes (W, G, Y, O, R, B) parse identically to face letters.
    ///
    @Test
    def colorCodesParseCorrectly(): Unit \ Assert =
        let colorNet = List.join(String.lineSeparator(),
            "            ┌───┬───┬───┐"
                :: "            │ W │ W │ W │"
                :: "            ├───┼───┼───┤"
                :: "            │ W │ W │ W │"
                :: "            ├───┼───┼───┤"
                :: "            │ W │ W │ W │"
                :: "┌───┬───┬───┼───┼───┼───┼───┬───┬───┬───┬───┬───┐"
                :: "│ O │ O │ O │ G │ G │ G │ R │ R │ R │ B │ B │ B │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ O │ O │ O │ G │ G │ G │ R │ R │ R │ B │ B │ B │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ O │ O │ O │ G │ G │ G │ R │ R │ R │ B │ B │ B │"
                :: "└───┴───┴───┼───┼───┼───┼───┴───┴───┴───┴───┴───┘"
                :: "            │ Y │ Y │ Y │"
                :: "            ├───┼───┼───┤"
                :: "            │ Y │ Y │ Y │"
                :: "            ├───┼───┼───┤"
                :: "            │ Y │ Y │ Y │"
                :: "            └───┴───┴───┘" :: Nil);
        Assert.assertEq(expected = Ok(made(3, "U U'")), Render.parse(colorNet))

    ///
    /// Numeric face indices (0-5) parse identically to face letters.
    ///
    @Test
    def numericIndicesParseCorrectly(): Unit \ Assert =
        let numNet = List.join(String.lineSeparator(),
            "            ┌───┬───┬───┐"
                :: "            │ 0 │ 0 │ 0 │"
                :: "            ├───┼───┼───┤"
                :: "            │ 0 │ 0 │ 0 │"
                :: "            ├───┼───┼───┤"
                :: "            │ 0 │ 0 │ 0 │"
                :: "┌───┬───┬───┼───┼───┼───┼───┬───┬───┬───┬───┬───┐"
                :: "│ 4 │ 4 │ 4 │ 2 │ 2 │ 2 │ 1 │ 1 │ 1 │ 5 │ 5 │ 5 │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ 4 │ 4 │ 4 │ 2 │ 2 │ 2 │ 1 │ 1 │ 1 │ 5 │ 5 │ 5 │"
                :: "├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "│ 4 │ 4 │ 4 │ 2 │ 2 │ 2 │ 1 │ 1 │ 1 │ 5 │ 5 │ 5 │"
                :: "└───┴───┴───┼───┼───┼───┼───┴───┴───┴───┴───┴───┘"
                :: "            │ 3 │ 3 │ 3 │"
                :: "            ├───┼───┼───┤"
                :: "            │ 3 │ 3 │ 3 │"
                :: "            ├───┼───┼───┤"
                :: "            │ 3 │ 3 │ 3 │"
                :: "            └───┴───┴───┘" :: Nil);
        Assert.assertEq(expected = Ok(made(3, "U U'")), Render.parse(numNet))

    ///
    /// Plain spaced nets without borders parse correctly.
    ///
    @Test
    def plainSpacedNetsParseCorrectly(): Unit \ Assert =
        let plainNet = List.join(String.lineSeparator(),
            "      U U U"
                :: "      U U U"
                :: "      U U U"
                :: "L L L F F F R R R B B B"
                :: "L L L F F F R R R B B B"
                :: "L L L F F F R R R B B B"
                :: "      D D D"
                :: "      D D D"
                :: "      D D D" :: Nil);
        Assert.assertEq(expected = Ok(made(3, "U U'")), Render.parse(plainNet))

    ///
    /// Compact unspaced nets parse correctly.
    ///
    @Test
    def compactNetsParseCorrectly(): Unit \ Assert =
        let compactNet = List.join(String.lineSeparator(),
            "    UUU"
                :: "    UUU"
                :: "    UUU"
                :: "LLLFFFRRRBBB"
                :: "LLLFFFRRRBBB"
                :: "LLLFFFRRRBBB"
                :: "    DDD"
                :: "    DDD"
                :: "    DDD" :: Nil);
        Assert.assertEq(expected = Ok(made(3, "U U'")), Render.parse(compactNet))

    ///
    /// Nets embedded in doc comments with markdown fences parse correctly.
    ///
    @Test
    def docCommentNetsParseCorrectly(): Unit \ Assert =
        let docNet = List.join(String.lineSeparator(),
            "/// ```"
                :: "///             ┌───┬───┬───┐"
                :: "///             │ U │ U │ U │"
                :: "///             ├───┼───┼───┤"
                :: "///             │ U │ U │ U │"
                :: "///             ├───┼───┼───┤"
                :: "///             │ U │ U │ U │"
                :: "/// ┌───┬───┬───┼───┼───┼───┼───┬───┬───┬───┬───┬───┐"
                :: "/// │ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "/// ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "/// │ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "/// ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤"
                :: "/// │ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │"
                :: "/// └───┴───┴───┼───┼───┼───┼───┴───┴───┴───┴───┴───┘"
                :: "///             │ D │ D │ D │"
                :: "///             ├───┼───┼───┤"
                :: "///             │ D │ D │ D │"
                :: "///             ├───┼───┼───┤"
                :: "///             │ D │ D │ D │"
                :: "///             └───┴───┴───┘"
                :: "/// ```" :: Nil);
        Assert.assertEq(expected = Ok(made(3, "U U'")), Render.parse(docNet))

    ///
    /// Flattened 54-character string in face order (U, R, F, D, L, B) parses correctly.
    ///
    @Test
    def flatFaceletStringsParseCorrectly(): Unit \ Assert =
        let flat = "UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB";
        Assert.assertEq(expected = Ok(made(3, "U U'")), Render.parse(flat))

    ///
    /// Malformed nets are rejected.
    ///
    @Test
    def malformedNetsAreRejected(): Unit \ Assert =
        Assert.assertErr(Render.parse(""));
        Assert.assertErr(Render.parse("invalid string with no net rows"));
        Assert.assertErr(Render.parse("│ U │ U │\n│ U │ U │\n│ D │ D │"))

    ///
    /// QR code generation produces non-empty UTF-8 block graphic encoding orbit64 token.
    ///
    @Test
    def qrCodeGeneratesNonEmptyUtf8Graphic(): Unit \ Assert =
        let c = made(3, "U R F");
        let qr = Render.qr(c) |> Result.getWithDefault("");
        let qrLight = Render.qrLight(c) |> Result.getWithDefault("");
        let qrTok = Render.qrWithToken(c, CubeSolve.Render.Qr.EcLevel.L)
            |> Result.getWithDefault("");
        let hasBlock = String.contains(substr = "█", qr) or String.contains(substr = "▀", qr);
        Assert.assertTrue(hasBlock);
        Assert.assertTrue(String.length(qrLight) > 0);
        Assert.assertTrue(String.length(qrTok) > String.length(qr))

    ///
    /// QR code generation supports all error correction levels (L, M, Q, H).
    ///
    @Test
    def qrCodeSupportsAllEcLevels(): Unit \ Assert =
        let c = made(3, "U R F");
        let levels = CubeSolve.Render.Qr.EcLevel.L :: CubeSolve.Render.Qr.EcLevel.M
            :: CubeSolve.Render.Qr.EcLevel.Q :: CubeSolve.Render.Qr.EcLevel.H :: Nil;
        levels |> List.forEach(lvl -> {
            let qr = Render.qrWith(c, lvl, true) |> Result.getWithDefault("");
            Assert.assertTrue(String.length(qr) > 0)
        })

    ///
    /// QR code with token centers the token string below the graphic.
    ///
    @Test
    def qrCodeCentersTokenBelow(): Unit \ Assert =
        let c = made(3, "U R F");
        let qrTok = Render.qrWithToken(c, CubeSolve.Render.Qr.EcLevel.H)
            |> Result.getWithDefault("");
        let lines = String.split(regex = "\r?\n", qrTok);
        let lastLine = match List.reverse(lines) {
            case last :: _ => last
            case Nil       => ""
        };
        Assert.assertTrue(String.startsWith(prefix = " ", lastLine))

    ///
    /// PNG QR code generation writes a readable PNG file with and without logo.
    ///
    @Test
    def qrCodeWritesPngFile(): Unit \ { Assert, IO } =
        let c = made(3, "U R F");
        let pathWith = "build/test_qr_logo.png";
        let pathWithout = "build/test_qr_nologo.png";
        Assert.assertEq(expected = Ok(()), Render.qrWritePng(pathWith, c, true));
        Assert.assertEq(expected = Ok(()), Render.qrWritePng(pathWithout, c, false))

    ///
    /// QR code generation with specific error correction levels produces expected dimensions.
    ///
    @Test
    def qrCodeDimensionsAcrossEcLevels(): Unit \ Assert =
        let c3 = made(3, "U R F");
        let c4 = made(4, "U R F");
        let qr3L = Render.qrWith(c3, CubeSolve.Render.Qr.EcLevel.L, true)
            |> Result.getWithDefault("");
        let qr3H = Render.qrWith(c3, CubeSolve.Render.Qr.EcLevel.H, true)
            |> Result.getWithDefault("");
        let lines3L = String.split(regex = "\r?\n", qr3L);
        let lines3H = String.split(regex = "\r?\n", qr3H);
        Assert.assertEq(expected = 15, List.length(lines3L));
        Assert.assertEq(expected = 17, List.length(lines3H));

        let qr4L = Render.qrWith(c4, CubeSolve.Render.Qr.EcLevel.L, true)
            |> Result.getWithDefault("");
        let qr4M = Render.qrWith(c4, CubeSolve.Render.Qr.EcLevel.M, true)
            |> Result.getWithDefault("");
        let qr4Q = Render.qrWith(c4, CubeSolve.Render.Qr.EcLevel.Q, true)
            |> Result.getWithDefault("");
        let qr4H = Render.qrWith(c4, CubeSolve.Render.Qr.EcLevel.H, true)
            |> Result.getWithDefault("");
        let lines4L = String.split(regex = "\r?\n", qr4L);
        let lines4M = String.split(regex = "\r?\n", qr4M);
        let lines4Q = String.split(regex = "\r?\n", qr4Q);
        let lines4H = String.split(regex = "\r?\n", qr4H);
        Assert.assertEq(expected = 17, List.length(lines4L));
        Assert.assertEq(expected = 19, List.length(lines4M));
        Assert.assertEq(expected = 19, List.length(lines4Q));
        Assert.assertEq(expected = 21, List.length(lines4H))

    ///
    /// QR code with full web URL produces valid UTF-8 graphic and PNG file.
    ///
    @Test
    def qrCodeWithUrlGeneratesValidMatrixAndFile(): Unit \ { Assert, IO } =
        let c = made(3, "U R F");
        let prefix = "https://cubesolve.org/#";
        let qr = Render.qrWithUrl(c, prefix, CubeSolve.Render.Qr.EcLevel.H)
            |> Result.getWithDefault("");
        let hasBlock = String.contains(substr = "█", qr) or String.contains(substr = "▀", qr);
        Assert.assertTrue(hasBlock);
        let path = "build/test_qr_url.png";
        Assert.assertEq(expected = Ok(()), Render.qrWritePngWithUrl(path, c, prefix, true))

}

