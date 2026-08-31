///
/// Solving the cross, the first step of the CFOP method.
///
/// **Optimal, and not by luck.** The whole coordinate is 190,080 states, so the
/// distance to solved is tabulated for every one of them and the search's
/// heuristic is exact. An IDA* with an exact heuristic expands only nodes on an
/// optimal path, so the first solution found is a shortest one and there is
/// nothing to improve on.
///
/// **It solves the cross and says nothing about the rest.** Everything above the
/// bottom layer is ignored, which is the point: the answer is a step, not a
/// solution, and `CubeSolve.Solve.Standard` remains the thing that solves cubes.
///
mod CubeSolve.Solve.Cross {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Solve.IdaStar
    use CubeSolve.Solve.IdaStar.Phase
    use CubeSolve.Table
    use CubeSolve.Table.Cross
    use CubeSolve.Table.TableView

    ///
    /// The furthest any cross is from solved.
    ///
    /// Eight, and measured rather than assumed -- the exhaustive sweep that
    /// builds the table reports it, and a test asserts it.
    ///
    pub def diameter(): Int32 = 8

    ///
    /// The table this solver reads.
    ///
    pub def build(): Result[String, TableView] = Cross.build()

    ///
    /// Whether `c`'s cross is already solved.
    ///
    /// Asked of the coordinate rather than of the four slots directly, so that
    /// what counts as solved here and what the table was built around cannot
    /// come apart.
    ///
    pub def isSolved(c: Cube.Cube): Bool =
        Cross.encode(c) |> Result.map(i -> i == Cross.solvedIndex())
            |> Result.getWithDefault(false)

    ///
    /// A shortest sequence solving `c`'s cross, or why there is none.
    ///
    pub def solution(
        t: TableView,
        c: Cube.Cube,
        maxNodes: Int64
    ): Result[String, List[Move.Move]] =
        forM (
            start <- Cross.encode(c);
            found <- search(t, start, maxNodes)
        ) yield found

    ///
    /// The search itself, from a coordinate.
    ///
    def search(
        t: TableView,
        start: Int32,
        maxNodes: Int64
    ): Result[String, List[Move.Move]] =
        IdaStar.search(phase(t), start, diameter(), maxNodes)
            |> Result.map(f -> IdaStar.moves(f)
                |> List.filterMap(i -> Move.ofIndex(i)))

    ///
    /// The phase the search runs.
    ///
    /// The heuristic is a table read and is exact, so `allows` is the only
    /// pruning that matters for speed and none of it is needed for correctness.
    ///
    def phase(t: TableView): Phase[Int32] =
        IdaStar.phase(
            Cross.moveCount(),
            Cross.successor,
            s -> Table.get(s, t),
            s -> s == Cross.solvedIndex(),
            Move.htmPruningAllows)

}
