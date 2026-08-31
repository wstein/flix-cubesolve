///
/// What decides when a search stops looking.
///
/// Three conditions, each there for a different failure:
///
/// - an answer exists, so nothing settles on nothing;
/// - `minViews` whole views have finished, so one expensive first view cannot
///   end a tier on its own;
/// - `probeFloor` probes have been spent, so a search whose views are cheap
///   keeps going instead of settling early.
///
/// The third is what a view count alone cannot do, and leaving it out is what
/// broke `Black mamba`: five views of that cube answer in eighteen moves and
/// the sixth answers in sixteen, for sixty-seven probes. A `default` that
/// stopped after two views never saw it.
///
mod TestScheduler {

    use CubeSolve.Model.Holding
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard

    ///
    /// The pattern whose sixth view is the one that matters.
    ///
    def blackMamba(): String = "A2HhlM-xDXSo"


    ///
    /// The documented bound for `Black mamba` is checked by
    /// `TestPatternBoundsFast`, not here.
    ///
    /// A fixture that solved this pattern's canonical token was tried and was
    /// wrong: the token is the smallest of its twenty-four holdings, so it is
    /// the pattern *rotated*, and the two-phase views are named in the frame
    /// they are given. Solving a re-held presentation is a different search, and
    /// it answers in eighteen where the gate's cube answers within sixteen. The
    /// bound belongs to the pattern as the collection records it, which is what
    /// the gate builds from its notation.
    ///
    ///
    /// Cheap views carry on past `minViews` until the floor is met.
    ///
    /// The property the floor exists for, asserted directly rather than
    /// inferred from a solution length: given a budget whose floor is well
    /// above what two views cost, the search must not stop at two.
    ///
    @Test
    def cheapViewsKeepGoingPastTheViewTarget(): Unit \ Assert + IO =
        if (Slow.skip("TestScheduler.cheapViewsKeepGoingPastTheViewTarget",
                "builds the phase tables and searches every view"))
            ()
        else
            match (Standard.buildTables(),
                   Holding.ofToken(3, blackMamba()) |> Result.flatMap(Sized.standardOf)) {
                case (Ok(t), Ok(c)) =>
                    let hungry = Standard.budget({
                        minViews = 2, probeFloor = 100000, probeMax = 400000,
                        maxDepth = 25, handovers = 300, phase1Depth = 12
                    });
                    let out = Standard.solveWithOutcome(t, hungry, c);
                    Assert.assertTrueWithMsg(out#viewsTried > 2,
                        "a floor of 100000 probes is far above what two views cost, "
                            + "so the search should have carried on past two and it "
                            + "stopped at ${out#viewsTried}")
                case (Err(e), _) => Assert.assertEqWithMsg(expected = "", e, "the tables")
                case (_, Err(e)) => Assert.assertEqWithMsg(expected = "", e, "the token")
            }
}
