///
/// Unfolded net box-drawing pretty-printer for the CLI.
///
mod RenderNet {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets

    /// The net as face letters in box-drawing format.
    pub def net(c: Cube.Cube): Result[String, String] =
        draw(c, i -> " " + letterOf(i) + " ")

    /// Face code letter in URFDLB order.
    pub def letterOf(face: Int32): String = match face {
        case 0 => "U"
        case 1 => "R"
        case 2 => "F"
        case 3 => "D"
        case 4 => "L"
        case 5 => "B"
        case _ => "?"
    }

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
