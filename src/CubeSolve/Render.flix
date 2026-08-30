///
/// Drawing a cube as an unfolded net.
///
/// **Pure, including the colours.** An ANSI escape is a string like any other,
/// so rendering produces text and printing it is somebody else's effect. That
/// keeps the layout testable without a terminal, and it is why the coloured form
/// can be checked by stripping the escapes and comparing against the plain one.
///
mod CubeSolve.Render {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets

    ///
    ///
    ///
    /// The net, as face letters.
    ///
    /// ```
    ///             ┌───┬───┬───┐
    ///             │ U │ U │ U │
    ///             ├───┼───┼───┤
    ///             │ U │ U │ U │
    ///             ├───┼───┼───┤
    ///             │ U │ U │ U │
    /// ┌───┬───┬───┼───┼───┼───┼───┬───┬───┬───┬───┬───┐
    /// │ L │ L │ L │ F │ F │ F │ R │ R │ R │ B │ B │ B │
    /// ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
    /// ...
    /// ```
    ///
    /// The cross is laid out `U` above, `L F R B` around the middle and `D`
    /// below, which is the arrangement every printed algorithm sheet uses.
    ///
    pub def net(c: Cube.Cube): Result[String, String] =
        draw(c, i -> " " + letterOf(i) + " ")

    ///
    /// The net in colour, for a terminal that understands 24-bit escapes.
    ///
    /// The sticker letter is kept inside the colour rather than replaced by a
    /// blank. A terminal without truecolor, a pipe into a file, or a reader who
    /// cannot distinguish the colours all still get the answer; only the
    /// prettiness is lost.
    ///
    pub def colouredNet(c: Cube.Cube): Result[String, String] =
        draw(c, i -> paint(i, " " + letterOf(i) + " "))

    ///
    /// The net, as color code letters: `W R G Y O B`.
    ///
    pub def colorNet(c: Cube.Cube): Result[String, String] =
        draw(c, i -> " " + colorLetterOf(i) + " ")

    ///
    /// The net in terminal color with color code letters (`W R G Y O B`).
    ///
    pub def colouredColorNet(c: Cube.Cube): Result[String, String] =
        draw(c, i -> paint(i, " " + colorLetterOf(i) + " "))

    ///
    /// Generate a compact UTF-8 graphic QR code encoding the cube's orbit64 token.
    ///
    pub def qr(c: Cube.Cube): Result[String, String] =
        Facelets.token(c) |> Result.map(Qr.render)

    ///
    /// Generate a compact UTF-8 QR code for light themes.
    ///
    pub def qrLight(c: Cube.Cube): Result[String, String] =
        Facelets.token(c) |> Result.map(Qr.renderLight)

    ///
    /// Generate a compact UTF-8 QR code with explicit EC level and theme choice.
    ///
    pub def qrWith(c: Cube.Cube, ec: Qr.EcLevel, darkTheme: Bool): Result[String, String] =
        Facelets.token(c) |> Result.map(tok -> Qr.renderWith(ec, darkTheme, tok))

    ///
    /// Generate a compact UTF-8 QR code with explicit EC level and the token centered below.
    ///
    pub def qrWithToken(c: Cube.Cube, ec: Qr.EcLevel): Result[String, String] =
        Facelets.token(c) |> Result.map(tok -> Qr.renderWithTokenAndEc(ec, true, tok))

    ///
    /// Generate a compact UTF-8 QR code with the token centered below (default Level L).
    ///
    pub def qrWithTokenL(c: Cube.Cube): Result[String, String] =
        Facelets.token(c) |> Result.map(Qr.renderWithToken)

    ///
    /// Write a high-resolution PNG QR code to `path` with optional real 3D cube logo.
    ///
    pub def qrWritePng(path: String, c: Cube.Cube, withLogo: Bool): Result[String, Unit] \ IO =
        match (Facelets.of(c), Facelets.token(c)) {
            case (Ok(fs), Ok(tok)) =>
                Qr.writeCubePng(path, Cube.size(c), fs, tok, withLogo)
            case (Err(e), _) => Err(e)
            case (_, Err(e)) => Err(e)
        }

    ///
    /// Render a compact UTF-8 QR code encoding a full web URL with the cube token.
    ///
    pub def qrWithUrl(c: Cube.Cube, urlPrefix: String, ec: Qr.EcLevel): Result[String, String] =
        Facelets.token(c) |> Result.map(tok ->
            Qr.renderWith(ec, true, urlPrefix + tok)
        )

    ///
    /// Write a high-resolution PNG QR code encoding a full web URL with optional real 3D cube logo.
    ///
    pub def qrWritePngWithUrl(
        path: String,
        c: Cube.Cube,
        urlPrefix: String,
        withLogo: Bool
    ): Result[String, Unit] \ IO =
        match (Facelets.of(c), Facelets.token(c)) {
            case (Ok(fs), Ok(tok)) =>
                Qr.writeCubePng(path, Cube.size(c), fs, urlPrefix + tok, withLogo)
            case (Err(e), _) => Err(e)
            case (_, Err(e)) => Err(e)
        }

    ///
    /// Write a standalone high-resolution 3D isometric cube icon PNG to `path` (transparent, 512px).
    ///
    pub def iconWritePng(path: String, c: Cube.Cube): Result[String, Unit] \ IO =
        iconWritePngWithOptions(path, c, 512, true)

    ///
    /// Write a standalone 3D isometric cube icon PNG with customizable dimensions and transparency.
    ///
    pub def iconWritePngWithOptions(
        path: String,
        c: Cube.Cube,
        imgSize: Int32,
        transparent: Bool
    ): Result[String, Unit] \ IO =
        Facelets.of(c) |> Result.flatMap(fs ->
            Icon.writePng(path, Cube.size(c), fs, imgSize, transparent)
        )

    ///
    /// Generate a compact UTF-8 graphic QR code from text.
    ///
    pub def qrOf(text: String): String =
        Qr.render(text)

    ///
    /// The letter for a face index, in the order `U R F D L B`.
    ///
    pub def letterOf(face: Int32): String = match face {
        case 0 => "U"
        case 1 => "R"
        case 2 => "F"
        case 3 => "D"
        case 4 => "L"
        case 5 => "B"
        case _ => "?"
    }

    ///
    /// The color code letter for a face index: White, Red, Green, Yellow, Orange, Blue.
    ///
    pub def colorLetterOf(face: Int32): String = match face {
        case 0 => "W"
        case 1 => "R"
        case 2 => "G"
        case 3 => "Y"
        case 4 => "O"
        case 5 => "B"
        case _ => "?"
    }

    ///
    /// `s` on the background colour that face is usually stickered.
    ///
    /// The Western scheme: white up, green front, red right, and so around.
    /// Orange is why these are 24-bit rather than the sixteen basic colours --
    /// there is no orange among them, and orange against red is the one
    /// distinction a cube renderer cannot afford to lose.
    ///
    pub def paint(face: Int32, s: String): String =
        let (r, g, b) = match face {
            case 0 => (245, 245, 245)
            case 1 => (200, 40, 40)
            case 2 => (30, 160, 70)
            case 3 => (240, 210, 40)
            case 4 => (235, 130, 30)
            case 5 => (40, 90, 200)
            case _ => (120, 120, 120)
        };
        "${escape()}[48;2;${r};${g};${b}m${escape()}[38;2;20;20;20m${s}${escape()}[0m"

    ///
    /// The escape character an ANSI sequence starts with.
    ///
    pub def escape(): String = Char.toString('\u001B')

    ///
    /// The net, with each sticker drawn by `sticker`.
    ///
    def draw(c: Cube.Cube, sticker: Int32 -> String): Result[String, String] =
        let n = Cube.size(c);
        let uIndent = String.repeat(4 * n, " ");
        let uTop = uIndent + "┌" + String.repeat(n - 1, "───┬") + "───┐";
        let uInner = uIndent + "├" + String.repeat(n - 1, "───┼") + "───┤";
        let topMid = "┌" + String.repeat(n - 1, "───┬") + "───┼"
            + String.repeat(n - 1, "───┼") + "───┼"
            + String.repeat(2 * n - 1, "───┬") + "───┐";
        let midInner = "├" + String.repeat(4 * n - 1, "───┼") + "───┤";
        let botMid = "└" + String.repeat(n - 1, "───┴") + "───┼"
            + String.repeat(n - 1, "───┼") + "───┼"
            + String.repeat(2 * n - 1, "───┴") + "───┘";
        let dBot = uIndent + "└" + String.repeat(n - 1, "───┴") + "───┘";
        Facelets.of(c) |> Result.map(fs -> {
            let uRows = List.range(0, n) |> List.flatMap(row -> {
                let top = if (row == 0) uTop else uInner;
                top :: (uIndent + "│" + rowOf(n, sticker, fs, 0, row)) :: Nil
            });
            let midRows = List.range(0, n) |> List.flatMap(row -> {
                let top = if (row == 0) topMid else midInner;
                top :: ("│" + ((4 :: 2 :: 1 :: 5 :: Nil)
                    |> List.map(f -> rowOf(n, sticker, fs, f, row))
                    |> List.join(""))) :: Nil
            });
            let dRows = List.range(0, n) |> List.flatMap(row -> {
                let bot = if (row == n - 1) dBot else uInner;
                (uIndent + "│" + rowOf(n, sticker, fs, 3, row)) :: bot :: Nil
            });
            List.append(uRows, List.append(midRows, botMid :: dRows))
                |> List.join(String.lineSeparator())
        })

    ///
    /// One row of one face.
    ///
    def rowOf(
        n: Int32,
        sticker: Int32 -> String,
        fs: Vector[Int32],
        face: Int32,
        row: Int32
    ): String =
        let base = face * n * n + row * n;
        List.range(0, n)
            |> List.map(col -> sticker(Vector.get(base + col, fs)) + "│")
            |> List.join("")

    ///
    /// Parse a pretty-printed net into a `Cube`.
    ///
    /// Tolerates UTF-8 box characters, ASCII borders (`+`, `-`, `|`), plain
    /// spaced nets, compact unspaced nets, doc comments (`///`), markdown blocks,
    /// face codes (`U R F D L B`), color codes (`W G Y O R B`), and numeric
    /// face indices (`0 1 2 3 4 5`).
    ///
    pub def parse(text: String): Result[String, Cube.Cube] =
        let dataRows = String.lines(text)
            |> List.map(cellsOfLine)
            |> List.filter(row -> not List.isEmpty(row));
        let totalRows = List.length(dataRows);
        let isNet = totalRows > 0
            and Int32.modulo(totalRows, 3) == 0
            and totalRows / 3 >= 2
            and totalRows / 3 <= 5;
        if (isNet) {
            let n = totalRows / 3;
            let netResult = forM (
                intRows <- dataRows |> Result.traverse(row ->
                    row |> Result.traverse(faceOf) |> Result.map(List.toVector));
                fs <- buildFacelets(n, intRows);
                cube <- Facelets.toCube(n, fs)
            ) yield cube;
            match netResult {
                case Ok(cube) => Ok(cube)
                case Err(_)   => parseFallback(dataRows)
            }
        } else
            parseFallback(dataRows)

    ///
    /// Parse fallback from flattened facelet tokens in standard order `U, R, F, D, L, B`.
    ///
    def parseFallback(dataRows: List[List[String]]): Result[String, Cube.Cube] =
        let tokens = List.flatten(dataRows);
        let total = List.length(tokens);
        match sizeOfCount(total) {
            case Some(n) =>
                forM (
                    ints <- tokens |> Result.traverse(faceOf);
                    cube <- Facelets.toCube(n, List.toVector(ints))
                ) yield cube
            case None    => Err("invalid net: unrecognized row structure or token count (${total})")
        }

    ///
    /// The cube size corresponding to a total facelet count, if any.
    ///
    def sizeOfCount(count: Int32): Option[Int32] = match count {
        case 24  => Some(2)
        case 54  => Some(3)
        case 96  => Some(4)
        case 150 => Some(5)
        case _   => None
    }

    ///
    /// The face index for a single-character face code, color code, or numeric
    /// index (0-5), or an error.
    ///
    /// Accepts face letters (`U R F D L B`), color letters (`W G Y O R B`),
    /// and face indices (`0 1 2 3 4 5`), case-insensitively, with any ANSI escapes stripped.
    ///
    pub def faceOf(token: String): Result[String, Int32] =
        let stripped = String.split(regex = escape() + "\\[[0-9;]*m", token)
            |> List.join("")
            |> String.trim;
        match stripped {
            case "U"   => Ok(0)
            case "u"   => Ok(0)
            case "W"   => Ok(0)
            case "w"   => Ok(0)
            case "0"   => Ok(0)
            case "R"   => Ok(1)
            case "r"   => Ok(1)
            case "1"   => Ok(1)
            case "F"   => Ok(2)
            case "f"   => Ok(2)
            case "G"   => Ok(2)
            case "g"   => Ok(2)
            case "2"   => Ok(2)
            case "D"   => Ok(3)
            case "d"   => Ok(3)
            case "Y"   => Ok(3)
            case "y"   => Ok(3)
            case "3"   => Ok(3)
            case "L"   => Ok(4)
            case "l"   => Ok(4)
            case "O"   => Ok(4)
            case "o"   => Ok(4)
            case "4"   => Ok(4)
            case "B"   => Ok(5)
            case "b"   => Ok(5)
            case "5"   => Ok(5)
            case other => Err("unknown face or color code '${other}'")
        }

    ///
    /// Extract cell contents from a line containing cell borders or plain text.
    ///
    def cellsOfLine(line: String): List[String] =
        let trimmed = line
            |> String.trim
            |> String.replace(src = "///", dst = "")
            |> String.replace(src = "```", dst = "")
            |> String.trim;
        if (String.isEmpty(trimmed) or isBorderOnly(trimmed))
            Nil
        else if (String.contains(substr = "│", trimmed) or String.contains(substr = "|", trimmed))
            String.split(regex = "[│|]", trimmed)
                |> List.flatMap(extractTokens)
        else
            extractTokens(trimmed)

    ///
    /// Whether `s` is composed purely of box border characters and whitespace.
    ///
    def isBorderOnly(s: String): Bool =
        let stripped = s
            |> String.replace(src = "┌", dst = "")
            |> String.replace(src = "┬", dst = "")
            |> String.replace(src = "┐", dst = "")
            |> String.replace(src = "├", dst = "")
            |> String.replace(src = "┼", dst = "")
            |> String.replace(src = "┤", dst = "")
            |> String.replace(src = "└", dst = "")
            |> String.replace(src = "┴", dst = "")
            |> String.replace(src = "┘", dst = "")
            |> String.replace(src = "─", dst = "")
            |> String.replace(src = "+", dst = "")
            |> String.replace(src = "-", dst = "")
            |> String.replace(src = "=", dst = "")
            |> String.trim;
        String.isEmpty(stripped)

    ///
    /// Extract recognized sticker tokens from a string fragment.
    ///
    def extractTokens(segment: String): List[String] =
        let clean = String.split(regex = escape() + "\\[[0-9;]*m", segment)
            |> List.join("")
            |> String.trim;
        if (String.isEmpty(clean))
            Nil
        else
            String.words(clean)
                |> List.flatMap(word ->
                    if (String.length(word) == 1)
                        word :: Nil
                    else
                        String.toList(word) |> List.map(Char.toString))
                |> List.filter(t -> Result.isOk(faceOf(t)))

    ///
    /// Reassemble the parsed rows into the standard facelets vector `U, R, F, D, L, B`.
    ///
    def buildFacelets(n: Int32, rows: List[Vector[Int32]]): Result[String, Vector[Int32]] =
        let vRows = List.toVector(rows);
        let validU = List.range(0, n)
            |> List.forAll(r -> Vector.length(Vector.get(r, vRows)) == n);
        let validMid = List.range(0, n)
            |> List.forAll(r -> Vector.length(Vector.get(n + r, vRows)) == 4 * n);
        let validD = List.range(0, n)
            |> List.forAll(r -> Vector.length(Vector.get(2 * n + r, vRows)) == n);
        if (not (validU and validMid and validD))
            Err("invalid row length in net for ${n}x${n}x${n} cube")
        else region rc {
            let arr = Array.repeat(rc, 6 * n * n, 0);
            List.range(0, n) |> List.forEach(r -> {
                let uRow = Vector.get(r, vRows);
                List.range(0, n) |> List.forEach(c ->
                    Array.put(Vector.get(c, uRow), 0 * n * n + r * n + c, arr))
            });
            List.range(0, n) |> List.forEach(r -> {
                let midRow = Vector.get(n + r, vRows);
                let off = r * n;
                List.range(0, n) |> List.forEach(c -> {
                    Array.put(Vector.get(c, midRow), 4 * n * n + off + c, arr);
                    Array.put(Vector.get(n + c, midRow), 2 * n * n + off + c, arr);
                    Array.put(Vector.get(2 * n + c, midRow), 1 * n * n + off + c, arr);
                    Array.put(Vector.get(3 * n + c, midRow), 5 * n * n + off + c, arr)
                })
            });
            List.range(0, n) |> List.forEach(r -> {
                let dRow = Vector.get(2 * n + r, vRows);
                List.range(0, n) |> List.forEach(c ->
                    Array.put(Vector.get(c, dRow), 3 * n * n + r * n + c, arr))
            });
            Ok(Array.toVector(arr))
        }

}
