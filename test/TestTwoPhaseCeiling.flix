///
/// Why the two-phase solver stops where it does on a hard cube.
///
/// `A_VAs734dSkb` has a seventeen-move solution. This solver answers it in
/// nineteen at every budget, and the reason is structural rather than a matter
/// of spending more.
///
/// **The seventeen has no two-phase decomposition.** A two-phase solution is a
/// prefix reaching the domino group and a finish inside it. Checked move by
/// move, this one first reaches that group after all seventeen of its moves --
/// which is to say when the cube is already solved. Phase one would have to be
/// seventeen moves long, and it is bounded at twelve.
///
/// **Spending more does not help, and the counters say why.** Raising the
/// handover limit from 300 to 9600 enumerates sixteen times as many phase-one
/// endings, and the admissible lower bound rejects 99.5% of them before phase
/// two is attempted: they are proved unable to beat nineteen. Only about 280
/// are ever tried, and the answer does not move.
///
/// ```text
///   handovers  HTM  probes  selected  pruned  limit hit
///   300        20   170     3622      3452    yes
///   600        19   119     6454      6335    yes
///   1200       19   155     10760     10605   yes
///   9600       19   281     51690     51409   yes
/// ```
///
/// So the gap between nineteen and seventeen is the gap between a two-phase
/// solver and an optimal one, and no budget closes it. Closing it means a
/// different search -- IDA* over the whole cube against pattern databases --
/// which this engine does not have and which would not be `Solve.Standard`.
///
mod TestTwoPhaseCeiling {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Holding
    use CubeSolve.Model.Move
    use CubeSolve.Table.Standard

    def token(): String = "A_VAs734dSkb"

    ///
    /// A seventeen-move solution for it, from outside this engine.
    ///
    /// Recorded so the claim above is checkable rather than asserted: it is
    /// replayed here, and it solves.
    ///
    def seventeen(): String =
        "F2 U' L' F D' B L2 R2 U' B' R2 F' D2 F R' D' R"

    ///
    /// The seventeen is real, and it has no phase split.
    ///
    /// Both halves of the finding in one test, because either alone is
    /// misleading: a solution that did not solve would prove nothing, and a
    /// split that was never checked would leave "our solver should find it" as
    /// an open question when it is a closed one.
    ///
    @Test
    def aShorterSolutionExistsAndTwoPhaseCannotExpressIt(): Unit \ Assert =
        match Holding.ofToken(3, token()) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "the token")
            case Ok(c)  =>
                match Cube.applyNotation(seventeen(), c) {
                    case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "replaying")
                    case Ok(done) =>
                        Assert.assertTrueWithMsg(Cube.isSolved(done),
                            "the recorded seventeen should solve the cube")
                };
                Assert.assertEqWithMsg(expected = 17, entersDominoAfter(c),
                    "the seventeen reaches the domino group only at its end, so "
                        + "phase one would have to be all of it")
        }

    ///
    /// After how many of its moves the solution first reaches the domino group.
    ///
    def entersDominoAfter(c: Cube.Cube): Int32 =
        match Move.parse(seventeen()) {
            case Err(_) => -1
            case Ok(ms) =>
                Vector.range(0, List.length(ms) + 1)
                    |> Vector.findLeft(k -> match Cube.applyAll(List.take(k, ms), c) {
                        case Ok(st) => Standard.isPhase1Solved(st)
                        case Err(_) => false
                    })
                    |> Option.getWithDefault(-1)
        }
}
