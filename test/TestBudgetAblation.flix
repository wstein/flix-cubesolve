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
/// What it measured, over the eight cubes below, under the breadth scheduler:
///
/// ```text
///   budget          HTM   probes  views  selected  pruned  tried  unexamined
///   fast            165   542     25     2814      1860    542    412
///   default         164   993     32     8076      6477    993    606
///   deep            159   1866    48     17098     14353   1866   879
///   max             157   2693    48     28376     24233   2693   1450
///   5 views, 300 h  159   1616    40     12186     9691    1616   879
///   5 views, 600 h  159   2395    40     20362     17088   2395   879
///   6 views, 300 h  159   1866    48     17098     14353   1866   879
///   6 views, 600 h  157   2693    48     28376     24233   2693   1450
/// ```
///
/// **The ladder is monotone and every tier earns its place**: 165, 164, 159,
/// 157. `max` is two moves shorter than `deep` over the corpus for 44% more
/// probes.
///
/// **Neither knob buys anything alone, and this is now the second scheduler it
/// has been true under.** The sixth view on its own is 159 for 15% more probes;
/// six hundred handovers on their own are 159 for 48% more. Only the pair
/// reaches 157. Holding under two different stopping rules makes it a property
/// of the search rather than of when the search stops.
///
/// **`deep` now asks for six views, because five described nothing.** Its row
/// was already identical to six views at three hundred handovers -- forty-eight
/// views over eight cubes is six apiece -- since the floor of six hundred probes
/// reached every view before the target of five was tested. `deep` and `max`
/// differ in handovers, not breadth.
///
/// **`fast` keeps half the standard handovers, and the measurement is why.** At
/// the standard three hundred it answers the corpus in 164, the same as
/// `default`, for fewer probes -- which leaves `default` buying nothing and
/// collapses two tiers into one. At a hundred and fifty it is 165, and the
/// ladder is monotone in quality and in cost together.
///
/// **Most endings are rejected rather than tried.** At `max`, 24,233 of 28,376
/// selected are pruned by the lower bound before phase two -- 85% -- and 1,450
/// are left unexamined when a view stops at its answer. The handover limit
/// mostly buys candidates that are proved worthless.
///
///
/// The four presets are monotone in quality and each buys something: 169, 164,
/// 158, 155. `deep` is six moves better than `default` at seventy per cent of
/// `exhaustive`'s probes, so it is a real intermediate rather than a weaker
/// `exhaustive`.
///
/// **A single command-line run cannot show that.** Starting a JVM and loading
/// the tables costs more than the search, so `deep` and `exhaustive` take
/// visibly the same time there while differing by 43% in probes. The probes are
/// what a caller solving many cubes in one process pays.
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
    def combinations(): List[(String, Standard.Budget)] =
        // The presets as they ship, floors included: whether `max` earns its
        // extra view and handovers is a question about the configured tiers,
        // not about the knobs in isolation.
        ("fast", Standard.fastBudget())
            :: ("default", Standard.defaultBudget())
            :: ("deep", Standard.deepBudget())
            :: ("max", Standard.maxBudget())
            // And the knobs alone, at a floor of zero, so a difference here is
            // the view count or the handover limit and not the floor.
            :: ("5 views, 300 h", cell(5, 300))
            :: ("5 views, 600 h", cell(5, 600))
            :: ("6 views, 300 h", cell(6, 300))
            :: ("6 views, 600 h", cell(6, 600))
            :: Nil

    ///
    /// One knob combination, with no floor of its own.
    ///
    def cell(views: Int32, handovers: Int32): Standard.Budget =
        Standard.budget({
            minViews = views, probeFloor = 0, probeMax = 4000,
            maxDepth = 25, handovers = handovers, phase1Depth = 12
        })

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
                println("  budget          HTM   probes  views  selected  unreachable  pruned  "
                    + "attempted  unexamined  capped");
                combinations() |> List.forEach(match (name, b) -> {
                    let r = overCorpus(t, b);
                    println("  ${String.padRight(16, ' ', name)}"
                        + "${String.padRight(6, ' ', "${r#htm}")}"
                        + "${String.padRight(8, ' ', "${r#probes}")}"
                        + "${String.padRight(7, ' ', "${r#views}")}"
                        + "${String.padRight(10, ' ', "${r#selected}")}"
                        + "${String.padRight(13, ' ', "${r#unreachable}")}"
                        + "${String.padRight(8, ' ', "${r#pruned}")}"
                        + "${String.padRight(11, ' ', "${r#attempted}")}"
                        + "${String.padRight(12, ' ', "${r#unexamined}")}"
                        + "${r#capped}")
                })
        }

    ///
    /// The whole corpus under one budget: total moves, total probes, how many
    /// were answered.
    ///
    def overCorpus(t: Standard.Tables, b: Standard.Budget): Tally =
        corpus() |> List.foldLeft((acc, token) ->
            match Holding.ofToken(3, token)
                    |> Result.flatMap(CubeSolve.Model.Sized.standardOf) {
                case Err(_) => acc
                case Ok(c)  => add(acc, Standard.solveWithOutcome(t, b, c))
            }, empty())

    ///
    /// What the corpus adds up to under one budget.
    ///
    type alias Tally = {
        htm = Int32, probes = Int32, views = Int32, solved = Int32,
        selected = Int32, unreachable = Int32, attempted = Int32, pruned = Int32,
        unexamined = Int32, capped = Int32
    }

    def empty(): Tally =
        { htm = 0, probes = 0, views = 0, solved = 0, selected = 0, unreachable = 0,
          attempted = 0, pruned = 0, unexamined = 0, capped = 0 }

    ///
    /// One cube's outcome folded in.
    ///
    def add(acc: Tally, out: Standard.Outcome): Tally =
        let vs = out#viewStats;
        let sum = f -> vs |> List.foldLeft((a, v) -> a + f(v), 0);
        { htm = acc#htm + Option.getWithDefault(0, out#finalHtm),
          probes = acc#probes + out#probesSpent,
          views = acc#views + out#viewsTried,
          solved = acc#solved + (if (Option.isEmpty(out#finalHtm)) 0 else 1),
          selected = acc#selected + sum(v -> v#handoversSelected),
          unreachable = acc#unreachable + sum(v -> v#handoversUnreachable),
          attempted = acc#attempted + sum(v -> v#phaseTwoAttempts),
          pruned = acc#pruned + sum(v -> v#handoversPruned),
          unexamined = acc#unexamined + sum(v -> v#handoversUnexamined),
          capped = acc#capped
              + (vs |> List.count(v -> v#handoverLimitReached)) }


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
                    combinations() |> List.forEach(match (name, b) -> {
                        let r = overCorpus(t, b);
                        Assert.assertEqWithMsg(expected = List.length(corpus()),
                            r#solved,
                            "${name} did not answer every cube in the corpus")
                    })
            }
}
