///
/// Solving the first layer: the cross, and the four corners above it.
///
/// **Two exact tables, combined by taking whichever says more.** The cross has
/// 190,080 states and the bottom corners 136,080, and each is small enough to
/// hold the true distance to solved. Neither alone bounds the pair, but the
/// larger of the two always does: a sequence finishing both must be at least as
/// long as the one finishing either. That is the same construction phase one of
/// the two-phase solver uses, at a size where both projections happen to be
/// exact rather than merely admissible.
///
/// **This is not the two-phase solver with a different goal.** It searches the
/// eighteen face turns for a sequence that leaves the whole first layer solved,
/// and the answer is short enough to teach -- which is the point of a method,
/// and why the general solver is not used to produce it. `Solve.Standard`
/// remains what solves cubes.
///
/// **It reports failure rather than guessing.** The search is bounded, and a
/// state it cannot finish inside that bound comes back as an error naming the
/// bound.
///
mod CubeSolve.Solve.FirstLayer {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Solve.IdaStar
    use CubeSolve.Solve.IdaStar.Phase
    use CubeSolve.Table
    use CubeSolve.Table.Cross
    use CubeSolve.Table.FirstLayer
    use CubeSolve.Table.TableView

    ///
    /// The two tables this solver reads.
    ///
    pub enum Tables with Eq {
        case Tables(TableView, TableView)
    }

    ///
    /// The furthest a first layer is from solved.
    ///
    /// Not proven here: it is the depth the search is allowed, chosen well above
    /// anything the corpus measurement reaches. A state needing more comes back
    /// as a failure, which is the honest answer for a bounded search.
    ///
    pub def searchDepth(): Int32 = 16

    ///
    /// Build both tables.
    ///
    pub def build(): Result[String, Tables] =
        forM (
            cross <- Cross.build();
            corners <- FirstLayer.build()
        ) yield Tables.Tables(cross, corners)

    ///
    /// Whether `c`'s first layer is solved.
    ///
    pub def isSolved(c: Cube.Cube): Bool =
        match (Cross.encode(c), FirstLayer.encode(c)) {
            case (Ok(x), Ok(y)) => x == Cross.solvedIndex() and y == FirstLayer.solvedIndex()
            case _              => false
        }

    ///
    /// A short sequence solving `c`'s first layer, or why there is none.
    ///
    pub def solution(t: Tables, c: Cube.Cube): Result[String, List[Move.Move]] =
        forM (
            cross <- Cross.encode(c);
            corners <- FirstLayer.encode(c);
            found <- search(t, pack(cross, corners))
        ) yield found

    ///
    /// The search itself, from a packed pair.
    ///
    def search(t: Tables, start: Int64): Result[String, List[Move.Move]] =
        IdaStar.search(phase(t), start, searchDepth())
            |> Result.mapErr(_ ->
                "no first layer within ${searchDepth()} moves: this state needs a "
                    + "longer search than this step allows")
            |> Result.map(f -> IdaStar.moves(f) |> List.filterMap(Move.ofIndex))

    ///
    /// The two coordinates in one machine integer.
    ///
    /// The pair does not fit an `Int32` -- 190,080 times 136,080 is about
    /// 2.6 x 10^10 -- and the search is generic in state width, so it rides in
    /// an `Int64` and costs nothing extra.
    ///
    pub def pack(cross: Int32, corners: Int32): Int64 =
        Int32.toInt64(cross) * Int32.toInt64(FirstLayer.stateCount())
            + Int32.toInt64(corners)

    ///
    /// The cross half of a packed pair.
    ///
    def crossOf(s: Int64): Int32 =
        Int64.tryToInt32(s / Int32.toInt64(FirstLayer.stateCount()))
            |> Option.getWithDefault(0)

    ///
    /// The corner half of a packed pair.
    ///
    def cornersOf(s: Int64): Int32 =
        Int64.tryToInt32(Int64.modulo(s, Int32.toInt64(FirstLayer.stateCount())))
            |> Option.getWithDefault(0)

    ///
    /// The phase the search runs.
    ///
    def phase(t: Tables): Phase[Int64] =
        let Tables.Tables(crossTable, cornerTable) = t;
        IdaStar.phase(
            Cross.moveCount(),
            (s, m) -> pack(Cross.successor(crossOf(s), m),
                FirstLayer.successor(cornersOf(s), m)),
            s -> Int32.max(Table.get(crossOf(s), crossTable),
                Table.get(cornersOf(s), cornerTable)),
            s -> crossOf(s) == Cross.solvedIndex()
                and cornersOf(s) == FirstLayer.solvedIndex(),
            Move.htmPruningAllows)

}
