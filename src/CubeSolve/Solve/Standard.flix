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
    /// A solution for `c`, using both phases' tables together.
    ///
    pub def solutionWith(
        t: Tables,
        budget: Budget,
        c: Sized.Standard
    ): Result[String, List[Move.Move]] =
        let Tables.Tables(p1, p2) = t;
        solution(p1, p2, budget, c)

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
        case Budget({ probeMin = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 })
    }

    ///
    /// A budget that returns a good solution quickly.
    ///
    /// Thirty probes past the first solution, five hundred in all, and nothing
    /// longer than twenty-five moves. Modest next to the reference's defaults,
    /// and chosen so the tests are a gate rather than a benchmark.
    ///
    pub def defaultBudget(): Budget =
        Budget({ probeMin = 30, probeMax = 500, maxDepth = 25, handovers = 300 })

    ///
    /// A budget, from its parts.
    ///
    pub def budget(
        parts: { probeMin = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 }
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
        acrossAxes(p1, p2, budget, c)

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
    /// Search every axis, and both directions of each, keeping the shortest.
    ///
    /// The probe budget is divided between the six searches rather than spent
    /// six times over, so this costs no more probes than a single search and
    /// can be compared with the recorded baseline directly.
    ///
    def acrossAxes(
        p1: Phase1.Tables,
        p2: Domino.Tables,
        budget: Budget,
        c: Sized.Standard
    ): Result[String, List[Move.Move]] =
        let Budget(limits) = budget;
        let views = axes() |> List.flatMap(r -> (r, false) :: (r, true) :: Nil);
        let job = { tables = Tables.Tables(p1, p2), budget = budget, cube = c };
        match sweep(job, views, 0, None) {
            case Some(best) => Ok(best)
            case None =>
                Err("no solution within ${limits#probeMax} probes and "
                    + "${limits#maxDepth} moves: raise the budget rather than "
                    + "retrying this search unchanged")
        }

    ///
    /// Work through the views of the cube, all drawing on one probe budget.
    ///
    /// Each search is given whatever is left rather than a fixed share, and is
    /// capped at one move shorter than the best found so far -- so a later view
    /// either improves on the answer or gives up quickly. That is what makes
    /// six searches affordable within one budget.
    ///
    def sweep(
        job: { tables = Tables, budget = Budget, cube = Sized.Standard },
        views: List[(Rotation.Rotation, Bool)],
        spent: Int32,
        best: Option[List[Move.Move]]
    ): Option[List[Move.Move]] =
        let Tables.Tables(p1, p2) = job#tables;
        let c = job#cube;
        let Budget(limits) = job#budget;
        let exhausted = spent >= limits#probeMax;
        let satisfied = bestIsGoodEnough(best, spent, limits);
        match views {
            case Nil                                     => best
            case _ :: _ if exhausted or satisfied        => best
            case (r, inverted) :: rest                   =>
                let remaining = Budget({
                    probeMin = 1,
                    probeMax = limits#probeMax - spent,
                    maxDepth = shorterThanBest(best, limits#maxDepth),
                    handovers = limits#handovers
                });
                let view = { rotation = r, inverted = inverted };
                let (found, used) = alongAxis(p1, p2, remaining, c, view);
                sweep(job, rest, spent + used, keepShorterOf(best, found))
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
        let seen = Cube.conjugate(r, Sized.cubeOfStandard(c));
        let looking = if (view#inverted) Cube.inverse(seen) else seen;
        match Sized.standardOf(looking) {
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
        limits = { probeMin = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 },
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
        let spent = probes >= limits#probeMax;
        let satisfied = bestIsGoodEnough(best, probes, limits);
        if (depth > Phase1.maxDepth() or spent or satisfied)
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
    def bestIsGoodEnough(
        best: Option[List[Move.Move]],
        probes: Int32,
        limits: { probeMin = Int32, probeMax = Int32, maxDepth = Int32, handovers = Int32 }
    ): Bool =
        Option.isEmpty(best) == false and probes >= limits#probeMin

    ///
    /// Try each handover in turn, returning the probes spent and the best found.
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
                if (probes >= limits#probeMax or bestIsGoodEnough(best, probes, limits))
                    (probes, best)
                else {
                    let improved = tryOne(attempt, first, best);
                    tryHandovers(attempt, rest, probes + 1, improved)
                }
        }

    ///
    /// One probe: finish the handover with phase two and keep it if it is better.
    ///
    def tryOne(
        attempt: Attempt,
        handover: List[Int32],
        best: Option[List[Move.Move]]
    ): Option[List[Move.Move]] =
        let limits = attempt#limits;
        let prefix = handover |> List.map(Phase1.moveOfIndex);
        let room = shorterThanBest(best, limits#maxDepth) - List.length(prefix);
        if (room < 0)
            best
        else
            match finishFrom(attempt, prefix, room) {
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
    def finishFrom(
        attempt: Attempt,
        prefix: List[Move.Move],
        room: Int32
    ): Option[List[Move.Move]] =
        let after = Cube.applyAll(prefix, Sized.cubeOfStandard(attempt#cube));
        let coords = after |> Result.flatMap(Domino.coordsOf);
        match coords {
            case Err(_) => None
            case Ok((cperm, eperm, mperm)) =>
                let search = Domino.phase2Of(attempt#phase2);
                let state = Domino.packPhase2(cperm, eperm, mperm);
                let ceiling = Domino.maxPhase2Depth();
                IdaStar.search(search, state, Int32.min(room, ceiling))
                    |> Result.map(f -> IdaStar.moves(f) |> List.map(Domino.moveOfIndex))
                    |> Result.toOption
        }

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
