///
/// The optimal 2x2x2 solver.
///
/// Optimal, not merely correct: the 2x2x2's whole state space fits in a table,
/// so there is no reason to accept a longer answer than the shortest one. Every
/// solution this returns is of the exact minimum length, and a test checks that
/// against the oracle rather than against a claim.
///
/// The search is the same `CubeSolve.Solve.IdaStar` every other size uses. What
/// this module supplies is the phase: a successor built from the factored move
/// tables, and a heuristic that is the larger of the two admissible
/// projections.
///
/// **Two heuristics rather than one.** Orientation alone tops out at 6 and
/// permutation alone at 7, against a diameter of 11, so either used by itself
/// leaves the search almost unguided through the distance range where nearly
/// every state lies. Their maximum is still admissible -- the larger of two
/// lower bounds is a lower bound -- and it cuts the search by more than a
/// factor of ten for a table of five kilobytes.
///
mod CubeSolve.Solve.Pocket {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Sized
    use CubeSolve.Model.Move
    use CubeSolve.Solve.IdaStar
    use CubeSolve.Solve.IdaStar.Phase
    use CubeSolve.Table
    use CubeSolve.Table.Pocket

    ///
    /// The longest any 2x2x2 needs, and so the depth beyond which a search has
    /// certainly gone wrong.
    ///
    /// Eleven, measured rather than assumed: the exhaustive sweep finds 2,644
    /// states at distance 11 and none beyond.
    ///
    pub def diameter(): Int32 = 11

    ///
    /// The 2x2x2 as a search phase, guided by both admissible projections.
    ///
    pub def phaseOf(t: Pocket.Tables): Phase[Int32] =
        IdaStar.phase(
            Pocket.moveCount(),
            successorOf(t),
            heuristicOf(t),
            s -> s == Pocket.solvedIndex(),
            Move.htmPruningAllows
        )

    ///
    /// The same phase with move pruning switched off.
    ///
    /// Only useful for showing what the pruning is worth: the two must return
    /// solutions of the same length, and the pruned one must visit far fewer
    /// nodes. A pruning rule that changed an answer would be a bug, and this is
    /// how that is checked.
    ///
    pub def unprunedPhaseOf(t: Pocket.Tables): Phase[Int32] =
        IdaStar.phase(
            Pocket.moveCount(),
            successorOf(t),
            heuristicOf(t),
            s -> s == Pocket.solvedIndex(),
            (_, _) -> true
        )

    ///
    /// The same phase guided by one projection only, named by `useOrientation`.
    ///
    /// Kept because it is what makes the case for using both: each is
    /// admissible on its own, so this returns optimal solutions too, just far
    /// more slowly.
    ///
    pub def singleProjectionPhaseOf(t: Pocket.Tables, useOrientation: Bool): Phase[Int32] =
        let table = if (useOrientation) Pocket.oriDistanceTable(t) else Pocket.permDistanceTable(t);
        let index =
            if (useOrientation) s -> Int32.modulo(s, Pocket.oriCount())
            else s -> s / Pocket.oriCount();
        IdaStar.phase(
            Pocket.moveCount(),
            successorOf(t),
            s -> Table.get(index(s), table),
            s -> s == Pocket.solvedIndex(),
            Move.htmPruningAllows
        )

    ///
    /// Where a move leads, through the factored move tables.
    ///
    def successorOf(t: Pocket.Tables): (Int32, Int32) -> Int32 =
        let pm = Pocket.permMoveTable(t);
        let om = Pocket.oriMoveTable(t);
        let n = Pocket.oriCount();
        let k = Pocket.moveCount();
        (s, m) -> {
            let perm = Table.get(s / n * k + m, pm);
            let ori = Table.get(Int32.modulo(s, n) * k + m, om);
            perm * n + ori
        }

    ///
    /// The larger of the two admissible projections.
    ///
    def heuristicOf(t: Pocket.Tables): Int32 -> Int32 =
        let oriD = Pocket.oriDistanceTable(t);
        let permD = Pocket.permDistanceTable(t);
        let n = Pocket.oriCount();
        s -> {
            let byOrientation = Table.get(Int32.modulo(s, n), oriD);
            let byPermutation = Table.get(s / n, permD);
            Int32.max(byOrientation, byPermutation)
        }

    ///
    /// The exact distance from `state` to solved, straight from the oracle.
    ///
    /// The 2x2x2 is small enough that this is a lookup rather than a search,
    /// which is what lets every solution be checked for optimality rather than
    /// merely for validity.
    ///
    pub def distanceOf(t: Pocket.Tables, state: Int32): Result[String, Int32] =
        Table.tryGet(state, Pocket.distanceTable(t))

    ///
    /// A shortest solution for `c`, or why there is none.
    ///
    pub def solution(t: Pocket.Tables, c: Sized.Pocket): Result[String, List[Move.Move]] =
        Pocket.encode(Sized.cubeOfPocket(c)) |> Result.flatMap(s -> solutionForState(t, s))

    ///
    /// A shortest solution for the state with coordinate `state`.
    ///
    pub def solutionForState(t: Pocket.Tables, state: Int32): Result[String, List[Move.Move]] =
        IdaStar.search(phaseOf(t), state, diameter())
            |> Result.map(f -> IdaStar.moves(f) |> List.map(Pocket.moveOfIndex))

}
