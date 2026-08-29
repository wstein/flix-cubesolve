///
/// Searching inside the domino group: the 3x3x3's phase two.
///
/// Once phase one has finished, the cube is in `<U, D, R2, L2, F2, B2>` and can
/// be solved without another quarter turn of a side face. This is the search
/// over that subgroup. `CubeSolve.Table.Domino` holds its coordinates and
/// tables; `CubeSolve.Solve.Standard` is what puts the two phases together.
///
mod CubeSolve.Solve.Domino {

    use CubeSolve.Solve.IdaStar
    use CubeSolve.Solve.IdaStar.Phase
    use CubeSolve.Table
    use CubeSolve.Table.Domino

    ///
    /// Phase two's tables.
    ///
    /// Re-exported for the same reason phase one's are: a caller combining the
    /// phases should talk to the phase, not to its table module.
    ///
    pub type alias Tables = Domino.Tables

    ///
    /// Build phase two's tables.
    ///
    pub def buildTables(): Result[String, Tables] = Domino.build()

    ///
    /// Phase two's tables, from the cache where possible.
    ///
    pub def cachedTables(): Result[String, Tables] \ CubeSolve.Table.Cache.Store =
        Domino.cachedTables()

    ///
    /// The move with index `m` in phase two's alphabet.
    ///
    pub def moveOfIndex(m: Int32): CubeSolve.Model.Move.Move = Domino.moveOfIndex(m)

    ///
    /// The phase-two coordinates of a cube, if it is inside the domino group.
    ///
    pub def coordsOf(c: CubeSolve.Model.Cube.Cube): Result[String, (Int32, Int32, Int32)] =
        Domino.coordsOf(c)

    ///
    /// The deepest phase two ever needs.
    ///
    /// Eighteen. The `CPerm x MPerm` pruning table reaches 14 and no domino
    /// state is further than that from solved along the coordinates the search
    /// tracks, so this is comfortable rather than tight.
    ///
    pub def maxPhase2Depth(): Int32 = 18

    ///
    /// The three phase-two coordinates packed into one state.
    ///
    /// `CPerm x EPerm x MPerm` is 40320 x 40320 x 24, about 3.9 x 10^10, so
    /// this is an `Int64` for the same reason phase one's is.
    ///
    pub def packPhase2(cperm: Int32, eperm: Int32, mperm: Int32): Int64 =
        let slices = Int32.toInt64(Domino.slicePermCount());
        let edges = Int32.toInt64(Domino.edgePermCount());
        (Int32.toInt64(cperm) * edges + Int32.toInt64(eperm)) * slices + Int32.toInt64(mperm)

    ///
    /// Phase two as a search phase.
    ///
    pub def phase2Of(p: Domino.Tables): Phase[Int64] =
        IdaStar.phase(
            Domino.moveCount(),
            phase2Successor(p),
            phase2Heuristic(p),
            s -> s == 0i64,
            Domino.pruningAllows
        )

    ///
    /// Where a phase-two move leads.
    ///
    def phase2Successor(p: Domino.Tables): (Int64, Int32) -> Int64 =
        let cm = Domino.cornerPermTable(p);
        let em = Domino.edgePermTable(p);
        let sm = Domino.slicePermTable(p);
        let k = Domino.moveCount();
        (s, m) -> {
            let cperm = Table.get(cornerPermOf(s) * k + m, cm);
            let eperm = Table.get(edgePermOf(s) * k + m, em);
            let mperm = Table.get(slicePermOf(s) * k + m, sm);
            packPhase2(cperm, eperm, mperm)
        }

    ///
    /// The larger of the two phase-two pruning bounds.
    ///
    def phase2Heuristic(p: Domino.Tables): Int64 -> Int32 =
        let cornerSlice = Domino.cornerSliceTable(p);
        let edgeComb = Domino.edgeCombTable(p);
        let lookup = Domino.combLookup(p);
        let slices = Domino.slicePermCount();
        let combs = Domino.combCount();
        s -> {
            let cperm = cornerPermOf(s);
            let a = Table.get(cperm * slices + slicePermOf(s), cornerSlice);
            let b = Table.get(edgePermOf(s) * combs + Table.get(cperm, lookup), edgeComb);
            Int32.max(a, b)
        }

    ///
    /// The corner permutation of a packed phase-two state.
    ///
    pub def cornerPermOf(s: Int64): Int32 =
        narrow(s / Int32.toInt64(Domino.slicePermCount()) / Int32.toInt64(Domino.edgePermCount()))

    ///
    /// The U/D-edge permutation of a packed phase-two state.
    ///
    pub def edgePermOf(s: Int64): Int32 =
        let slices = Int32.toInt64(Domino.slicePermCount());
        narrow(Int64.modulo(s / slices, Int32.toInt64(Domino.edgePermCount())))

    ///
    /// The slice-edge permutation of a packed phase-two state.
    ///
    pub def slicePermOf(s: Int64): Int32 =
        narrow(Int64.modulo(s, Int32.toInt64(Domino.slicePermCount())))

    ///
    /// A coordinate that is known to fit, as an `Int32`.
    ///
    def narrow(v: Int64): Int32 = Int64.tryToInt32(v) |> Option.getWithDefault(0)

}
