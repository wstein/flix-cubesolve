mod TestPatternBoundsFast {

    use CubeSolve.Solve.Standard

    ///
    /// The solver stays within the documented move count, over a named subset.
    ///
    /// This is the gate that runs on every commit. Solving 110 patterns is
    /// roughly half the suite's runtime, which is too much to pay for routine
    /// feedback, so this covers 27 of them chosen by stated rules --
    /// see `PatternBoundCheck.stratum` for the rules and the reason attached to
    /// each pattern.
    ///
    /// The subset is not a sample and nothing is quietly dropped:
    /// `TestPatternBoundsExhaustive` runs all 110 and is required before a
    /// release. What this one buys is that a regression on the patterns most
    /// likely to show one -- the two named hard cases, every pattern the solver
    /// already loses by four moves or more, and every pattern sitting exactly
    /// at its published bound -- is caught in the fast loop.
    ///
    /// The comparison against the published algorithms is tallied but bounded
    /// loosely here, because a 27-pattern subset cannot carry the whole
    /// collection's figures. The exhaustive gate holds those.
    ///
    @Test
    def theStratumStaysWithinTheDocumentedMoveCount(): Unit \ Assert =
        let stratum = PatternBoundCheck.stratum();
        Assert.assertEqWithMsg(expected = 27, Vector.length(stratum),
            "the fast stratum should name 27 patterns");
        Assert.assertEqWithMsg(
            expected = Vector.length(stratum),
            List.length(List.distinct(Vector.toList(stratum))),
            "the fast stratum names a pattern twice");

        let (comparable, longer, worst) =
            PatternBoundCheck.check(
                PatternBoundCheck.tables(), Standard.defaultBudget(), stratum);

        // every named pattern was found; a typo in the list would show as a
        // short count rather than as a silently smaller gate
        Assert.assertEqWithMsg(expected = 24, comparable,
            "24 of the 27 are published in face turns and so document a count");
        // 11 of the 24, far above the collection's 29-in-102 rate, and that is
        // the point: the stratum deliberately takes every pattern the solver
        // already loses badly, so it is dense in exactly the cases a regression
        // would touch.
        Assert.assertTrueWithMsg(longer <= 11,
            "the solver is longer than the publication on ${longer} of the "
                + "stratum, up from the recorded 11");
        Assert.assertTrueWithMsg(worst <= 7,
            "the solver's worst excess over the stratum is ${worst} moves, over "
                + "the recorded 7")

}
