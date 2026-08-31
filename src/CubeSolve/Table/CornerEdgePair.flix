///
/// The four bottom corners together with one designated middle edge.
///
/// **A projection that measures what the separate ones cannot.** Run after the
/// first layer is solved, the cross and corner projections both read zero while
/// the true distance does not, because the layer must be disturbed and put back.
/// Neither can see that cost; this can, because it holds the corners and an edge
/// at once and so knows what restoring the one while placing the other is worth.
///
/// It is admissible for the whole of the first two layers: any sequence that
/// finishes them must also finish the corners and this edge, so the distance
/// here is a lower bound on that.
///
/// **3,265,920 states**: 136,080 corner states by the twelve slots and two ways
/// round one edge can be in. One edge rather than four, because four would be
/// 136,080 times 190,080 and the point of a projection is that it fits.
///
/// Added on evidence. With the three separate projections the search spent
/// between 4.1 and 31.4 million nodes on states of the same depth -- an
/// eightfold spread that depth cannot explain and restore cost can. The figures
/// are in `docs/architecture.md`.
///
mod CubeSolve.Table.CornerEdgePair {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Table
    use CubeSolve.Table.Cache
    use CubeSolve.Table.FirstLayer
    use CubeSolve.Table.TableView
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The middle edge this projection watches: `FR`, slot 8.
    ///
    /// One of the four, chosen and fixed. Which one does not matter to
    /// admissibility -- every solution places all four -- and holding one keeps
    /// the table small.
    ///
    pub def designatedEdge(): Int32 = 8

    ///
    /// How many edge slots there are to sit in.
    ///
    pub def slotCount(): Int32 = 12

    ///
    /// Where one edge can be: twelve slots, each of two ways round.
    ///
    pub def edgeStateCount(): Int32 = slotCount() * 2

    ///
    /// Every state of the coordinate.
    ///
    pub def stateCount(): Int32 = FirstLayer.stateCount() * edgeStateCount()

    ///
    /// The eighteen face turns.
    ///
    pub def moveCount(): Int32 = 18

    ///
    /// The coordinate of solved corners with the edge home.
    ///
    pub def solvedIndex(): Int32 =
        rank(FirstLayer.solvedIndex(), designatedEdge(), 0)

    ///
    /// A coordinate from a corner state, an edge slot and its flip.
    ///
    pub def rank(corners: Int32, slot: Int32, flip: Int32): Int32 =
        corners * edgeStateCount() + slot * 2 + flip

    ///
    /// The corner state, edge slot and flip a coordinate stands for.
    ///
    pub def unrank(index: Int32): (Int32, Int32, Int32) =
        let corners = index / edgeStateCount();
        let rest = Int32.modulo(index, edgeStateCount());
        (corners, rest / 2, Int32.modulo(rest, 2))

    ///
    /// Where `c`'s bottom corners and designated edge are, as a coordinate.
    ///
    pub def encode(c: Cube.Cube): Result[String, Int32] =
        match Cube.orbits(c) {
            case CornerCoord(_, _) :: MidgeCoord(ep, eo) :: Nil =>
                match slotOf(designatedEdge(), ep) {
                    case -1   => Err("this cube is missing an edge, which cannot happen")
                    case slot =>
                        FirstLayer.encode(c)
                            |> Result.map(corners ->
                                rank(corners, slot, Vector.get(slot, eo)))
                }
            case _ => Err("this pair is a 3x3x3 coordinate")
        }

    ///
    /// The slot holding piece `p`, or `-1` if no slot does.
    ///
    def slotOf(p: Int32, ep: Vector[Int32]): Int32 =
        Vector.range(0, slotCount())
            |> Vector.findLeft(s -> Vector.get(s, ep) == p)
            |> Option.getWithDefault(-1)

    ///
    /// The coordinate `index` becomes after move `m`.
    ///
    pub def successor(index: Int32, m: Int32): Int32 =
        match Move.ofIndex(m) {
            case None     => index
            case Some(mv) =>
                let (corners, slot, flip) = unrank(index);
                let (movedSlot, movedFlip) =
                    turnEdge(Move.face(mv), Move.amount(mv), slot, flip);
                rank(FirstLayer.successor(corners, m), movedSlot, movedFlip)
        }

    ///
    /// One edge's slot and flip after `k` quarter turns of `f`.
    ///
    def turnEdge(
        f: Move.Face,
        k: Int32,
        slot: Int32,
        flip: Int32
    ): (Int32, Int32) =
        if (k <= 0)
            (slot, flip)
        else
            let perm = Move.edgePermutation(f);
            let delta = Move.edgeFlip(f);
            let landing = Vector.range(0, slotCount())
                |> Vector.findLeft(i -> Vector.get(i, perm) == slot)
                |> Option.getWithDefault(slot);
            let turned = Int32.modulo(flip + Vector.get(landing, delta), 2);
            turnEdge(f, k - 1, landing, turned)

    ///
    /// Distance to solved corners with the edge home, for every state.
    ///
    pub def build(): Result[String, TableView] =
        Table.distancesFrom(
            { states = stateCount(), goal = solvedIndex(), moves = moveCount(), bits = 8 },
            successor)

    ///
    /// The same table, read from the cache when one is there.
    ///
    /// Distances over one `D` corner and the middle edge it pairs with. Building it is
    /// seconds to over a minute; reading it is milliseconds, and a caller that
    /// solves one cube per process pays the build every time without this.
    ///
    pub def cached(): Result[String, TableView] \ Cache.Store =
        Table.keep("cornerEdgePair", () -> build())

}
