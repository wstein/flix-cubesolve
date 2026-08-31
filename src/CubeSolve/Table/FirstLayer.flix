///
/// The four bottom corners, and where they are.
///
/// The companion to `CubeSolve.Table.Cross`: that one tracks the four bottom
/// edges and this one the four bottom corners, and the first layer is done when
/// both are home. Neither knows about the other, which is what lets each be
/// tabulated exactly and combined afterwards.
///
/// **136,080 states**: four distinguishable corners among eight slots is
/// `8 x 7 x 6 x 5 = 1,680` placements, and each can sit three ways round, so
/// eighty-one times that. Small enough to hold the exact distance to solved for
/// every one.
///
mod CubeSolve.Table.FirstLayer {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face
    use CubeSolve.Table
    use CubeSolve.Table.Cache
    use CubeSolve.Table.TableView
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The corners the first layer is made of: `DFR DLF DBL DRB`, slots 4 to 7.
    ///
    pub def bottomCorners(): Vector[Int32] = Vector#{4, 5, 6, 7}

    ///
    /// How many corner slots there are to sit in.
    ///
    pub def slotCount(): Int32 = 8

    ///
    /// The number of placements, ignoring twist: `8 x 7 x 6 x 5`.
    ///
    pub def placementCount(): Int32 = 1680

    ///
    /// Four corners, each of three ways round.
    ///
    pub def twistCount(): Int32 = 81

    ///
    /// Every state of the coordinate.
    ///
    pub def stateCount(): Int32 = placementCount() * twistCount()

    ///
    /// The eighteen face turns.
    ///
    pub def moveCount(): Int32 = 18

    ///
    /// The coordinate of a solved bottom layer's corners.
    ///
    pub def solvedIndex(): Int32 = rank(bottomCorners(), Vector#{0, 0, 0, 0})

    ///
    /// Where `c`'s bottom corners are, as a coordinate.
    ///
    pub def encode(c: Cube.Cube): Result[String, Int32] =
        match Cube.orbits(c) {
            case CornerCoord(cp, co) :: MidgeCoord(_, _) :: Nil =>
                let places = bottomCorners() |> Vector.map(p -> slotOf(p, cp));
                if (Vector.exists(s -> s < 0, places))
                    Err("this cube is missing a bottom corner, which cannot happen")
                else
                    Ok(rank(places, places |> Vector.map(s -> Vector.get(s, co))))
            case _ => Err("the first layer is a 3x3x3 coordinate")
        }

    ///
    /// The slot holding piece `p`, or `-1` if no slot does.
    ///
    def slotOf(p: Int32, cp: Vector[Int32]): Int32 =
        Vector.range(0, slotCount())
            |> Vector.findLeft(s -> Vector.get(s, cp) == p)
            |> Option.getWithDefault(-1)

    ///
    /// A coordinate from four slots and four twists.
    ///
    /// The slots are ranked against the ones still free, so four corners address
    /// `8 x 7 x 6 x 5` rather than `8^4`: they cannot share a slot, and a
    /// coordinate with gaps would put unreachable states in the table.
    ///
    pub def rank(places: Vector[Int32], twists: Vector[Int32]): Int32 =
        let step = (acc, i) -> {
            let (sofar, free) = acc;
            let slot = Vector.get(i, places);
            let idx = List.indexOf(slot, free) |> Option.getWithDefault(0);
            (sofar * (slotCount() - i) + idx, List.filter(x -> x != slot, free))
        };
        let (placed, _) = Vector.range(0, 4) |> Vector.foldLeft(step,
            (0, List.range(0, slotCount())));
        placed * twistCount() + twistDigits(twists)

    ///
    /// Four twists as a base-three number.
    ///
    def twistDigits(twists: Vector[Int32]): Int32 =
        Vector.range(0, 4) |> Vector.foldLeft((acc, i) ->
            acc * 3 + Vector.get(i, twists), 0)

    ///
    /// The slots and twists a coordinate stands for.
    ///
    /// The placement digits come out least-significant first and are spent left
    /// to right, because each is an index into the slots still free at that
    /// point.
    ///
    pub def unrank(index: Int32): (Vector[Int32], Vector[Int32]) =
        let twists = twistsOf(Int32.modulo(index, twistCount()));
        let placed = index / twistCount();
        let d3 = Int32.modulo(placed, 5);
        let after3 = placed / 5;
        let d2 = Int32.modulo(after3, 6);
        let after2 = after3 / 6;
        let d1 = Int32.modulo(after2, 7);
        let d0 = after2 / 7;
        (spend(List#{d0, d1, d2, d3}), twists)

    ///
    /// A base-three number as four twists, most significant first.
    ///
    def twistsOf(digits: Int32): Vector[Int32] =
        Vector#{
            Int32.modulo(digits / 27, 3),
            Int32.modulo(digits / 9, 3),
            Int32.modulo(digits / 3, 3),
            Int32.modulo(digits, 3)
        }

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
    /// The coordinate `index` becomes after move `m`.
    ///
    pub def successor(index: Int32, m: Int32): Int32 =
        match Move.ofIndex(m) {
            case None     => index
            case Some(mv) =>
                let (places, twists) = unrank(index);
                let (moved, turned) = turn(Move.face(mv), Move.amount(mv), places, twists);
                rank(moved, turned)
        }

    ///
    /// `places` and `twists` after `k` quarter turns of `f`.
    ///
    def turn(
        f: Face,
        k: Int32,
        places: Vector[Int32],
        twists: Vector[Int32]
    ): (Vector[Int32], Vector[Int32]) =
        if (k <= 0)
            (places, twists)
        else
            let perm = Move.cornerPermutation(f);
            let delta = Move.cornerTwist(f);
            let landing = s -> Vector.range(0, slotCount())
                |> Vector.findLeft(i -> Vector.get(i, perm) == s)
                |> Option.getWithDefault(s);
            let moved = places |> Vector.map(landing);
            let added = i -> Vector.get(Vector.get(i, moved), delta);
            let turnedTwists = Vector.range(0, 4) |> Vector.map(i ->
                Int32.modulo(Vector.get(i, twists) + added(i), 3));
            turn(f, k - 1, moved, turnedTwists)

    ///
    /// Distance to solved bottom corners, for every state.
    ///
    /// Exact rather than a lower bound, because the whole space fits.
    ///
    pub def build(): Result[String, TableView] =
        Table.distancesFrom(
            { states = stateCount(), goal = solvedIndex(), moves = moveCount(), bits = 8 },
            successor)

    ///
    /// The same table, read from the cache when one is there.
    ///
    /// Distances over the four `D` corners, placed and twisted. Building it is
    /// seconds to over a minute; reading it is milliseconds, and a caller that
    /// solves one cube per process pays the build every time without this.
    ///
    pub def cached(): Result[String, TableView] \ Cache.Store =
        Table.keep("firstLayer", () -> build())

}
