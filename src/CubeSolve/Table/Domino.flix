///
/// The domino group: the 3x3x3's phase two.
///
/// Once phase one has finished, the cube can be solved without ever turning a
/// face by a quarter turn again -- only `U`, `D` and the four half turns. That
/// subgroup, `<U, D, R2, L2, F2, B2>`, is conventionally called the domino
/// group, and inside it the cube is a much smaller problem:
///
/// ```
/// CPerm   8!  = 40320   the eight corners
/// EPerm   8!  = 40320   the eight U- and D-layer edges
/// MPerm   4!  =    24   the four slice edges, among themselves
/// CComb   140          parity, and where the U-layer corner tetrad sits
/// ```
///
/// **Each of these is closed under the phase-two alphabet**, which is what
/// makes them coordinates at all. A half turn of `R` swaps two U/D edges with
/// each other and two slice edges with each other; it never mixes the two
/// families. A quarter turn of `R` would, which is exactly what phase one is
/// for.
///
/// **CComb is a projection of CPerm, not an independent coordinate.** It is
/// `parity * 70 + rank`, where the parity is that of the corner permutation and
/// the rank says which four slots hold the URF/UFL/ULB/UBR tetrad. Both are
/// determined by the corner permutation and both transform under a move without
/// reference to anything else, so pairing it with EPerm gives an admissible
/// bound that couples corners to edges -- which neither `CPerm x MPerm` nor
/// `EPerm x MPerm` does.
///
mod CubeSolve.Table.Domino {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Cube.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Table
    use CubeSolve.Table.TableView
    use CubeSolve.Table.Domino.Tables.Tables
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The number of corner permutations.
    ///
    pub def cornerPermCount(): Int32 = 40320

    ///
    /// The number of permutations of the eight U- and D-layer edges.
    ///
    pub def edgePermCount(): Int32 = 40320

    ///
    /// The number of permutations of the four slice edges among themselves.
    ///
    pub def slicePermCount(): Int32 = 24

    ///
    /// The number of corner parity-and-tetrad states: `2 x C(8, 4)`.
    ///
    pub def combCount(): Int32 = 140

    ///
    /// The number of moves in the phase-two alphabet.
    ///
    pub def moveCount(): Int32 = 10

    ///
    /// The phase-two alphabet, as indices into the full eighteen.
    ///
    /// `U U2 U' D D2 D' R2 L2 F2 B2`. Quarter turns of U and D, half turns of
    /// everything else: the moves that leave every phase-one coordinate solved.
    ///
    pub def moveIndices(): Vector[Int32] =
        Vector#{0, 1, 2, 9, 10, 11, 4, 13, 7, 16}

    ///
    /// The full-alphabet index of phase-two move `m`, or `m` itself when
    /// negative -- which is how the search says "no move yet".
    ///
    pub def fullIndexOf(m: Int32): Int32 =
        if (m < 0) m else Vector.get(m, moveIndices())

    ///
    /// The move phase-two index `m` names.
    ///
    pub def moveOfIndex(m: Int32): Move.Move =
        Move.ofIndex(fullIndexOf(m)) |> Option.getWithDefault(Move.Move.Turn(Move.Face.U, 1))

    ///
    /// Whether phase-two move `next` may follow `last`.
    ///
    /// The same half-turn rule as everywhere else, applied to the moves' real
    /// identities rather than to their positions in this smaller alphabet.
    ///
    pub def pruningAllows(last: Int32, next: Int32): Bool =
        Move.htmPruningAllows(fullIndexOf(last), fullIndexOf(next))

    // ---------- ranking ----------

    ///
    /// The Lehmer rank of a permutation of `0..7`.
    ///
    pub def permRank(p: Vector[Int32]): Int32 =
        let step = (acc, i) -> {
            let later = Vector.range(i + 1, 8);
            let smaller = Vector.count(j -> Vector.get(j, p) < Vector.get(i, p), later);
            acc * (8 - i) + smaller
        };
        Vector.range(0, 8) |> Vector.foldLeft(step, 0)

    ///
    /// The permutation of `0..7` with Lehmer rank `r`.
    ///
    pub def permUnrank(r: Int32): Vector[Int32] = region rc {
        let digits = Array.repeat(rc, 8, 0);
        def digitsOf(i, rest) =
            if (i < 0) ()
            else {
                Array.put(Int32.modulo(rest, 8 - i), i, digits);
                digitsOf(i - 1, rest / (8 - i))
            };
        digitsOf(7, r);
        let taken = Array.repeat(rc, 8, false);
        Vector.init(i -> takeUnused(Array.get(i, digits), taken), 8)
    }

    ///
    /// The `wanted`-th still-unused index, marked used.
    ///
    def takeUnused(wanted: Int32, taken: Array[Bool, r]): Int32 \ r =
        def scan(at, remaining) =
            if (Array.get(at, taken))
                scan(at + 1, remaining)
            else if (remaining == 0) {
                Array.put(true, at, taken);
                at
            } else
                scan(at + 1, remaining - 1);
        scan(0, wanted)

    ///
    /// The Lehmer rank of a permutation of `0..3`.
    ///
    pub def slicePermRank(p: Vector[Int32]): Int32 =
        let step = (acc, i) -> {
            let later = Vector.range(i + 1, 4);
            let smaller = Vector.count(j -> Vector.get(j, p) < Vector.get(i, p), later);
            acc * (4 - i) + smaller
        };
        Vector.range(0, 4) |> Vector.foldLeft(step, 0)

    ///
    /// The permutation of `0..3` with Lehmer rank `r`.
    ///
    pub def slicePermUnrank(r: Int32): Vector[Int32] = region rc {
        let digits = Array.repeat(rc, 4, 0);
        def digitsOf(i, rest) =
            if (i < 0) ()
            else {
                Array.put(Int32.modulo(rest, 4 - i), i, digits);
                digitsOf(i - 1, rest / (4 - i))
            };
        digitsOf(3, r);
        let taken = Array.repeat(rc, 4, false);
        Vector.init(i -> takeUnused(Array.get(i, digits), taken), 4)
    }

    ///
    /// The parity of a permutation: `0` when even, `1` when odd.
    ///
    pub def parityOf(p: Vector[Int32]): Int32 =
        let n = Vector.length(p);
        let inversions = Vector.range(0, n) |> Vector.map(i ->
            Vector.range(i + 1, n)
                |> Vector.count(j -> Vector.get(i, p) > Vector.get(j, p)))
            |> Vector.sum;
        Int32.modulo(inversions, 2)

    ///
    /// The CComb coordinate of a corner permutation.
    ///
    /// `parity * 70 + rank`, where the rank says which four slots hold the
    /// URF/UFL/ULB/UBR tetrad -- corners 0 to 3.
    ///
    pub def combOf(cp: Vector[Int32]): Int32 =
        let tetrad = Vector.range(0, 8) |> Vector.filter(i -> Vector.get(i, cp) < 4);
        parityOf(cp) * 70 + Orbit64.Rank.combRank(tetrad)

    // ---------- coordinates of a cube ----------

    ///
    /// The four phase-two coordinates of `c`, or why it has none.
    ///
    /// Refuses a cube outside the domino group: its slice edges are not in the
    /// slice, so `MPerm` would be describing something that is not a
    /// permutation of them. Saying so is better than returning a number.
    ///
    pub def coordsOf(c: Cube): Result[String, (Int32, Int32, Int32)] =
        if (Cube.size(c) != 3)
            Err("the phase-two coordinates describe a 3x3x3, not a "
                + "${Cube.size(c)}x${Cube.size(c)}x${Cube.size(c)}")
        else
            match Cube.orbits(c) {
                case CornerCoord(cp, _) :: MidgeCoord(ep, _) :: Nil => splitEdges(cp, ep)
                case _ => Err("a 3x3x3 has a corner orbit and a midge orbit, in that order")
            }

    ///
    /// The corner, U/D-edge and slice-edge ranks, if the edges are sorted into
    /// their families.
    ///
    def splitEdges(
        cp: Vector[Int32],
        ep: Vector[Int32]
    ): Result[String, (Int32, Int32, Int32)] =
        let outer = Vector.init(i -> Vector.get(i, ep), 8);
        let sliceAt = i -> Vector.get(i + 8, ep) - 8;
        let inner = Vector.init(sliceAt, 4);
        let inU = x -> x >= 0 and x < 8;
        let inSlice = x -> x >= 0 and x < 4;
        if (not Vector.forAll(inU, outer))
            Err("this cube is not in the domino group: a slice edge is sitting in "
                + "the U or D layer, so phase one has not finished")
        else if (not Vector.forAll(inSlice, inner))
            Err("this cube is not in the domino group: a U or D edge is sitting in "
                + "the slice, so phase one has not finished")
        else
            Ok((permRank(cp), permRank(outer), slicePermRank(inner)))

    ///
    /// Whether `c` is solved, decided from its phase-two coordinates.
    ///
    pub def isSolved(c: Cube): Bool =
        match coordsOf(c) {
            case Ok((cperm, eperm, mperm)) => cperm == 0 and eperm == 0 and mperm == 0
            case Err(_) => false
        }

    // ---------- move tables ----------

    ///
    /// A move table of `states` rows and one column per phase-two move.
    ///
    def movesOver(states: Int32, after: (Int32, Int32) -> Int32): Result[String, TableView] =
        region rc {
            let entries = states * moveCount();
            let payload = Table.emptyPayload(rc, 16, entries);
            Vector.range(0, states) |> Vector.forEach(r ->
                Vector.range(0, moveCount()) |> Vector.forEach(m ->
                    Table.putEntry(payload, 16, r * moveCount() + m, after(r, m))));
            Table.ofPayload(16, entries, payload)
        }

    ///
    /// The slot map of a whole move, composed from its quarter turn.
    ///
    /// This composition has to happen *before* the coordinate is restricted to
    /// its family, and that is not a stylistic preference. A half turn of `R`
    /// keeps the U/D edges among themselves, but the quarter turn it is made of
    /// does not -- after a single `R`, a slice edge is sitting in the U layer.
    /// Applying the quarter turn twice to an eight-entry coordinate therefore
    /// indexes off the end of it. Composing first and restricting afterwards
    /// asks only about the move phase two actually makes.
    ///
    def composed(perm: Vector[Int32], k: Int32): Vector[Int32] =
        Vector.init(i -> follow(perm, k, i), Vector.length(perm))

    ///
    /// Where slot `i` comes from after `k` applications of `perm`.
    ///
    def follow(perm: Vector[Int32], k: Int32, i: Int32): Int32 =
        if (k <= 0) i else follow(perm, k - 1, Vector.get(i, perm))

    ///
    /// The corner permutation table: `40320 x 10`.
    ///
    pub def cornerPermMoves(): Result[String, TableView] =
        movesOver(cornerPermCount(), (r, m) -> {
            let move = moveOfIndex(m);
            let perm = composed(Move.cornerPermutation(Move.face(move)), Move.amount(move));
            let p = permUnrank(r);
            permRank(Vector.init(i -> Vector.get(Vector.get(i, perm), p), 8))
        })

    ///
    /// The U/D-edge permutation table: `40320 x 10`.
    ///
    pub def edgePermMoves(): Result[String, TableView] =
        movesOver(edgePermCount(), (r, m) -> {
            let move = moveOfIndex(m);
            let perm = composed(Move.edgePermutation(Move.face(move)), Move.amount(move));
            let p = permUnrank(r);
            permRank(Vector.init(i -> Vector.get(Vector.get(i, perm), p), 8))
        })

    ///
    /// The slice-edge permutation table: `24 x 10`.
    ///
    pub def slicePermMoves(): Result[String, TableView] =
        movesOver(slicePermCount(), (r, m) -> {
            let move = moveOfIndex(m);
            let perm = composed(Move.edgePermutation(Move.face(move)), Move.amount(move));
            let p = slicePermUnrank(r);
            let cameFrom = i -> Vector.get(Vector.get(i + 8, perm) - 8, p);
            slicePermRank(Vector.init(cameFrom, 4))
        })

    ///
    /// The CComb table: `140 x 10`.
    ///
    /// Built by taking a representative corner permutation for each CComb
    /// value, moving it, and reading the result's CComb. Sound because CComb is
    /// a homomorphic projection: every permutation with the same CComb moves to
    /// permutations with the same CComb, so the representative's answer is
    /// everyone's.
    ///
    pub def combMoves(): Result[String, TableView] =
        let representative = representatives();
        movesOver(combCount(), (r, m) -> {
            let move = moveOfIndex(m);
            let perm = composed(Move.cornerPermutation(Move.face(move)), Move.amount(move));
            let start = permUnrank(Vector.get(r, representative));
            combOf(Vector.init(i -> Vector.get(Vector.get(i, perm), start), 8))
        })

    ///
    /// One corner-permutation rank per CComb value.
    ///
    def representatives(): Vector[Int32] = region rc {
        let found = Array.repeat(rc, combCount(), -1);
        def scan(r) =
            if (r >= cornerPermCount()) ()
            else {
                let c = combOf(permUnrank(r));
                if (Array.get(c, found) < 0) Array.put(r, c, found) else ();
                scan(r + 1)
            };
        scan(0);
        Array.toVector(found)
    }

    ///
    /// The CComb of each corner permutation: `40320` entries.
    ///
    /// CComb is a function of the corner permutation, so the search reads it
    /// from here rather than recomputing a parity and a combination rank at
    /// every node.
    ///
    pub def combOfCornerPerm(): Result[String, TableView] =
        region rc {
            let payload = Table.emptyPayload(rc, 16, cornerPermCount());
            Vector.range(0, cornerPermCount()) |> Vector.forEach(r ->
                Table.putEntry(payload, 16, r, combOf(permUnrank(r))));
            Table.ofPayload(16, cornerPermCount(), payload)
        }

    // ---------- the tables, together ----------

    ///
    /// Every phase-two table.
    ///
    pub enum Tables {
        case Tables({
            cornerPermMoves = TableView,
            edgePermMoves = TableView,
            slicePermMoves = TableView,
            combMoves = TableView,
            combOfCornerPerm = TableView,
            cornerSlice = TableView,
            edgeComb = TableView
        })
    }

    ///
    /// The move table on corner permutations.
    ///
    pub def cornerPermTable(p: Tables): TableView = let Tables(r) = p; r#cornerPermMoves

    ///
    /// The move table on U/D-edge permutations.
    ///
    pub def edgePermTable(p: Tables): TableView = let Tables(r) = p; r#edgePermMoves

    ///
    /// The move table on slice-edge permutations.
    ///
    pub def slicePermTable(p: Tables): TableView = let Tables(r) = p; r#slicePermMoves

    ///
    /// The move table on CComb.
    ///
    pub def combTable(p: Tables): TableView = let Tables(r) = p; r#combMoves

    ///
    /// The CComb of each corner permutation.
    ///
    pub def combLookup(p: Tables): TableView = let Tables(r) = p; r#combOfCornerPerm

    ///
    /// Pruning over `CPerm x MPerm`: 967,680 entries.
    ///
    pub def cornerSliceTable(p: Tables): TableView = let Tables(r) = p; r#cornerSlice

    ///
    /// Pruning over `EPerm x CComb`: 5,644,800 entries.
    ///
    pub def edgeCombTable(p: Tables): TableView = let Tables(r) = p; r#edgeComb

    ///
    /// Build every phase-two table.
    ///
    /// The pruning sweeps reach depth 14 and 13 respectively, which is why
    /// these are five-bit entries where phase one's are four.
    ///
    pub def build(): Result[String, Tables] =
        forM (
            cp <- cornerPermMoves();
            ep <- edgePermMoves();
            sp <- slicePermMoves();
            cb <- combMoves();
            lookup <- combOfCornerPerm();
            cs <- pairPruning(
                { moves = cp, count = cornerPermCount() },
                { moves = sp, count = slicePermCount() });
            ec <- pairPruning(
                { moves = ep, count = edgePermCount() },
                { moves = cb, count = combCount() })
        ) yield Tables({
            cornerPermMoves = cp,
            edgePermMoves = ep,
            slicePermMoves = sp,
            combMoves = cb,
            combOfCornerPerm = lookup,
            cornerSlice = cs,
            edgeComb = ec
        })

    ///
    /// Distance to the solved pair, in the product of two coordinates.
    ///
    /// Eight bits an entry. Phase two reaches depth 14, which needs five bits,
    /// and the next width up that packs whole is eight -- the table is small
    /// enough that the difference does not matter.
    ///
    def pairPruning(
        first: { moves = TableView, count = Int32 },
        second: { moves = TableView, count = Int32 }
    ): Result[String, TableView] =
        let k = moveCount();
        let firstMoves = first#moves;
        let secondMoves = second#moves;
        let secondCount = second#count;
        Table.distancesFrom(
            { states = first#count * secondCount, goal = 0, moves = k, bits = 8 },
            (s, m) -> {
                let a = Table.get(s / secondCount * k + m, firstMoves);
                let b = Table.get(Int32.modulo(s, secondCount) * k + m, secondMoves);
                a * secondCount + b
            })

}
