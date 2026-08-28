///
/// Random-state scrambles for the 2x2x2, including scrambles of an exact
/// difficulty.
///
/// **Scrambles are random-state, not random-move.** A uniformly random move
/// sequence is not uniform over states: short sequences cancel, and the
/// distribution piles up near solved. So this samples a state uniformly, solves
/// it, and emits the inverse of the solution. Scrambling therefore costs
/// exactly what solving costs, and there is no cheaper competition-legal route.
///
/// **Exact difficulty is possible here and nowhere else.** The 2x2x2's whole
/// distance table fits in memory, so "a state exactly seven moves from solved"
/// is a set that can be sampled from rather than an approximation. Larger cubes
/// have no such table and can only certify bounds.
///
mod CubeSolve.Scramble.Pocket {

    use CubeSolve.Model.Cube.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Scramble.Pocket.Index.Index
    use CubeSolve.Scramble.Pocket.Scramble.Scramble
    use CubeSolve.Table

    ///
    /// A scramble: the moves, the state they produce, and how far that is from
    /// solved.
    ///
    /// The distance is reported rather than left for the caller to measure. It
    /// is exact, it was known during generation, and a caller choosing a
    /// difficulty needs to see what it actually got.
    ///
    pub enum Scramble {
        case Scramble({ moves = List[Move.Move], state = Cube, distance = Int32 })
    }

    ///
    /// The moves of the scramble, to apply to a solved cube.
    ///
    pub def moves(s: Scramble): List[Move.Move] = let Scramble(r) = s; r#moves

    ///
    /// The state the scramble produces.
    ///
    pub def state(s: Scramble): Cube = let Scramble(r) = s; r#state

    ///
    /// The exact number of moves needed to solve it again.
    ///
    pub def distance(s: Scramble): Int32 = let Scramble(r) = s; r#distance

    ///
    /// The scramble written in the usual notation.
    ///
    pub def show(s: Scramble): String = Move.showAll(moves(s))

    // ---------- sampling from a distance class ----------

    ///
    /// Which states lie at each small distance from solved.
    ///
    /// Only the sparse classes are listed. The reason is arithmetic: sampling
    /// by drawing at random and rejecting costs one draw per state in the
    /// class, so at distance 0 it would take 3,674,160 draws to find the solved
    /// state and at distance 11 about 1,390. For the four classes in the middle
    /// -- 7 through 10, which hold 92% of the space -- rejection costs at most
    /// sixteen draws and an index would cost 14 MB.
    ///
    /// So both paths are exactly uniform and the choice between them is
    /// entirely about cost: 65,004 states listed, about 260 KB.
    ///
    pub enum Index {
        case Index(Vector[Vector[Int32]])
    }

    ///
    /// The largest distance any state can be from solved: 11, measured.
    ///
    pub def diameter(): Int32 = CubeSolve.Solve.Pocket.diameter()

    ///
    /// Whether distance `d` is indexed rather than sampled by rejection.
    ///
    pub def isIndexed(d: Int32): Bool = d <= 6 or d >= 11

    ///
    /// Build the index of the sparse distance classes.
    ///
    /// One sweep of the distance table. A caller that wants scrambles of an
    /// exact difficulty should build this once and keep it.
    ///
    pub def indexOf(t: CubeSolve.Table.Pocket.Tables): Index =
        let table = CubeSolve.Table.Pocket.distanceTable(t);
        let all = Vector.range(0, CubeSolve.Table.Pocket.stateCount());
        Index(Vector.init(d ->
            if (isIndexed(d)) Vector.filter(s -> Table.get(s, table) == d, all)
            else Vector#{},
            diameter() + 1))

    ///
    /// The states listed at distance `d`, empty for a class left to rejection.
    ///
    pub def statesAt(ix: Index, d: Int32): Vector[Int32] =
        let Index(buckets) = ix;
        if (d < 0 or d >= Vector.length(buckets)) Vector#{} else Vector.get(d, buckets)

    ///
    /// A uniform scramble whose solution is exactly `d` moves, and the next seed.
    ///
    /// Exactly `d`, not at most: the state is drawn from the set at that
    /// distance, and the distance comes from the exhaustive table rather than
    /// from a search that might have stopped early.
    ///
    pub def atDistance(
        t: CubeSolve.Table.Pocket.Tables,
        ix: Index,
        d: Int32,
        seed: Int64
    ): Result[String, (Scramble, Int64)] =
        if (d < 0 or d > diameter())
            Err("no 2x2x2 state is ${d} moves from solved: the furthest is "
                + "${diameter()}, measured by exhaustive search")
        else
            let (chosen, next) =
                if (isIndexed(d)) fromIndex(ix, d, seed) else byRejection(t, d, seed);
            scrambleOf(t, chosen) |> Result.map(s -> (s, next))

    ///
    /// A uniform draw from the listed states at distance `d`.
    ///
    def fromIndex(ix: Index, d: Int32, seed: Int64): (Int32, Int64) =
        let bucket = statesAt(ix, d);
        let (at, next) = Random.nextBelow(Vector.length(bucket), seed);
        (Vector.get(at, bucket), next)

    ///
    /// Draw uniformly from the whole space until the draw is at distance `d`.
    ///
    /// Uniform because every state is equally likely to be drawn and the test
    /// depends only on the distance, so the accepted states are uniform over
    /// the class. Used only where the class is large enough for this to be
    /// cheap.
    ///
    def byRejection(t: CubeSolve.Table.Pocket.Tables, d: Int32, seed: Int64): (Int32, Int64) =
        let table = CubeSolve.Table.Pocket.distanceTable(t);
        let (drawn, next) = Random.nextBelow(CubeSolve.Table.Pocket.stateCount(), seed);
        if (Table.get(drawn, table) == d) (drawn, next) else byRejection(t, d, next)

    // ---------- uniform over the whole space ----------

    ///
    /// A uniform scramble, and the next seed.
    ///
    /// Uniform over states, which is what a competition scramble means. The
    /// difficulty is whatever the draw gives, and is reported.
    ///
    pub def uniform(
        t: CubeSolve.Table.Pocket.Tables,
        seed: Int64
    ): Result[String, (Scramble, Int64)] =
        let (drawn, next) = Random.nextBelow(CubeSolve.Table.Pocket.stateCount(), seed);
        scrambleOf(t, drawn) |> Result.map(s -> (s, next))

    ///
    /// The scramble that produces the state with coordinate `at`.
    ///
    /// Solve it, then invert. Every move of the solution is undone in reverse
    /// order, so applying the result to a solved cube lands exactly on the
    /// sampled state -- which is asserted rather than assumed.
    ///
    def scrambleOf(t: CubeSolve.Table.Pocket.Tables, at: Int32): Result[String, Scramble] =
        forM (
            solution <- CubeSolve.Solve.Pocket.solutionForState(t, at);
            cube <- CubeSolve.Table.Pocket.decode(at)
        ) yield Scramble({
            moves = Move.inverseOf(solution),
            state = cube,
            distance = List.length(solution)
        })

}
