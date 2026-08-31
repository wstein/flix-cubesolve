///
/// The cross: four edges, and where they are.
///
/// The first step of the CFOP method solves the four edges of one face. Only
/// those four matter, so the coordinate tracks nothing else -- which slot each
/// of them occupies and which way round it sits, and not one bit about the
/// corners or the other eight edges.
///
/// **190,080 states**: four distinguishable pieces in twelve slots is
/// `12 x 11 x 10 x 9 = 11,880` arrangements, and each of the four can be
/// flipped, so sixteen times that. Small enough that the distance to solved is
/// tabulated exactly for every one of them, which makes the search's heuristic
/// perfect rather than merely admissible: the first solution it finds is
/// optimal, and no depth is ever searched twice.
///
/// **There is no move table.** A successor is four slot lookups and four flip
/// lookups; a table to avoid that would be thirteen megabytes to save a dozen
/// array reads, which is the wrong trade at this size. The two-phase solver's
/// tables exist because its successors are the hot loop of a search that runs
/// tens of millions of steps. This one runs a few thousand.
///
mod CubeSolve.Table.Cross {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face
    use CubeSolve.Table
    use CubeSolve.Table.Cache
    use CubeSolve.Table.TableView
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The four edge pieces the cross is made of: `DR DF DL DB`, slots 4 to 7.
    ///
    /// The cross is solved on `D`. Which face carries it is method policy
    /// rather than arithmetic, and fixing it is what keeps this coordinate one
    /// coordinate: a caller wanting another face turns the cube first.
    ///
    pub def crossPieces(): Vector[Int32] = Vector#{4, 5, 6, 7}

    ///
    /// How many edge slots there are to sit in.
    ///
    pub def slotCount(): Int32 = 12

    ///
    /// The number of arrangements, ignoring flips: `12 x 11 x 10 x 9`.
    ///
    pub def placementCount(): Int32 = 11880

    ///
    /// Every state of the coordinate.
    ///
    pub def stateCount(): Int32 = placementCount() * 16

    ///
    /// The eighteen face turns, which is the alphabet the cross is solved in.
    ///
    pub def moveCount(): Int32 = 18

    ///
    /// The coordinate of a solved cross.
    ///
    pub def solvedIndex(): Int32 = rank(crossPieces(), Vector#{0, 0, 0, 0})

    ///
    /// Where `c`'s cross edges are, as a coordinate.
    ///
    pub def encode(c: Cube.Cube): Result[String, Int32] =
        match Cube.orbits(c) {
            case CornerCoord(_, _) :: MidgeCoord(ep, eo) :: Nil =>
                let places = crossPieces() |> Vector.map(p -> slotOf(p, ep));
                if (Vector.exists(s -> s < 0, places))
                    Err("this cube is missing a cross edge, which cannot happen")
                else
                    Ok(rank(places, places |> Vector.map(s -> Vector.get(s, eo))))
            case _ => Err("the cross is a 3x3x3 coordinate")
        }

    ///
    /// The slot holding piece `p`, or `-1` if no slot does.
    ///
    def slotOf(p: Int32, ep: Vector[Int32]): Int32 =
        Vector.range(0, slotCount())
            |> Vector.findLeft(s -> Vector.get(s, ep) == p)
            |> Option.getWithDefault(-1)

    ///
    /// A coordinate from four slots and four flips.
    ///
    /// The slots are ranked against the ones still free, so the four together
    /// address `12 x 11 x 10 x 9` and not `12^4`: the pieces cannot share a
    /// slot, and a coordinate with gaps in it would put unreachable states in
    /// every table built over it.
    ///
    pub def rank(places: Vector[Int32], flips: Vector[Int32]): Int32 =
        let step = (acc, i) -> {
            let (sofar, free) = acc;
            let slot = Vector.get(i, places);
            let idx = List.indexOf(slot, free) |> Option.getWithDefault(0);
            (sofar * (slotCount() - i) + idx, List.filter(x -> x != slot, free))
        };
        let (placed, _) = Vector.range(0, 4) |> Vector.foldLeft(step,
            (0, List.range(0, slotCount())));
        placed * 16 + flipBits(flips)

    ///
    /// Four flips as four bits.
    ///
    def flipBits(flips: Vector[Int32]): Int32 =
        Vector.range(0, 4) |> Vector.foldLeft((acc, i) ->
            acc + Int32.leftShift(Vector.get(i, flips), i), 0)

    ///
    /// The slots and flips a coordinate stands for.
    ///
    /// **The digits come out least-significant first and are then spent
    /// left to right.** Each is an index into the slots still free at that
    /// point, so which slot a digit names depends on every digit before it.
    /// Reading them out and resolving them in the same pass gets the first one
    /// right and the other three wrong, which is a bijection everywhere the
    /// first piece happens to sit in slot zero and nowhere else.
    ///
    pub def unrank(index: Int32): (Vector[Int32], Vector[Int32]) =
        let flips = Vector.range(0, 4)
            |> Vector.map(i -> Int32.bitwiseAnd(Int32.rightShift(index, i), 1));
        let placed = index / 16;
        let d3 = Int32.modulo(placed, 9);
        let after3 = placed / 9;
        let d2 = Int32.modulo(after3, 10);
        let after2 = after3 / 10;
        let d1 = Int32.modulo(after2, 11);
        let d0 = after2 / 11;
        (spend(List#{d0, d1, d2, d3}), flips)

    ///
    /// Four indices into the slots still free, spent in order.
    ///
    def spend(digits: List[Int32]): Vector[Int32] =
        let step = (acc, d) -> {
            let (free, out) = acc;
            let slot = List.nth(d, free) |> Option.getWithDefault(0);
            (List.filter(x -> x != slot, free), List.append(out, slot :: Nil))
        };
        let (_, places) = digits |> List.foldLeft(step,
            (List.range(0, slotCount()), Nil));
        List.toVector(places)

    ///
    /// Just the first tracked piece's slot and flip, without unranking the rest.
    ///
    /// The first placement digit indexes the slots still free, and at that point
    /// none have been taken -- so the digit *is* the slot, and no list is needed
    /// to look it up. The flip is bit zero.
    ///
    /// This exists because a heuristic reads it on every node, and `unrank`
    /// allocates four lists to answer a question about one piece.
    ///
    pub def firstPiece(index: Int32): (Int32, Int32) =
        let placed = index / 16;
        let slot = ((placed / 9) / 10) / 11;
        (slot, Int32.bitwiseAnd(index, 1))

    ///
    /// The coordinate `index` becomes after move `m`.
    ///
    /// Slot-indexed throughout: `edgePermutation(f)[i]` is the slot the piece
    /// arriving in slot `i` came from, so a piece sitting in slot `s` moves to
    /// whichever slot draws from `s`.
    ///
    pub def successor(index: Int32, m: Int32): Int32 =
        match Move.ofIndex(m) {
            case None      => index
            case Some(mv)  =>
                let (places, flips) = unrank(index);
                let (moved, turned) = turn(Move.face(mv), Move.amount(mv), places, flips);
                rank(moved, turned)
        }

    ///
    /// `places` and `flips` after `k` quarter turns of `f`.
    ///
    def turn(
        f: Face,
        k: Int32,
        places: Vector[Int32],
        flips: Vector[Int32]
    ): (Vector[Int32], Vector[Int32]) =
        if (k <= 0)
            (places, flips)
        else
            let perm = Move.edgePermutation(f);
            let delta = Move.edgeFlip(f);
            let landing = s -> Vector.range(0, slotCount())
                |> Vector.findLeft(i -> Vector.get(i, perm) == s)
                |> Option.getWithDefault(s);
            let moved = places |> Vector.map(landing);
            let added = i -> Vector.get(Vector.get(i, moved), delta);
            let turnedFlips = Vector.range(0, 4) |> Vector.map(i ->
                Int32.modulo(Vector.get(i, flips) + added(i), 2));
            turn(f, k - 1, moved, turnedFlips)

    ///
    /// Distance to a solved cross, for every state.
    ///
    /// Exact rather than a lower bound, because the whole space fits. Four bits
    /// an entry: the cross is never more than eight moves from solved, so a
    /// nibble holds every distance with room to spare.
    ///
    pub def build(): Result[String, TableView] =
        Table.distancesFrom(
            { states = stateCount(), goal = solvedIndex(), moves = moveCount(), bits = 4 },
            successor)

    ///
    /// The same table, read from the cache when one is there.
    ///
    /// Distances over the four `D` edges, placed and flipped. Building it is
    /// seconds to over a minute; reading it is milliseconds, and a caller that
    /// solves one cube per process pays the build every time without this.
    ///
    pub def cached(): Result[String, TableView] \ Cache.Store =
        Table.keep("crossEdges", () -> build())

}
