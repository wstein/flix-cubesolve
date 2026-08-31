///
/// The anytime interface: a first answer straight away, better ones on request.
///
/// Two of the plan's gates live here.
///
/// - **Gate 7.3** -- a starved `probeMax` reaches the exhaustion path and
///   returns the documented reason rather than hanging or claiming success.
/// - **Gate 7.4** -- `next` never returns a longer solution than its
///   predecessor.
///
mod TestResumableSearch {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard
    use CubeSolve.Solve.Standard.Step

    ///
    /// Everything the anytime interface must satisfy, on one set of tables.
    ///
    /// Written as one test for the reason the pattern tests are: the 3x3x3
    /// tables take about thirty seconds to build and nothing here can share
    /// them across `@Test` functions, so five tests would spend two and a half
    /// minutes building the same tables five times. Each property is its own
    /// function below and names itself in its failure message, so a failure
    /// still says which one broke.
    ///
    /// **Stratified, and here is the stratification.** Driving a search to
    /// exhaustion means searching all six views, so these properties cost solver
    /// time rather than table time. Gate 7.4 runs three fixed seeds under
    /// `thoroughBudget`, which is the budget that produces the most improvements
    /// and so the longest chain to check monotonicity over; the comparison
    /// against `solution` runs two seeds under `defaultBudget`, the budget it
    /// compares against; and the two exhaustion properties run one seed each,
    /// because a reason string does not vary with the cube. Seeds are fixed, so
    /// a failure replays.
    ///
    /// - **Gate 7.4** -- `eachSolutionIsStrictlyShorterAndStillSolves`
    /// - **Gate 7.3** -- `aStarvedBudgetExplainsItself` and
    ///   `aSearchOutOfViewsSaysSo`
    /// - Resumption keeps ground -- `continuingUnderALargerBudgetNeverLosesGround`
    /// - The interface is not a worse way to solve --
    ///   `drivingByHandIsNoWorseThanAskingOutright`
    ///
    @Test
    def theAnytimeInterfaceKeepsItsPromises(): Unit \ Assert + IO =
        if (Slow.skip("TestResumableSearch.theAnytimeInterfaceKeepsItsPromises",
                "runs the anytime search to exhaustion"))
            ()
        else {
            let t = tables();
            eachSolutionIsStrictlyShorterAndStillSolves(t);
            aStarvedBudgetExplainsItself(t);
            aSearchOutOfViewsSaysSo(t);
            continuingUnderALargerBudgetNeverLosesGround(t);
            drivingByHandIsNoWorseThanAskingOutright(t)
        }

    def tables(): Standard.Tables \ Assert =
        match Standard.buildTables() {
            case Ok(t)  => t
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected the tables");
                unreachable!()
        }

    def scrambled(t: Standard.Tables, seed: Int64): Sized.Standard \ Assert =
        let _ = t;
        match Random.sampleDeterministic(seed, 3)
            |> Result.map(fst)
            |> Result.flatMap(Sized.standardOf) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "seed ${seed}");
                unreachable!()
        }

    def solves(c: Sized.Standard, ms: List[Move.Move]): Bool =
        let start = Sized.cubeOfStandard(c);
        match (Cube.applyAll(ms, start), Cube.solved(3)) {
            case (Ok(after), Ok(goal)) => Cube.orbits(after) == Cube.orbits(goal)
            case _                     => false
        }

    ///
    /// Gate 7.4. Every solution `next` hands back is strictly shorter than the
    /// one before it, and every one of them actually solves the cube.
    ///
    /// Both halves matter. A `next` that returned the same solution repeatedly
    /// would satisfy "never longer" and be useless; one that shortened the
    /// answer by searching a different view and forgetting to rename it back
    /// would satisfy "strictly shorter" and be wrong. The replay is what
    /// separates them, and renaming a view's answer back into the caller's
    /// frame is exactly where this solver has had a real bug before.
    ///
    def eachSolutionIsStrictlyShorterAndStillSolves(t: Standard.Tables): Unit \ Assert =
        Vector.range(0, 3) |> Vector.forEach(i -> {
            let seed = Int32.toInt64(i) + 90000i64;
            let c = scrambled(t, seed);
            let improvements = collect(Standard.start(t, Standard.thoroughBudget(), c), Nil);
            Assert.assertTrueWithMsg(List.length(improvements) >= 1,
                "seed ${seed}: the search produced no solution at all");
            improvements |> List.forEach(ms ->
                Assert.assertTrueWithMsg(solves(c, ms),
                    "seed ${seed}: a returned solution does not solve the cube"));
            let lengths = improvements |> List.map(List.length);
            Assert.assertEqWithMsg(
                expected = List.sort(lengths) |> List.reverse, lengths,
                "seed ${seed}: solutions came back in lengths ${lengths}, which is "
                    + "not strictly decreasing");
            Assert.assertEqWithMsg(
                expected = List.length(lengths), List.length(List.distinct(lengths)),
                "seed ${seed}: two solutions were the same length")
        })

    ///
    /// Every improvement, in the order `next` produced them.
    ///
    def collect(
        s: Standard.Search,
        found: List[List[Move.Move]]
    ): List[List[Move.Move]] =
        match Standard.next(s) {
            case Step.Exhausted(_, _)  => List.reverse(found)
            case Step.Improved(ms, s2) => collect(s2, ms :: found)
        }

    ///
    /// Gate 7.3. A budget too small to finish says so, and says it the same way
    /// every time.
    ///
    /// The reason is checked, not merely its presence: "exhausted" that does not
    /// distinguish *out of probes* from *out of views* would be useless, because
    /// only the first can be answered by spending more.
    ///
    def aStarvedBudgetExplainsItself(t: Standard.Tables): Unit \ Assert =
        let c = scrambled(t, 90100i64);
        let starved = Standard.budget({
            probeMin = 1, probeMax = 1, maxDepth = 25, handovers = 1
        });
        // One probe cannot be spread over six views, so this ends out of probes
        // rather than out of views -- whether or not it found anything first.
        match drain(Standard.start(t, starved, c)) {
            case (why, s) =>
                Assert.assertTrueWithMsg(String.contains(substr = "probes", why),
                    "a probe-starved search should say so, not: ${why}");
                Assert.assertTrueWithMsg(String.contains(substr = "withBudget", why),
                    "the reason should say how to continue, not: ${why}");
                Assert.assertTrueWithMsg(Standard.probesSpent(s) <= 1,
                    "a budget of one probe spent ${Standard.probesSpent(s)}")
        }

    ///
    /// A search that has run out of views says the other thing, and does not
    /// pretend more probes would help.
    ///
    def aSearchOutOfViewsSaysSo(t: Standard.Tables): Unit \ Assert =
        let c = scrambled(t, 90101i64);
        match drain(Standard.start(t, Standard.fastBudget(), c)) {
            case (why, _) =>
                Assert.assertTrueWithMsg(String.contains(substr = "every view", why),
                    "a search that ran out of views should say so, not: ${why}")
        }

    ///
    /// Continuing under a larger budget keeps the answer already found.
    ///
    /// `withBudget` offers every view again, so it can only find something at
    /// least as good -- a view is capped at one move shorter than the best in
    /// hand, and the best is carried across.
    ///
    def continuingUnderALargerBudgetNeverLosesGround(t: Standard.Tables): Unit \ Assert =
        let c = scrambled(t, 90102i64);
        let small = Standard.budget({
            probeMin = 1, probeMax = 3, maxDepth = 25, handovers = 300
        });
        match drain(Standard.start(t, small, c)) {
            case (_, stopped) =>
                let before = Standard.bestSoFar(stopped);
                let resumed = Standard.withBudget(stopped, Standard.defaultBudget());
                Assert.assertEqWithMsg(expected = before, Standard.bestSoFar(resumed),
                    "resuming should carry the answer across, not discard it");
                match drain(resumed) {
                    case (_, done) =>
                        match (before, Standard.bestSoFar(done)) {
                            case (Some(a), Some(b)) =>
                                Assert.assertTrueWithMsg(List.length(b) <= List.length(a),
                                    "resuming made the answer longer: ${List.length(a)} "
                                        + "became ${List.length(b)}");
                                Assert.assertTrueWithMsg(solves(c, b),
                                    "the resumed answer does not solve the cube")
                            case (None, _) => ()
                            case (Some(_), None) =>
                                Assert.assertTrueWithMsg(false, "resuming lost the answer")
                        }
                }
        }

    ///
    /// Run a search to a stop, returning why it stopped and where it got to.
    ///
    def drain(s: Standard.Search): (String, Standard.Search) =
        match Standard.next(s) {
            case Step.Exhausted(why, s2) => (why, s2)
            case Step.Improved(_, s2)    => drain(s2)
        }

    ///
    /// Driving the search by hand reaches an answer at least as good as asking
    /// for one outright.
    ///
    /// `solution` stops at the `probeMin` floor; `next` has no floor and keeps
    /// going while views remain. So the anytime interface is not a worse way to
    /// use the solver, which is the only reason to offer it.
    ///
    def drivingByHandIsNoWorseThanAskingOutright(t: Standard.Tables): Unit \ Assert =
        Vector.range(0, 2) |> Vector.forEach(i -> {
            let seed = Int32.toInt64(i) + 90200i64;
            let c = scrambled(t, seed);
            let budget = Standard.defaultBudget();
            match (Standard.solutionWith(t, budget, c), drain(Standard.start(t, budget, c))) {
                case (Ok(direct), (_, driven)) =>
                    match Standard.bestSoFar(driven) {
                        case None => Assert.assertTrueWithMsg(false,
                            "seed ${seed}: driving the search found nothing")
                        case Some(byHand) =>
                            Assert.assertTrueWithMsg(
                                List.length(byHand) <= List.length(direct),
                                "seed ${seed}: driving gave ${List.length(byHand)} "
                                    + "against ${List.length(direct)} outright")
                    }
                case (Err(e), _) =>
                    Assert.assertEqWithMsg(expected = "", e, "seed ${seed}")
            }
        })

}
