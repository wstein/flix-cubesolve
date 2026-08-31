mod PocketSearchTestSupport {

    use CubeSolve.Model.Cube
    use CubeSolve.Table

    /// Every 2x2x2 table.
    pub def tables(): Table.Pocket.Tables \ Assert =
        match Table.Pocket.build() {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    /// The states at exactly distance 11 -- the deepest, and the worst case for
    /// the search. There are 2,644 of them.
    pub def deepestStates(t: Table.Pocket.Tables): Vector[Int32] =
        let d = Table.Pocket.distanceTable(t);
        Vector.range(0, Table.Pocket.stateCount())
            |> Vector.filter(i -> Table.get(i, d) == 11)

    /// Checks that the search returns a solution of exactly the oracle's
    /// distance for `state`, and that replaying it really solves the cube.
    pub def assertOptimal(t: Table.Pocket.Tables, state: Int32): Unit \ Assert =
        let exact = Table.get(state, Table.Pocket.distanceTable(t));
        match CubeSolve.Solve.Pocket.solutionForState(t, state) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "state ${state}")
            case Ok(ms) =>
                Assert.assertEqWithMsg(
                    expected = exact, List.length(ms),
                    "state ${state} has distance ${exact} but the search returned "
                        + "${List.length(ms)} moves");
                let replayed = Table.Pocket.decode(state)
                    |> Result.flatMap(c -> Cube.applyAll(ms, c))
                    |> Result.map(Cube.isSolved);
                Assert.assertEqWithMsg(
                    expected = Ok(true), replayed,
                    "the solution for state ${state} did not replay to solved")
        }

}
