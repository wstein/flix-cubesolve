///
/// What each knob of a budget actually buys, measured.
///
/// The presets move two things: how many of the six views must finish, and how
/// many phase-one handovers phase two is offered. `deep` differs from
/// `thorough` in both at once, so comparing the two says extra work happened
/// and not which knob did it. This separates them: every combination of the two
/// view counts and the two handover counts, over one fixed set of cubes.
///
/// **A report, not a gate.** It asserts only that every combination answers at
/// all; the numbers are for reading. Solution length is a property of the
/// search and the cube, and pinning it here would turn an improvement into a
/// failure. Set `CUBESOLVE_ABLATION=1` to run it:
///
/// ```sh
/// CUBESOLVE_ABLATION=1 ./flixw test
/// ```
///
/// What it measured, over the eight cubes below:
///
/// ```text
///   views x handovers        total HTM   probes
///   5 views, 300 handovers   158         3378
///   5 views, 600 handovers   158         4534
///   6 views, 300 handovers   158         3621
///   6 views, 600 handovers   155         4826
/// ```
///
/// **Neither knob buys anything on its own.** The sixth view alone costs 7%
/// more probes and returns the same total; six hundred handovers alone cost 34%
/// more and return the same total. Only the two together shorten anything, by
/// three moves over eight cubes for 43% more work.
///
/// That is why `deep` moves both, and why `thorough` is the efficient point
/// rather than a weaker version of `deep`. It also says what an earlier claim
/// here could not: comparing `thorough` to `deep` shows extra work happened and
/// not which knob did it, because both change at once.
///
/// Eight cubes and a three-move difference is a small sample. It is enough to
/// say the individual knobs did nothing here and not enough to put a number on
/// what the pair is worth.
///
mod TestBudgetAblation {

    use CubeSolve.Model.Holding
    use CubeSolve.Solve.Standard

    ///
    /// The cubes measured, as canonical tokens.
    ///
    /// Seven drawn from the uniform scrambler and pinned, plus the state that
    /// started this: `AD44qcBJiFJM`, whose four presets once collapsed into two
    /// behaviours. Pinned rather than drawn afresh so that two runs of this can
    /// be compared to each other.
    ///
    def corpus(): List[String] =
        "AD44qcBJiFJM" :: "BBhzw-IyLWDz" :: "AsEcE0Z-JGmZ" :: "AY-QJTFLELSu"
            :: "Ac4jnBmFqDvJ" :: "AQ4-xgwvdEU9" :: "AoQmsdNGOivQ"
            :: "A40MKWmYYc_9" :: Nil

    ///
    /// The four combinations, named for what they are.
    ///
    def combinations(): List[(String, Int32, Int32)] =
        ("5 views, 300 handovers", 5, 300)
            :: ("5 views, 600 handovers", 5, 600)
            :: ("6 views, 300 handovers", 6, 300)
            :: ("6 views, 600 handovers", 6, 600)
            :: Nil

    @Test
    def whatEachKnobBuys(): Unit \ Assert + IO =
        match Sys.Env.handle(_ -> Sys.Env.getVar("CUBESOLVE_ABLATION"))(()) {
            case Some("1") => report()
            case _ =>
                println("TestBudgetAblation: SKIPPED -- it solves eight cubes four "
                    + "ways. Run with CUBESOLVE_ABLATION=1; it is a report rather "
                    + "than a gate, so nothing depends on it.")
        }

    def report(): Unit \ Assert + IO =
        match Standard.buildTables() {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "the tables")
            case Ok(t)  =>
                println("");
                println("  views x handovers          total HTM   probes   solved");
                combinations() |> List.forEach(match (name, views, handovers) -> {
                    let b = Standard.budget({
                        minViews = views, probeMax = 4000,
                        maxDepth = 25, handovers = handovers
                    });
                    let (htm, probes, solved) = overCorpus(t, b);
                    let pad = String.padRight(24, ' ', name);
                    println("  ${pad}  ${htm}       ${probes}    ${solved}/8")
                })
        }

    ///
    /// The whole corpus under one budget: total moves, total probes, how many
    /// were answered.
    ///
    def overCorpus(t: Standard.Tables, b: Standard.Budget): (Int32, Int32, Int32) =
        corpus() |> List.foldLeft((acc, token) -> {
            let (htm, probes, solved) = acc;
            match Holding.ofToken(3, token) |> Result.flatMap(CubeSolve.Model.Sized.standardOf) {
                case Err(_) => acc
                case Ok(c)  =>
                    let out = Standard.solveWithOutcome(t, b, c);
                    match out#finalHtm {
                        case Some(n) => (htm + n, probes + out#probesSpent, solved + 1)
                        case None    => (htm, probes + out#probesSpent, solved)
                    }
            }
        }, (0, 0, 0))

    ///
    /// Every combination answers every cube.
    ///
    /// The only assertion: a budget that could not solve a cube the others
    /// solved would be a defect rather than a measurement.
    ///
    @Test
    def everyCombinationAnswersEveryCube(): Unit \ Assert + IO =
        if (Slow.skip("TestBudgetAblation.everyCombinationAnswersEveryCube",
                "solves eight cubes four ways"))
            ()
        else
            match Standard.buildTables() {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "the tables")
                case Ok(t)  =>
                    combinations() |> List.forEach(match (name, views, handovers) -> {
                        let b = Standard.budget({
                            minViews = views, probeMax = 4000,
                            maxDepth = 25, handovers = handovers
                        });
                        let (_, _, solved) = overCorpus(t, b);
                        Assert.assertEqWithMsg(expected = List.length(corpus()), solved,
                            "${name} did not answer every cube in the corpus")
                    })
            }
}
