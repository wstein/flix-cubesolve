///
/// Solving the first two layers: the cross, the corners above it, and the four
/// edges between the centres.
///
/// Four exact projections, combined by taking whichever says most. Each is the
/// true distance for the pieces it tracks, so each is a lower bound on finishing
/// all of them, and the largest is the best of the four.
///
/// **What this promises is a bounded search, not a proven optimum.** The bound
/// is admissible by construction, so a solution it finds is a shortest one --
/// but the search stops at `searchDepth()` and reports failure beyond it, and
/// nothing here proves that bound is never reached. Read it as a short,
/// teachable answer that is optimal when one is found, rather than as a global
/// optimality claim.
///
/// **Whether the bound is strong enough was a measurement, not an assumption.**
/// Run after the first layer is solved, the cross and corner projections both
/// read zero while the real distance does not, because the layer has to be
/// disturbed and put back. With only those three the search spent between 4.1
/// and 84.5 million nodes over an eight-state corpus, and 7.6 times as many on
/// one depth-11 state as on another. The paired projection was added on that
/// evidence and cut the worst case to 13.2 million; the figures are in
/// `docs/architecture.md`.
///
mod CubeSolve.Solve.TwoLayers {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Solve.IdaStar
    use CubeSolve.Solve.IdaStar.Phase
    use CubeSolve.Table
    use CubeSolve.Solve.TwoLayers.Packed
    use CubeSolve.Table.CornerEdgePair
    use CubeSolve.Table.Cache
    use CubeSolve.Table.Cross
    use CubeSolve.Table.FirstLayer
    use CubeSolve.Table.MiddleEdges
    use CubeSolve.Table.TableView

    ///
    /// The four tables this solver reads.
    ///
    /// Three separate projections and one paired one. The pair is not
    /// redundant: it is the only one that can see the cost of restoring what a
    /// move disturbs, which is what the separate ones are blind to once the
    /// first layer is solved and two of them read zero.
    ///
    pub enum Tables with Eq {
        case Tables(TableView, TableView, TableView, TableView)
    }

    ///
    /// How deep the search is allowed to go before giving up.
    ///
    pub def searchDepth(): Int32 = 20

    ///
    /// Build all four tables.
    ///
    pub def build(): Result[String, Tables] =
        forM (
            cross <- Cross.build();
            corners <- FirstLayer.build();
            middles <- MiddleEdges.build();
            paired <- CornerEdgePair.build()
        ) yield Tables.Tables(cross, corners, middles, paired)

    ///
    /// The same four tables, read from the cache where they are there.
    ///
    /// **Prefer this to `build`.** These four are 3.8 million states between
    /// them and take a minute or two to construct; `build` pays that on every
    /// call. A command line that solves one cube per process and calls `build`
    /// is not slow once, it is slow every time -- which is exactly what
    /// happened to `--method cfop` and `--method beginner` in v0.4.0 and
    /// v0.4.1, at about a hundred seconds per invocation, warm or cold.
    ///
    pub def cachedTables(): Result[String, Tables] \ Cache.Store =
        forM (
            cross <- Cross.cached();
            corners <- FirstLayer.cached();
            middles <- MiddleEdges.cached();
            paired <- CornerEdgePair.cached()
        ) yield Tables.Tables(cross, corners, middles, paired)

    ///
    /// Whether `c`'s first two layers are solved.
    ///
    pub def isSolved(c: Cube.Cube): Bool =
        match (Cross.encode(c), FirstLayer.encode(c), MiddleEdges.encode(c)) {
            case (Ok(x), Ok(y), Ok(z)) =>
                x == Cross.solvedIndex()
                    and y == FirstLayer.solvedIndex()
                    and z == MiddleEdges.solvedIndex()
            case _ => false
        }

    ///
    /// A sequence solving `c`'s first two layers, or why there is none.
    ///
    pub def solution(t: Tables, c: Cube.Cube): Result[String, List[Move.Move]] =
        found(t, c) |> Result.map(f -> IdaStar.moves(f) |> List.filterMap(Move.ofIndex))

    ///
    /// The search result, node count included.
    ///
    /// Public because the node count is the only honest measure of whether the
    /// heuristic is doing its job, and the corpus measurement needs it.
    ///
    pub def found(t: Tables, c: Cube.Cube): Result[String, IdaStar.Found] =
        forM (
            cross <- Cross.encode(c);
            corners <- FirstLayer.encode(c);
            middles <- MiddleEdges.encode(c);
            _ <- CornerEdgePair.encode(c);
            f <- IdaStar.search(phase(t), Packed.pack(cross, corners, middles), searchDepth())
                |> Result.mapErr(_ ->
                    "no first two layers within ${searchDepth()} moves: this state "
                        + "needs a longer search than this step allows")
        ) yield f


    ///
    /// The phase the search runs.
    ///
    def phase(t: Tables): Phase[Int64] =
        IdaStar.phase(
            Cross.moveCount(),
            step,
            s -> best(t, s),
            isGoal,
            Move.htmPruningAllows)

    ///
    /// One move applied to all three coordinates at once.
    ///
    def step(s: Int64, m: Int32): Int64 =
        Packed.pack(Cross.successor(Packed.crossOf(s), m),
            FirstLayer.successor(Packed.cornersOf(s), m),
            MiddleEdges.successor(Packed.middlesOf(s), m))

    ///
    /// The largest of the four lower bounds.
    ///
    /// Each is the true distance for the pieces it tracks, so each bounds the
    /// whole; the largest is the best of them. The paired one is usually the
    /// largest once the first layer is solved, which is the reason it is here.
    ///
    def best(t: Tables, s: Int64): Int32 =
        let Tables.Tables(cross, corners, middles, paired) = t;
        Int32.max(
            Int32.max(atCross(s, cross), atCorners(s, corners)),
            Int32.max(atMiddles(s, middles), atPair(s, paired)))

    ///
    /// What the cross projection says from here.
    ///
    def atCross(s: Int64, t: TableView): Int32 = Table.get(Packed.crossOf(s), t)

    ///
    /// What the corner projection says.
    ///
    def atCorners(s: Int64, t: TableView): Int32 = Table.get(Packed.cornersOf(s), t)

    ///
    /// What the middle-edge projection says.
    ///
    def atMiddles(s: Int64, t: TableView): Int32 = Table.get(Packed.middlesOf(s), t)

    ///
    /// What the paired projection says -- usually the largest of the four once
    /// the first layer is solved, which is the reason it exists.
    ///
    def atPair(s: Int64, t: TableView): Int32 = Table.get(pairedOf(s), t)

    ///
    /// Three coordinates in one machine integer, for a caller building a state.
    ///
    pub def pack(cross: Int32, corners: Int32, middles: Int32): Int64 =
        Packed.pack(cross, corners, middles)

    ///
    /// The first-layer tables, which these already contain.
    ///
    /// The cross and corner projections are shared: the first layer is solved
    /// with two of them and the two layers with all four, so building both sets
    /// separately would construct the same 326,160 states twice.
    ///
    pub def firstLayerTables(t: Tables): CubeSolve.Solve.FirstLayer.Tables =
        let Tables.Tables(cross, corners, _, _) = t;
        CubeSolve.Solve.FirstLayer.Tables.Tables(cross, corners)

    ///
    /// How many nodes a search expanded.
    ///
    /// Re-exported so a caller measuring the heuristic does not have to reach
    /// into the search itself.
    ///
    pub def nodesOf(f: IdaStar.Found): Int64 = IdaStar.nodes(f)

    ///
    /// The moves a search found.
    ///
    pub def movesOf(f: IdaStar.Found): List[Move.Move] =
        IdaStar.moves(f) |> List.filterMap(Move.ofIndex)

    ///
    /// The paired projection's table, for a caller checking it is closed.
    ///
    /// Exposed so the assertion can live with the fixture that builds it rather
    /// than in a module that would have to build 3.2 million states again to
    /// say the same thing.
    ///
    pub def pairedTable(t: Tables): TableView =
        let Tables.Tables(_, _, _, paired) = t;
        paired

    ///
    /// How many states the paired projection has.
    ///
    pub def pairedStateCount(): Int32 = CornerEdgePair.stateCount()

    ///
    /// Where the paired projection's solved state sits.
    ///
    pub def pairedSolvedIndex(): Int32 = CornerEdgePair.solvedIndex()

    ///
    /// The paired coordinate of a packed triple.
    ///
    /// Derived rather than packed alongside the others: the corner half is
    /// already in the state and the edge half is read out of the middle-edge
    /// half, so carrying it separately would be a fourth copy of two things
    /// already there, free to drift. Read arithmetically rather than by
    /// unranking, because this runs on every node and `unrank` allocates.
    ///
    pub def pairedOf(s: Int64): Int32 =
        let (slot, flip) = Cross.firstPiece(Packed.middlesOf(s));
        CornerEdgePair.rank(Packed.cornersOf(s), slot, flip)

    ///
    /// Whether all three are home.
    ///
    def isGoal(s: Int64): Bool =
        Packed.crossOf(s) == Cross.solvedIndex()
            and Packed.cornersOf(s) == FirstLayer.solvedIndex()
            and Packed.middlesOf(s) == MiddleEdges.solvedIndex()

}
