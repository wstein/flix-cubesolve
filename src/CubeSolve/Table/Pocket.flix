///
/// The 2x2x2 coordinate system, its move tables, and its exact distance oracle.
///
/// A 2x2x2 has no fixed centres, so one corner may be held still without loss
/// of generality. This engine holds **DBL** -- corner slot 6 -- which leaves
/// `U`, `R` and `F` as a sufficient generator set and the state space small
/// enough to solve exhaustively:
///
/// ```
/// permutation   7!  = 5040     Lehmer rank of the seven movable corners
/// orientation   3^6 =  729     base 3, the seventh twist forced by the sum
/// combined      permIndex * 729 + oriIndex  = 3,674,160 states
/// ```
///
/// The orientation coordinate is 729 rather than 2187 because the seven movable
/// twists still sum to zero mod three once DBL is held at zero, so six are free.
/// Using 2187 is valid and sparse.
///
/// **The move tables are factored.** A turn's effect on orientation,
/// `new_o[i] = o[cp[i]] + co[i]`, depends on the move and on the orientation and
/// not at all on the permutation. So orientation and permutation each get their
/// own table -- 5040 x 9 and 729 x 9 -- rather than one table of 3.6 million
/// rows.
///
/// That same independence is what makes the two projections admissible
/// heuristics: distance in either quotient lower-bounds distance in the full
/// space, because a move acts on the projection without reference to what was
/// projected away. See `CubeSolve.Solve.IdaStar`.
///
mod CubeSolve.Table.Pocket {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Cube.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Table
    use CubeSolve.Table.TableView
    use Orbit64.Coord.Coord.CornerCoord
    use CubeSolve.Table.Pocket.Tables.Tables
    use CubeSolve.Table.Cache
    use CubeSolve.Table.Codec

    ///
    /// The number of permutations of the seven movable corners.
    ///
    pub def permCount(): Int32 = 5040

    ///
    /// The number of legal twist patterns of the seven movable corners.
    ///
    pub def oriCount(): Int32 = 729

    ///
    /// The number of states of a 2x2x2 with one corner held still.
    ///
    pub def stateCount(): Int32 = permCount() * oriCount()

    ///
    /// The number of moves in the generator set: `U R F`, each by one, two or
    /// three quarter turns.
    ///
    /// These are exactly the first nine of the full eighteen-move alphabet,
    /// because faces are numbered `U R F D L B` and each face's three moves are
    /// contiguous.
    ///
    pub def moveCount(): Int32 = 9

    ///
    /// The coordinate of the solved cube.
    ///
    /// Zero, because the identity permutation has Lehmer rank zero and the
    /// all-zero twist vector encodes as zero. Worth naming anyway: a search
    /// tests against it in its inner loop.
    ///
    pub def solvedIndex(): Int32 = 0

    ///
    /// The corner slots that move, in the order they are renumbered `0..6`.
    ///
    /// Everything but DBL, which is held still.
    ///
    pub def movableSlots(): Vector[Int32] = Vector#{0, 1, 2, 3, 4, 5, 7}

    ///
    /// Where corner slot `s` sits in the movable numbering, or `6` for DBL,
    /// which never arises because no move in the generator set touches it.
    ///
    def movableIndexOf(s: Int32): Int32 = if (s < 6) s else s - 1

    // ---------- ranking ----------

    ///
    /// The Lehmer rank of a permutation of `0..6`.
    ///
    pub def permRank(q: Vector[Int32]): Int32 =
        Vector.range(0, 7) |> Vector.foldLeft((acc, i) ->
            let later = Vector.range(i + 1, 7);
            let smaller = Vector.count(j -> Vector.get(j, q) < Vector.get(i, q), later);
            acc * (7 - i) + smaller, 0)

    ///
    /// The permutation of `0..6` with Lehmer rank `r`.
    ///
    pub def permUnrank(r: Int32): Vector[Int32] = region rc {
        let digits = Array.repeat(rc, 7, 0);
        def digitsOf(i, rest) =
            if (i < 0) ()
            else {
                Array.put(Int32.modulo(rest, 7 - i), i, digits);
                digitsOf(i - 1, rest / (7 - i))
            };
        digitsOf(6, r);
        let pool = Array.init(rc, i -> i, 7);
        let taken = Array.repeat(rc, 7, false);
        Vector.init(i -> chooseUnused(Array.get(i, digits), pool, taken), 7)
    }

    ///
    /// The `wanted`-th still-unused entry of `pool`, marked used.
    ///
    def chooseUnused(wanted: Int32, pool: Array[Int32, r], taken: Array[Bool, r]): Int32 \ r =
        def scan(at, remaining) =
            if (Array.get(at, taken))
                scan(at + 1, remaining)
            else if (remaining == 0) {
                Array.put(true, at, taken);
                Array.get(at, pool)
            } else
                scan(at + 1, remaining - 1);
        scan(0, wanted)

    ///
    /// The orientation coordinate of seven twists, least significant first.
    ///
    /// The seventh is dropped: it is forced by the requirement that all seven
    /// sum to zero mod three.
    ///
    pub def oriRank(o: Vector[Int32]): Int32 =
        Vector.range(0, 6) |> Vector.foldLeft((acc, i) ->
            acc + Vector.get(i, o) * Int32.pow(base = 3, i), 0)

    ///
    /// The seven twists with orientation coordinate `r`.
    ///
    pub def oriUnrank(r: Int32): Vector[Int32] =
        let digit = i -> Int32.modulo(r / Int32.pow(base = 3, i), 3);
        let free = Vector.init(digit, 6);
        let forced = Int32.modulo(3 - Int32.modulo(Vector.sum(free), 3), 3);
        Vector.append(free, Vector#{forced})

    // ---------- the model, in coordinates and back ----------

    ///
    /// The coordinate of `c`, or why it has none.
    ///
    /// Refuses a cube whose DBL corner has moved. That is not a limitation of
    /// the encoding but of the frame it is stated in: holding a corner still is
    /// what makes the space small, and a cube that has been rotated has to be
    /// brought back before it can be indexed.
    ///
    pub def encode(c: Cube): Result[String, Int32] =
        if (Cube.size(c) != 2)
            Err("the pocket coordinate describes a 2x2x2, not a ${Cube.size(c)}x"
                + "${Cube.size(c)}x${Cube.size(c)}")
        else
            match Cube.orbits(c) {
                case CornerCoord(cp, co) :: Nil => encodeCorners(cp, co)
                case _ => Err("a 2x2x2 has exactly one orbit, its corners")
            }

    ///
    /// The coordinate of a corner permutation and twist vector.
    ///
    def encodeCorners(cp: Vector[Int32], co: Vector[Int32]): Result[String, Int32] =
        if (Vector.get(6, cp) != 6 or Vector.get(6, co) != 0)
            Err("this coordinate holds the DBL corner still, but here it is piece "
                + "${Vector.get(6, cp)} twisted ${Vector.get(6, co)}: rotate the "
                + "cube so that DBL is home before indexing it")
        else
            let q = Vector.init(i ->
                movableIndexOf(Vector.get(Vector.get(i, movableSlots()), cp)), 7);
            let o = Vector.init(i -> Vector.get(Vector.get(i, movableSlots()), co), 7);
            Table.flatIndex(permRank(q), oriCount(), oriRank(o))

    ///
    /// The cube with coordinate `i`, or why there is none.
    ///
    pub def decode(i: Int32): Result[String, Cube] =
        if (i < 0 or i >= stateCount())
            Err("${i} is not a pocket coordinate: they run 0 to ${stateCount() - 1}")
        else
            let q = permUnrank(i / oriCount());
            let o = oriUnrank(Int32.modulo(i, oriCount()));
            // q holds movable indices; movableSlots turns one back into a slot.
            let cp = Vector.init(s ->
                if (s == 6) 6
                else Vector.get(Vector.get(movableIndexOf(s), q), movableSlots()), 8);
            let co = Vector.init(s ->
                if (s == 6) 0 else Vector.get(movableIndexOf(s), o), 8);
            Cube.ofOrbits(2, CornerCoord(cp, co) :: Nil)

    // ---------- move tables ----------

    ///
    /// The move with index `m` in the pocket alphabet.
    ///
    /// The first nine of the full alphabet, which are exactly `U`, `R` and `F`
    /// by one, two and three quarter turns.
    ///
    pub def moveOfIndex(m: Int32): Move.Move =
        Move.ofIndex(m) |> Option.getWithDefault(Move.Move.Turn(Move.Face.U, 1))

    ///
    /// The permutation move table: `5040 x 9`, read at `perm * 9 + move`.
    ///
    /// Sixteen bits an entry, because a permutation index reaches 5039 and does
    /// not fit a byte.
    ///
    pub def permMoves(): Result[String, TableView] = region rc {
        let payload = Table.emptyPayload(rc, 16, permCount() * moveCount());
        Vector.range(0, permCount()) |> Vector.forEach(r ->
            Vector.range(0, moveCount()) |> Vector.forEach(m ->
                Table.putEntry(payload, 16, r * moveCount() + m, turnedPerm(r, m))));
        Table.ofPayload(16, permCount() * moveCount(), payload)
    }

    ///
    /// The orientation move table: `729 x 9`, read at `ori * 9 + move`.
    ///
    pub def oriMoves(): Result[String, TableView] = region rc {
        let payload = Table.emptyPayload(rc, 16, oriCount() * moveCount());
        Vector.range(0, oriCount()) |> Vector.forEach(r ->
            Vector.range(0, moveCount()) |> Vector.forEach(m ->
                Table.putEntry(payload, 16, r * moveCount() + m, turnedOri(r, m))));
        Table.ofPayload(16, oriCount() * moveCount(), payload)
    }

    ///
    /// The permutation index after move `m` is applied to index `r`.
    ///
    def turnedPerm(r: Int32, m: Int32): Int32 =
        let move = moveOfIndex(m);
        let perm = Move.cornerPermutation(Move.face(move));
        let after = repeat(Move.amount(move), permUnrank(r), q -> movePerm(perm, q));
        permRank(after)

    ///
    /// One quarter turn applied to a movable-corner permutation.
    ///
    /// Slot-indexed: the piece now at movable slot `i` is the one that was at
    /// the slot the turn brings there.
    ///
    def movePerm(perm: Vector[Int32], q: Vector[Int32]): Vector[Int32] =
        Vector.init(i ->
            let slot = Vector.get(i, movableSlots());
            Vector.get(movableIndexOf(Vector.get(slot, perm)), q), 7)

    ///
    /// The orientation index after move `m` is applied to index `r`.
    ///
    def turnedOri(r: Int32, m: Int32): Int32 =
        let move = moveOfIndex(m);
        let face = Move.face(move);
        let perm = Move.cornerPermutation(face);
        let delta = Move.cornerTwist(face);
        let after = repeat(Move.amount(move), oriUnrank(r), o -> moveOri(perm, delta, o));
        oriRank(after)

    ///
    /// One quarter turn applied to a movable-corner twist vector.
    ///
    def moveOri(perm: Vector[Int32], delta: Vector[Int32], o: Vector[Int32]): Vector[Int32] =
        Vector.init(i ->
            let slot = Vector.get(i, movableSlots());
            let carried = Vector.get(movableIndexOf(Vector.get(slot, perm)), o);
            Int32.modulo(carried + Vector.get(slot, delta), 3), 7)

    ///
    /// `step` applied `k` times to `x`.
    ///
    def repeat(k: Int32, x: a, step: a -> a): a =
        if (k <= 0) x else repeat(k - 1, step(x), step)

    // ---------- the exact oracle ----------

    ///
    /// Every 2x2x2 table, built together.
    ///
    /// One value rather than five accessors because building them separately
    /// would repeat the two move tables that three of them are derived from,
    /// and the distance sweep is the expensive part of the whole engine.
    ///
    pub enum Tables {
        case Tables({
            permMoves = TableView,
            oriMoves = TableView,
            distances = TableView,
            oriDistances = TableView,
            permDistances = TableView
        })
    }

    ///
    /// The move table on permutations.
    ///
    pub def permMoveTable(t: Tables): TableView = let Tables(r) = t; r#permMoves

    ///
    /// The move table on orientations.
    ///
    pub def oriMoveTable(t: Tables): TableView = let Tables(r) = t; r#oriMoves

    ///
    /// The exact distance to solved, for every one of the 3,674,160 states.
    ///
    pub def distanceTable(t: Tables): TableView = let Tables(r) = t; r#distances

    ///
    /// Distance to solved in the 729-state orientation quotient.
    ///
    pub def oriDistanceTable(t: Tables): TableView = let Tables(r) = t; r#oriDistances

    ///
    /// Distance to solved in the 5040-state permutation quotient.
    ///
    pub def permDistanceTable(t: Tables): TableView = let Tables(r) = t; r#permDistances

    ///
    /// Build every 2x2x2 table.
    ///
    /// This is the engine's one genuinely expensive initialisation: a
    /// breadth-first sweep of the whole state space. It is pure and
    /// deterministic, so the result can be cached or serialised, but nothing
    /// here does that -- a caller that needs it more than once should hold on
    /// to it.
    ///
    pub def build(): Result[String, Tables] =
        forM (
            pm <- permMoves();
            om <- oriMoves();
            full <- fullDistances(pm, om);
            oriD <- quotientDistancesOf(om, oriCount());
            permD <- quotientDistancesOf(pm, permCount())
        ) yield Tables({
            permMoves = pm,
            oriMoves = om,
            distances = full,
            oriDistances = oriD,
            permDistances = permD
        })

    ///
    /// Exact distance to solved for every state.
    ///
    /// Four bits an entry: the diameter is 11 and fifteen is the marker, so the
    /// whole 3,674,160-state table is 1,837,080 bytes.
    ///
    def fullDistances(pm: TableView, om: TableView): Result[String, TableView] =
        Table.distancesFrom(
            { states = stateCount(), goal = solvedIndex(), moves = moveCount(), bits = 4 },
            (s, m) -> {
                let perm = Table.get(s / oriCount() * moveCount() + m, pm);
                let ori = Table.get(Int32.modulo(s, oriCount()) * moveCount() + m, om);
                perm * oriCount() + ori
            })

    ///
    /// Distance to solved in a quotient with its own move table.
    ///
    /// Public because it is cheap -- 729 or 5040 states -- and a caller that
    /// wants only a heuristic should not have to pay for the 3.6 million-state
    /// sweep that `build` does.
    ///
    /// Both projections are homomorphic -- a move acts on either without
    /// reference to the other -- so a sweep of the quotient gives an admissible
    /// heuristic for the full space.
    ///
    pub def quotientDistancesOf(moves: TableView, states: Int32): Result[String, TableView] =
        Table.distancesFrom(
            { states = states, goal = 0, moves = moveCount(), bits = 4 },
            (s, m) -> Table.get(s * moveCount() + m, moves))

    ///
    /// Build every 2x2x2 table, reading from the cache where it can.
    ///
    /// Each table is cached under its own key, so a change that invalidates one
    /// does not throw away the rest.
    ///
    pub def cachedTables(): Result[String, Tables] \ Cache.Store =
        forM (
            pm <- keep("pocket.permMoves", () -> permMoves());
            om <- keep("pocket.oriMoves", () -> oriMoves());
            full <- keep("pocket.distances", () -> fullDistances(pm, om));
            oriD <- keep("pocket.oriDistances", () -> quotientDistancesOf(om, oriCount()));
            permD <- keep("pocket.permDistances", () -> quotientDistancesOf(pm, permCount()))
        ) yield Tables({
            permMoves = pm,
            oriMoves = om,
            distances = full,
            oriDistances = oriD,
            permDistances = permD
        })

    ///
    /// One table, from the cache or freshly built and kept.
    ///
    def keep(
        key: String,
        build: Unit -> Result[String, TableView]
    ): Result[String, TableView] \ Cache.Store =
        Cache.table(key, headerFor(key), build)

    ///
    /// The header a 2x2x2 table is written under.
    ///
    /// Public because anything reading this cache without going through
    /// `cachedTables` -- the Gate 13.2 harness does -- must ask under the same
    /// header, and a second copy of that construction would drift.
    ///
    pub def headerFor(key: String): Codec.Header =
        Codec.header({
            table = key,
            convention = CubeSolve.convention(),
            generator = CubeSolve.generator()
        })

}
