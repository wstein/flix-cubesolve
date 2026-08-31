///
/// The 3x3x3 solver: phase one and phase two, together.
///
/// This is the public entry point for a 3x3x3. It owns the budget and the
/// handover and nothing else -- `CubeSolve.Solve.Phase1` searches into the
/// domino group and `CubeSolve.Solve.Domino` searches inside it.
///
/// **The handover goes through the model.** Phase one's solution is applied to
/// the cube and phase two's coordinates are read from the result, never from
/// the coordinate the phase-one search wrote. A search bug that corrupted a
/// coordinate would otherwise hand phase two a state that does not exist, and
/// phase two would either fail mysteriously or solve a different cube.
///
mod CubeSolve.Solve.Standard {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Rotation
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.IdaStar
    use CubeSolve.Solve.Phase1
    use CubeSolve.Solve.Standard.Budget.Budget
    use CubeSolve.Solve.Domino
    use CubeSolve.Table.Cache

    ///
    /// Every table a 3x3x3 solve needs, for both phases.
    ///
    /// A caller should not have to know that the engine has two phases with
    /// separate table sets, so this is the pair and `solution` is what consumes
    /// it.
    ///
    pub enum Tables {
        case Tables(Phase1.Tables, Domino.Tables)
    }

    ///
    /// Build every table a 3x3x3 solve needs.
    ///
    /// Several breadth-first sweeps over millions of states, so this takes
    /// tens of seconds. Prefer `cachedTables`, which pays that once.
    ///
    pub def buildTables(): Result[String, Tables] =
        forM (
            p1 <- Phase1.buildTables();
            p2 <- Domino.buildTables()
        ) yield Tables.Tables(p1, p2)

    ///
    /// Every table a 3x3x3 solve needs, from the cache where possible.
    ///
    pub def cachedTables(): Result[String, Tables] \ Cache.Store =
        forM (
            p1 <- Phase1.cachedTables();
            p2 <- Domino.cachedTables()
        ) yield Tables.Tables(p1, p2)

    ///
    /// Why a search finished.
    ///
    pub enum Termination with Eq, ToString {
        /// The cube was already in the solved state.
        case SolvedImmediately
        /// The search reached the probe cap (`probeMax`).
        case ProbeCap
        /// The search has an answer and has completed `minViews` whole views.
        ///
        /// The ordinary way a bounded search ends. It is a count of views
        /// rather than of probes because a view runs atomically: a floor
        /// expressed in probes is crossed wholesale by whichever view happens
        /// to span it, which made two presets that differed only in that floor
        /// behave identically.
        case Settled
        /// Every orientation and inversion view was searched to completion.
        case ViewsExhausted
    }

    ///
    /// Which axis of the cube phase one aimed at.
    ///
    pub enum ViewAxis with Eq, ToString {
        case UD
        case FB
        case RL
    }

    ///
    /// Statistics for one orientation/inversion search view.
    ///
    /// `accepted` is true if this view produced a candidate that became the
    /// current best (including the initial candidate). `Outcome.improvements`
    /// counts strict reductions after the initial candidate.
    ///
    pub type alias ViewStats = {
        axis = ViewAxis,
        inverted = Bool,
        probesSpent = Int32,
        foundMoves = Option[Int32],
        accepted = Bool
    }

    ///
    /// The complete, structured outcome of a 3x3 search, on success or failure.
    ///
    pub type alias Outcome = {
        answer = Option[List[Move.Move]],
        probesSpent = Int32,
        viewTarget = Int32,
        probeCap = Int32,
        viewsTried = Int32,
        viewsAvailable = Int32,
        firstHtm = Option[Int32],
        finalHtm = Option[Int32],
        improvements = Int32,
        termination = Termination,
        viewStats = List[ViewStats]
    }

    ///
    /// A solution for `c`, using both phases' tables together.
    ///
    pub def solutionWith(
        t: Tables,
        budget: Budget,
        c: Sized.Standard
    ): Result[String, List[Move.Move]] =
        let Budget(limits) = budget;
        outcomeToResult(solveWithOutcome(t, budget, c), limits#probeMax, limits#maxDepth)

    ///
    /// A full structured search outcome for `c`, using both phases' tables together.
    ///
    pub def solveWithOutcome(
        t: Tables,
        budget: Budget,
        c: Sized.Standard
    ): Outcome =
        let Tables.Tables(p1, p2) = t;
        solutionOutcome(p1, p2, budget, c)

    ///
    /// What a solve is allowed to spend, and what it must achieve.
    ///
    /// **Probes, not seconds.** A time budget is not reproducible: it varies
    /// with the machine, the JDK, JIT warm-up and garbage collection, so a gate
    /// reading "solve in 100 ms" fails on a slow runner and passes on a fast
    /// one. A probe is one phase-two attempt, and counting them gives the same
    /// answer everywhere.
    ///
    pub enum Budget {
        case Budget({ minViews = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 })
    }

    ///
    /// A budget that answers quickly and accepts a longer solution for it.
    ///
    /// Measured mean **20.9** moves over uniform random states.
    ///
    /// The solver looks at the cube six ways -- three axes, each forwards and
    /// inverted -- and `minViews` is how many of those it must finish before it
    /// settles. One, here: the first view that yields an answer is accepted.
    ///
    /// It also offers phase one half as many handovers as the default. Views
    /// and handovers are the two things that make a search wider, and this is
    /// the relaxed end of both.
    ///
    pub def fastBudget(): Budget =
        Budget({ minViews = 1, probeMax = 500, maxDepth = 25, handovers = 150 })

    ///
    /// The budget to use when nothing else is stated.
    ///
    /// Two views and the standard three hundred handovers. Everything else is
    /// stated as a multiple of this one.
    ///
    pub def defaultBudget(): Budget =
        Budget({ minViews = 2, probeMax = 500, maxDepth = 25, handovers = 300 })

    ///
    /// Five of the six views, at the standard handovers.
    ///
    /// Measured mean **20.6** moves, which is min2phase's own average. What is
    /// left after this is the gap between a two-phase solver and an optimal
    /// one, and no budget closes that.
    ///
    /// Five rather than six so that it stays distinguishable from a budget that
    /// takes every view: a tier nobody can tell apart from the one above it is
    /// the defect this ladder was rebuilt to remove.
    ///
    pub def deepBudget(): Budget =
        Budget({ minViews = 5, probeMax = 1200, maxDepth = 25, handovers = 300 })

    ///
    /// All six views, with double the probe cap and double the floor.
    ///
    pub def exhaustiveBudget(): Budget =
        Budget({ minViews = 6, probeMax = 2400, maxDepth = 25, handovers = 600 })

    ///
    /// Deprecated name for `deepBudget`.
    ///
    pub def thoroughBudget(): Budget = deepBudget()

    ///
    /// A budget, from its parts.
    ///
    pub def budget(
        parts: { minViews = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 }
    ): Budget = Budget(parts)

    ///
    /// A solution for `c`, or why there is none within the budget.
    ///
    /// Works upward through phase-one depths, and at each depth tries several
    /// handovers rather than only the first. The shortest phase one very often
    /// leads to a long phase two, so the best totals come from trying a few.
    ///
    /// The handover is applied to the **model** cube and phase two's
    /// coordinates are read from that, never from the coordinate the phase-one
    /// search wrote. A search bug that corrupted a coordinate would otherwise
    /// hand phase two a state that does not exist, and phase two would either
    /// fail mysteriously or solve the wrong cube.
    ///
    pub def solution(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        budget: Budget,
        c: Sized.Standard
    ): Result[String, List[Move.Move]] =
        let Budget(limits) = budget;
        outcomeToResult(solutionOutcome(p1, p2, budget, c), limits#probeMax, limits#maxDepth)

    ///
    /// A full structured search outcome for `c`, or why there is none within the budget.
    ///
    pub def solutionOutcome(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        budget: Budget,
        c: Sized.Standard
    ): Outcome =
        acrossAxesOutcome(p1, p2, budget, c)

    def outcomeToResult(
        out: Outcome,
        probeMax: Int32,
        maxDepth: Int32
    ): Result[String, List[Move.Move]] =
        match out#answer {
            case Some(ms) => Ok(ms)
            case None     =>
                Err("no solution within ${probeMax} probes and "
                    + "${maxDepth} moves: raise the budget rather than "
                    + "retrying this search unchanged")
        }

    ///
    /// The three axes phase one can aim at.
    ///
    /// Phase one's goal is stated against the `U`/`D` axis, and its Flip
    /// coordinate is defined against that axis specifically -- a cube with
    /// every edge oriented in the `U`/`D` sense need not be oriented in the
    /// `F`/`B` sense. So the same tables can aim at the other two axes by
    /// looking at a conjugated cube: `x` carries `U`/`D` onto `F`/`B` and `z`
    /// carries it onto `R`/`L`.
    ///
    /// A scramble awkward for one axis is often easy for another, and this is
    /// where most of the remaining solution length is.
    ///
    def axes(): List[Rotation.Rotation] =
        Rotation.identity() :: Rotation.x() :: Rotation.z() :: Nil

    ///
    /// A search in progress: what it is solving, what it has spent, what it has
    /// found, and which views it has not tried yet.
    ///
    /// Held explicitly rather than hidden in a loop so that a caller can take
    /// the first answer and decide afterwards whether to pay for a better one.
    /// The engine has no notion of time, so "how long may this take" is not a
    /// question it can answer; "may I have a shorter one" is.
    ///
    pub enum Search {
        case Search({
            tables = Tables,
            budget = Budget,
            cube = Sized.Standard,
            views = List[(Rotation.Rotation, Bool)],
            spent = Int32,
            best = Option[List[Move.Move]],
            firstHtm = Option[Int32],
            improvements = Int32,
            viewStats = List[ViewStats]
        })
    }

    ///
    /// What `next` did.
    ///
    /// `Exhausted` carries the search back along with the reason, because the
    /// reason decides whether resuming is worth anything: out of probes can be
    /// answered with `withBudget`, out of views cannot be answered at all by
    /// this scheduler.
    ///
    pub enum Step {
        case Improved(List[Move.Move], Search)
        case Exhausted(String, Search)
    }

    ///
    /// A search over `c` that has not looked at anything yet.
    ///
    pub def start(t: Tables, budget: Budget, c: Sized.Standard): Search =
        let isSol = Cube.isSolved(Sized.cubeOfStandard(c));
        let vs = if (isSol) Nil else allViews();
        Search.Search({
            tables = t,
            budget = budget,
            cube = c,
            views = vs,
            spent = 0,
            best = if (isSol) Some(Nil) else None,
            firstHtm = if (isSol) Some(0) else None,
            improvements = 0,
            viewStats = Nil
        })

    def allViews(): List[(Rotation.Rotation, Bool)] =
        axes() |> List.flatMap(r -> (r, false) :: (r, true) :: Nil)

    ///
    /// The shortest solution found so far, if any.
    ///
    pub def bestSoFar(s: Search): Option[List[Move.Move]] =
        let Search.Search(f) = s;
        f#best

    ///
    /// How many probes this search has spent.
    ///
    /// Probes rather than time, for the reason `Budget` gives: this number is
    /// the same on every machine, and a duration is not.
    ///
    pub def probesSpent(s: Search): Int32 =
        let Search.Search(f) = s;
        f#spent

    ///
    /// The next solution, which is always strictly shorter than the last one.
    ///
    /// Views that find nothing better are searched and passed over silently, so
    /// one call may cost several of them. That is the point: a caller asking for
    /// a better answer wants a better answer, not a report that a view failed.
    ///
    /// The guarantee is structural. A view is capped at one move shorter than
    /// the best in hand, so anything it returns is an improvement, and
    /// `Improved` is reachable no other way.
    ///
    pub def next(s: Search): Step =
        advance(s, lengthOf(bestSoFar(s)))

    ///
    /// `s` continued under a different budget, with every view offered again.
    ///
    /// The best found so far is kept and still caps what a view will accept, so
    /// this cannot make the answer worse. Views already searched are searched
    /// again: a view that found nothing shorter under a small allowance may find
    /// something under a larger one, and there is no way to tell which without
    /// looking. Probes already spent are not refunded -- `probesSpent` keeps
    /// counting -- so a new `probeMax` must exceed it to buy anything.
    ///
    pub def withBudget(s: Search, budget: Budget): Search =
        let Search.Search(f) = s;
        Search.Search({
            tables = f#tables,
            budget = budget,
            cube = f#cube,
            views = allViews(),
            spent = f#spent,
            best = f#best,
            firstHtm = f#firstHtm,
            improvements = f#improvements,
            viewStats = f#viewStats
        })

    ///
    /// Search views until one improves on `before`, or until there is nothing
    /// left to search.
    ///
    def advance(s: Search, before: Int32): Step =
        let Search.Search(f) = s;
        let Budget(limits) = f#budget;
        if (f#spent >= limits#probeMax)
            Step.Exhausted(outOfProbes(limits#probeMax), s)
        else
            continueFrom(s, before, limits#maxDepth)

    ///
    /// One more view, and what came of it.
    ///
    def continueFrom(s: Search, before: Int32, maxDepth: Int32): Step =
        match stepOnce(s) {
            case None     => Step.Exhausted(outOfViews(maxDepth), s)
            case Some(s2) => afterOneView(s2, before)
        }

    ///
    /// Whether the view just searched improved on `before`.
    ///
    def afterOneView(s: Search, before: Int32): Step =
        match bestSoFar(s) {
            case Some(found) if List.length(found) < before => Step.Improved(found, s)
            case _                                          => advance(s, before)
        }

    ///
    /// Why a search stopped, when the probes ran out.
    ///
    def outOfProbes(probeMax: Int32): String =
        "spent all ${probeMax} probes: continue with `withBudget` and a larger "
            + "`probeMax`, which is the only thing that buys more here"

    ///
    /// Why a search stopped, when there was nothing left to look at.
    ///
    def outOfViews(maxDepth: Int32): String =
        "every view of the cube has been searched at ${maxDepth} moves or fewer: "
            + "this scheduler has nothing further to try, and more probes alone "
            + "will not change that"

    ///
    /// One view searched, or nothing when none are left.
    ///
    /// The single place a view is run. `solution` and `next` differ only in when
    /// they stop calling it, so the two cannot drift into searching differently.
    ///
    def stepOnce(s: Search): Option[Search] =
        let Search.Search(f) = s;
        match f#views {
            case Nil          => None
            case view :: rest =>
                let (found, used) = searchOneView(s, view);
                Some(folded(s, view, rest, found, used))
        }

    def axisOf(r: Rotation.Rotation): ViewAxis =
        if (r == Rotation.identity()) ViewAxis.UD
        else if (r == Rotation.x()) ViewAxis.FB
        else ViewAxis.RL

    def isBetter(best: Option[List[Move.Move]], found: Option[List[Move.Move]]): Bool =
        match (best, found) {
            case (None, Some(_))       => true
            case (Some(b), Some(cand)) => List.length(cand) < List.length(b)
            case _                     => false
        }

    ///
    /// One view searched, reporting what it found and what it spent.
    ///
    def searchOneView(
        s: Search,
        view: (Rotation.Rotation, Bool)
    ): (Option[List[Move.Move]], Int32) =
        let Search.Search(f) = s;
        let Tables.Tables(p1, p2) = f#tables;
        let Budget(limits) = f#budget;
        let (r, inverted) = view;
        let looking = { rotation = r, inverted = inverted };
        alongAxis(p1, p2, shareFor(limits, f#spent, f#best), f#cube, looking)

    ///
    /// `s` with a view's result taken in and that view dropped.
    ///
    def folded(
        s: Search,
        view: (Rotation.Rotation, Bool),
        rest: List[(Rotation.Rotation, Bool)],
        found: Option[List[Move.Move]],
        used: Int32
    ): Search =
        let Search.Search(f) = s;
        let (r, inverted) = view;
        let improved = isBetter(f#best, found);
        let stat = {
            axis = axisOf(r),
            inverted = inverted,
            probesSpent = used,
            foundMoves = Option.map(List.length, found),
            accepted = improved
        };
        let newFirst = match f#firstHtm {
            case Some(h) => Some(h)
            case None    => Option.map(List.length, found)
        };
        let newImpr =
            if (improved and not Option.isEmpty(f#best)) f#improvements + 1
            else f#improvements;
        Search.Search({
            tables = f#tables,
            budget = f#budget,
            cube = f#cube,
            views = rest,
            spent = f#spent + used,
            best = keepShorterOf(f#best, found),
            firstHtm = newFirst,
            improvements = newImpr,
            viewStats = stat :: f#viewStats
        })

    ///
    /// What one view may spend, and how long an answer it may accept.
    ///
    /// Whatever probes are left, and capped one move under the best in hand, so
    /// a view either improves on the answer or gives up quickly.
    ///
    def shareFor(
        limits: { minViews = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 },
        spent: Int32,
        best: Option[List[Move.Move]]
    ): Budget =
        Budget({
            minViews = 1,
            probeMax = limits#probeMax - spent,
            maxDepth = shorterThanBest(best, limits#maxDepth),
            handovers = limits#handovers
        })

    ///
    /// How long the best solution is, or longer than any solution can be.
    ///
    def lengthOf(best: Option[List[Move.Move]]): Int32 =
        best |> Option.map(List.length) |> Option.getWithDefault(Int32.maxValue())

    ///
    /// Search every axis, and both directions of each, keeping the shortest.
    ///
    /// The probe budget is divided between the six searches rather than spent
    /// six times over, so this costs no more probes than a single search and
    /// can be compared with the recorded baseline directly.
    ///
    def acrossAxesOutcome(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        budget: Budget,
        c: Sized.Standard
    ): Outcome =
        let Budget(limits) = budget;
        if (Cube.isSolved(Sized.cubeOfStandard(c)))
            solvedOutcome(limits)
        else
            searchOutcome(p1, p2, budget, limits, c)

    def solvedOutcome(
        limits: { minViews = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 }
    ): Outcome = {
        answer = Some(Nil),
        probesSpent = 0,
        viewTarget = limits#minViews,
        probeCap = limits#probeMax,
        viewsTried = 0,
        viewsAvailable = List.length(allViews()),
        firstHtm = Some(0),
        finalHtm = Some(0),
        improvements = 0,
        termination = Termination.SolvedImmediately,
        viewStats = Nil
    }

    def searchOutcome(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        budget: Budget,
        limits: { minViews = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 },
        c: Sized.Standard
    ): Outcome = {
        let settled = runToSettled(start(Tables.Tables(p1, p2), budget, c));
        let Search.Search(f) = settled;
        let term =
            if (f#spent >= limits#probeMax) Termination.ProbeCap
            else if (hasSettled(f#best, List.length(f#viewStats), limits))
                Termination.Settled
            else Termination.ViewsExhausted;
        {
            answer = f#best,
            probesSpent = f#spent,
            viewTarget = limits#minViews,
            probeCap = limits#probeMax,
            viewsTried = List.length(f#viewStats),
            viewsAvailable = List.length(allViews()),
            firstHtm = f#firstHtm,
            finalHtm = Option.map(List.length, f#best),
            improvements = f#improvements,
            termination = term,
            viewStats = List.reverse(f#viewStats)
        }
    }

    ///
    /// Work through the views until the budget says stop.
    ///
    /// Each search is given whatever is left rather than a fixed share, and is
    /// capped at one move shorter than the best found so far -- so a later view
    /// either improves on the answer or gives up quickly. That is what makes
    /// six searches affordable within one budget.
    ///
    /// Unlike `next`, this honours `minViews`: it stops once there is an answer
    /// and enough has been spent looking for a better one. A caller driving the
    /// search by hand has said what it wants by asking, so no floor applies.
    ///
    def runToSettled(s: Search): Search =
        let Search.Search(f) = s;
        let Budget(limits) = f#budget;
        if (f#spent >= limits#probeMax
                or hasSettled(f#best, List.length(f#viewStats), limits))
            s
        else
            match stepOnce(s) {
                case None     => s
                case Some(s2) => runToSettled(s2)
            }

    ///
    /// The shorter of two solutions, keeping the first when they are equal.
    ///
    def shorterOf(a: List[Move.Move], b: List[Move.Move]): List[Move.Move] =
        if (List.length(b) < List.length(a)) b else a

    ///
    /// The shorter of what was already found and what a view just produced.
    ///
    def keepShorterOf(
        best: Option[List[Move.Move]],
        found: Option[List[Move.Move]]
    ): Option[List[Move.Move]] =
        match (best, found) {
            case (None, x)          => x
            case (x, None)          => x
            case (Some(a), Some(b)) => Some(shorterOf(a, b))
        }

    ///
    /// Both directions along one axis, keeping the shorter.
    ///
    /// The cube is conjugated into the frame that puts this axis where phase
    /// one looks, and the answer is renamed back out of it.
    ///
    def alongAxis(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        share: Budget,
        c: Sized.Standard,
        view: { rotation = Rotation.Rotation, inverted = Bool }
    ): (Option[List[Move.Move]], Int32) =
        let r = view#rotation;
        // A 3x3x3 has no centre orbit, so neither of these can refuse; the
        // Result is here for the sizes that do, and a refusal is treated as a
        // view that found nothing rather than special-cased.
        let looking = Cube.conjugate(r, Sized.cubeOfStandard(c))
            |> Result.flatMap(seen -> if (view#inverted) Cube.inverse(seen) else Ok(seen));
        match looking |> Result.flatMap(Sized.standardOf) {
            case Err(_) => (None, 0)
            case Ok(turned) =>
                let (found, used) = searchOnce(p1, p2, share, turned);
                let named = ms -> namedInTheCallersFrame(ms, r, view#inverted);
                (found |> Option.map(named), used)
        }

    ///
    /// A solution found in a conjugated, possibly inverted view, named back in
    /// the frame the caller handed over.
    ///
    /// The rename is by the **inverse** rotation. Getting that backwards
    /// produces a sequence of the right length that solves a different cube --
    /// which the replay test catches, and nothing else would.
    ///
    def namedInTheCallersFrame(
        ms: List[Move.Move],
        r: Rotation.Rotation,
        inverted: Bool
    ): List[Move.Move] =
        let undone = if (inverted) Move.inverseOf(ms) else ms;
        undone |> List.map(m -> Rotation.reframe(m, Rotation.inverse(r)))

    ///
    /// A solution found by searching `c` only, never its inverse.
    ///
    /// Kept public because it is the baseline the two-direction search is
    /// measured against, and a comparison against something that is no longer
    /// reachable is not a comparison.
    ///
    pub def oneDirection(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        budget: Budget,
        c: Sized.Standard
    ): Result[String, List[Move.Move]] =
        let Budget(limits) = budget;
        match searchOnce(p1, p2, budget, c) {
            case (Some(best), _) => Ok(best)
            case (None, _) =>
                Err("no solution within ${limits#probeMax} probes and "
                    + "${limits#maxDepth} moves: raise the budget rather than "
                    + "retrying this search unchanged")
        }

    ///
    /// One search, reporting the probes it spent as well as what it found.
    ///
    /// The probe count is what lets several searches share a budget rather than
    /// each being handed a slice of it. Slicing was measurably worse: six
    /// searches on a sixth of the budget each are all too starved to use the
    /// diversity they were added for.
    ///
    def searchOnce(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        budget: Budget,
        c: Sized.Standard
    ): (Option[List[Move.Move]], Int32) =
        let Budget(limits) = budget;
        match Phase1.stateOf(c) {
            case Err(_) => (None, 0)
            case Ok(start) =>
                let first = Phase1.heuristicAt(p1, start);
                let attempt = { phase1 = p1, phase2 = p2, limits = limits, cube = c };
                byDepth(attempt, start, first, 0, None)
        }

    ///
    /// What a solve carries through its depths.
    ///
    type alias Attempt = {
        phase1 = Phase1.Tables,
        phase2 = Domino.Tables,
        limits = { minViews = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 },
        cube = Sized.Standard
    }

    ///
    /// Try each phase-one depth in turn, keeping the best total so far.
    ///
    def byDepth(
        attempt: Attempt,
        start: Int64,
        depth: Int32,
        probes: Int32,
        best: Option[List[Move.Move]]
    ): (Option[List[Move.Move]], Int32) =
        let limits = attempt#limits;
        // A view runs to its own end. The tier counts whole views, so stopping
        // one part-way would make "a view" mean different amounts of work
        // depending on where the probe count happened to land -- which is how
        // two presets that differed only in a probe floor came to behave
        // identically.
        let spent = probes >= limits#probeMax;
        if (depth > Phase1.maxDepth() or spent)
            (best, probes)
        else {
            let handovers = IdaStar.enumerate(
                Phase1.phaseOf(attempt#phase1), start, depth, limits#handovers);
            let (probed, improved) = tryHandovers(attempt, handovers, probes, best);
            byDepth(attempt, start, depth + 1, probed, improved)
        }

    ///
    /// Whether there is a solution and enough has been spent looking for a
    /// better one.
    ///
    def hasSettled(
        best: Option[List[Move.Move]],
        viewsDone: Int32,
        limits: { minViews = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 }
    ): Bool =
        Option.isEmpty(best) == false and viewsDone >= limits#minViews

    ///
    /// A handover phase one is offering: the moves, the state they leave, and
    /// the fewest moves phase two could possibly need from it.
    ///
    type alias Handover = {
        prefix = List[Move.Move],
        state = Int64,
        bound = Int32
    }

    ///
    /// What phase two makes of one handover, or nothing if it does not reach
    /// the domino group at all.
    ///
    def describe(attempt: Attempt, handover: List[Int32]): Option[Handover] =
        let prefix = handover |> List.map(Phase1.moveOfIndex);
        let after = Cube.applyAll(prefix, Sized.cubeOfStandard(attempt#cube));
        match after |> Result.flatMap(Domino.coordsOf) {
            case Err(_) => None
            case Ok((cperm, eperm, mperm)) =>
                let state = Domino.packPhase2(cperm, eperm, mperm);
                Some({
                    prefix = prefix,
                    state = state,
                    bound = Domino.lowerBoundOf(attempt#phase2, state)
                })
        }

    ///
    /// Try each handover in turn, returning the probes spent and the best found.
    ///
    /// A handover whose lower bound already puts it at or past the current best
    /// is skipped without a probe. That is not a change to what a probe means --
    /// a probe is a phase-two attempt, and this handover is never attempted,
    /// because arithmetic has already proved it cannot win. The check is made
    /// against the *current* best rather than the one the ranking saw, so each
    /// improvement prunes the handovers still to come.
    ///
    def tryHandovers(
        attempt: Attempt,
        handovers: List[List[Int32]],
        probes: Int32,
        best: Option[List[Move.Move]]
    ): (Int32, Option[List[Move.Move]]) =
        match handovers {
            case Nil => (probes, best)
            case first :: rest =>
                let limits = attempt#limits;
                if (probes >= limits#probeMax)
                    (probes, best)
                else
                    match describe(attempt, first) {
                        case None => tryHandovers(attempt, rest, probes, best)
                        case Some(h) =>
                            let room =
                                shorterThanBest(best, limits#maxDepth) - List.length(h#prefix);
                            if (h#bound > room)
                                // Proven unable to beat the answer in hand, so it
                                // is not attempted and is not a probe.
                                tryHandovers(attempt, rest, probes, best)
                            else
                                tryHandovers(
                                    attempt, rest, probes + 1, tryOne(attempt, h, best))
                    }
        }

    ///
    /// One probe: finish the handover with phase two and keep it if it is better.
    ///
    def tryOne(
        attempt: Attempt,
        handover: Handover,
        best: Option[List[Move.Move]]
    ): Option[List[Move.Move]] =
        let limits = attempt#limits;
        let prefix = handover#prefix;
        let room = shorterThanBest(best, limits#maxDepth) - List.length(prefix);
        if (room < 0)
            best
        else
            match finishFrom(attempt, handover#state, room) {
                case None       => best
                case Some(rest) => keepShorter(best, List.append(prefix, rest))
            }

    ///
    /// The longest total worth looking for: shorter than the best so far, and
    /// never longer than the budget allows.
    ///
    def shorterThanBest(best: Option[List[Move.Move]], maxLength: Int32): Int32 =
        match best {
            case None    => maxLength
            case Some(b) => Int32.min(maxLength, List.length(b) - 1)
        }

    ///
    /// Phase two from the state the handover leaves, in at most `room` moves.
    ///
    def finishFrom(attempt: Attempt, state: Int64, room: Int32): Option[List[Move.Move]] =
        let search = Domino.phase2Of(attempt#phase2);
        let ceiling = Domino.maxPhase2Depth();
        IdaStar.search(search, state, Int32.min(room, ceiling), IdaStar.unbounded())
            |> Result.map(f -> IdaStar.moves(f) |> List.map(Domino.moveOfIndex))
            |> Result.toOption

    ///
    /// The shorter of the best so far and a new candidate.
    ///
    def keepShorter(
        best: Option[List[Move.Move]],
        candidate: List[Move.Move]
    ): Option[List[Move.Move]] =
        match best {
            case None    => Some(candidate)
            case Some(b) =>
                if (List.length(candidate) < List.length(b)) Some(candidate) else Some(b)
        }

}
