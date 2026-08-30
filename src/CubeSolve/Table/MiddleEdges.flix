///
/// The four middle edges, and where they are.
///
/// The third projection of the first two layers, after the cross's edges and the
/// bottom corners. `FR FL BL BR` are slots 8 to 11.
///
/// **The numbering is the cross's, because the arithmetic is.** Four
/// distinguishable edges among twelve slots with a flip each is the same
/// counting problem whichever four they are, so `rank`, `unrank` and `successor`
/// are `CubeSolve.Table.Cross`'s and only the pieces tracked differ. A second
/// copy would be a second thing to get wrong.
///
mod CubeSolve.Table.MiddleEdges {

    use CubeSolve.Model.Cube
    use CubeSolve.Table
    use CubeSolve.Table.Cross
    use CubeSolve.Table.TableView
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The edges between the centres: `FR FL BL BR`, slots 8 to 11.
    ///
    pub def middleEdges(): Vector[Int32] = Vector#{8, 9, 10, 11}

    ///
    /// Every state of the coordinate, which is the cross's count.
    ///
    pub def stateCount(): Int32 = Cross.stateCount()

    ///
    /// The eighteen face turns.
    ///
    pub def moveCount(): Int32 = Cross.moveCount()

    ///
    /// The coordinate of solved middle edges.
    ///
    pub def solvedIndex(): Int32 = Cross.rank(middleEdges(), Vector#{0, 0, 0, 0})

    ///
    /// Where `c`'s middle edges are, as a coordinate.
    ///
    pub def encode(c: Cube.Cube): Result[String, Int32] =
        match Cube.orbits(c) {
            case CornerCoord(_, _) :: MidgeCoord(ep, eo) :: Nil =>
                let places = middleEdges() |> Vector.map(p -> slotOf(p, ep));
                if (Vector.exists(s -> s < 0, places))
                    Err("this cube is missing a middle edge, which cannot happen")
                else
                    Ok(Cross.rank(places, places |> Vector.map(s -> Vector.get(s, eo))))
            case _ => Err("the middle edges are a 3x3x3 coordinate")
        }

    ///
    /// The slot holding piece `p`, or `-1` if no slot does.
    ///
    def slotOf(p: Int32, ep: Vector[Int32]): Int32 =
        Vector.range(0, Cross.slotCount())
            |> Vector.findLeft(s -> Vector.get(s, ep) == p)
            |> Option.getWithDefault(-1)

    ///
    /// The coordinate `index` becomes after move `m`.
    ///
    pub def successor(index: Int32, m: Int32): Int32 = Cross.successor(index, m)

    ///
    /// Distance to solved middle edges, for every state.
    ///
    pub def build(): Result[String, TableView] =
        Table.distancesFrom(
            { states = stateCount(), goal = solvedIndex(), moves = moveCount(), bits = 8 },
            successor)

}
