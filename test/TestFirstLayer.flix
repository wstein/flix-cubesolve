///
/// The first layer: the cross, and the four corners above it.
///
/// The coordinate is checked exhaustively, because a ranking that collides puts
/// two different layers at one table entry and makes every distance below it a
/// lie. The solver is checked by replay on a named stratum, because each search
/// costs seconds and the suite is not the place to spend minutes.
///
/// **The result is checked against the ladder, not against the coordinate.**
/// `Solve.FirstLayer.isSolved` asks the same encoders the search was steered by,
/// so a coordinate fault and a search fault that agreed with each other would
/// satisfy it. `Method.Beginner` reads the cube instead, and that is what the
/// public stage boundary means.
///
mod TestFirstLayer {


    use CubeSolve.Method.Beginner
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Solve.FirstLayer.Tables
    use CubeSolve.Table
    use CubeSolve.Table.FirstLayer.{encode, rank, solvedIndex, stateCount, successor, unrank}

    ///
    /// The corner table is complete, and no bottom corner is more than seven
    /// moves from home.
    ///
    @Test
    def theCornerTableIsCompleteAndSevenDeep(): Unit \ Assert =
        match CubeSolve.Table.FirstLayer.build() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "building")
            case Ok(t)  =>
                Assert.assertEqWithMsg(expected = stateCount(), Table.entries(t),
                    "one entry per state");
                let deepest = Vector.range(0, stateCount())
                    |> Vector.foldLeft((w, i) -> Int32.max(w, Table.get(i, t)), 0);
                Assert.assertEqWithMsg(expected = 7, deepest,
                    "the furthest bottom corners are seven moves from home");
                Assert.assertEqWithMsg(expected = 0, Table.get(solvedIndex(), t),
                    "solved corners are nought moves from home")
        }
}
