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
    /// `s` on the background colour that face is usually stickered.
    ///
    /// The Western scheme: white up, green front, red right, and so around.
    /// Orange is why these are 24-bit rather than the sixteen basic colours --
    /// there is no orange among them, and orange against red is the one
    /// distinction a cube renderer cannot afford to lose.
    ///
    def paint(face: Int32, s: String): String =
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

}
