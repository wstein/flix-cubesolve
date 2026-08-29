mod TestPatternBoundsExhaustive {

    use CubeSolve.Solve.Standard

    ///
    /// The solver stays within the documented move count, over all 110 patterns.
    ///
    /// **Off by default, and loudly so.** Solving every pattern takes about two
    /// minutes -- roughly half the suite -- which is too much for routine
    /// feedback but exactly right for a merge or a release. Set
    /// `CUBESOLVE_EXHAUSTIVE=1` to run it:
    ///
    /// ```sh
    /// CUBESOLVE_EXHAUSTIVE=1 ./flixw test
    /// ```
    ///
    /// When it is off this test prints that it was skipped and how to run it,
    /// rather than passing in silence. A gate nobody knows is disabled is worse
    /// than no gate.
    ///
    /// The whole collection's figures live here rather than in the fast
    /// stratum, because a 27-pattern subset cannot carry them: 102 patterns
    /// published in face turns, the solver longer on 32 of them, worst excess 7.
    ///
    @Test
    def theWholeCollectionStaysWithinTheDocumentedMoveCount(): Unit \ Assert + IO =
        match Sys.Env.handle(_ -> Sys.Env.getVar("CUBESOLVE_EXHAUSTIVE"))(()) {
            case Some("1") => runIt()
            case _ =>
                println("TestPatternBoundsExhaustive: SKIPPED -- all 110 patterns take "
                    + "about two minutes. Run with CUBESOLVE_EXHAUSTIVE=1 to include "
                    + "it; CI runs it on main and before releases.")
        }

    ///
    /// The check itself, over every pattern in the collection.
    ///
    def runIt(): Unit \ Assert =
        let (comparable, longer, worst) =
            PatternBoundCheck.check(
                PatternBoundCheck.tables(), Standard.defaultBudget(), Vector#{});
        Assert.assertEqWithMsg(expected = 102, comparable,
            "102 of the 110 are published in face turns and so document a count");
        Assert.assertTrueWithMsg(longer <= 32,
            "the solver is longer than the published algorithm on ${longer} "
                + "patterns, up from the recorded 32");
        Assert.assertTrueWithMsg(worst <= 7,
            "the solver's worst excess over a published algorithm is ${worst} "
                + "moves, over the recorded 7")

}
