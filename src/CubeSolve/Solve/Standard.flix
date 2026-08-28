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
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.IdaStar
    use CubeSolve.Solve.Phase1
    use CubeSolve.Solve.Standard.Budget.Budget
    use CubeSolve.Table.Domino

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
        case Budget({ probeMin = Int32, probeMax = Int32, maxDepth = Int32 })
    }

    ///
    /// A budget that returns a good solution quickly.
    ///
    /// Thirty probes past the first solution, five hundred in all, and nothing
    /// longer than twenty-five moves. Modest next to the reference's defaults,
    /// and chosen so the tests are a gate rather than a benchmark.
    ///
    pub def defaultBudget(): Budget =
        Budget({ probeMin = 30, probeMax = 500, maxDepth = 25 })

    ///
    /// How many phase-one handovers to try at each depth.
    ///
    def handoversPerDepth(): Int32 = 60

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
        p1: CubeSolve.Table.Standard.Tables,
        p2: Domino.Tables,
        budget: Budget,
        c: Sized.Standard
    ): Result[String, List[Move.Move]] =
        let Budget(limits) = budget;
        Phase1.stateOf(c) |> Result.flatMap(start -> {
            let first = Phase1.heuristicAt(p1, start);
            let search = { phase1 = p1, phase2 = p2, limits = limits, cube = c };
            match byDepth(search, start, first, 0, None) {
                case Some(best) => Ok(best)
                case None =>
                    Err("no solution within ${limits#probeMax} probes and "
                        + "${limits#maxDepth} moves: raise the budget rather than "
                        + "retrying this search unchanged")
            }
        })

    ///
    /// What a solve carries through its depths.
    ///
    type alias Attempt = {
        phase1 = CubeSolve.Table.Standard.Tables,
        phase2 = Domino.Tables,
        limits = { probeMin = Int32, probeMax = Int32, maxDepth = Int32 },
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
    ): Option[List[Move.Move]] =
        let limits = attempt#limits;
        let spent = probes >= limits#probeMax;
        let satisfied = bestIsGoodEnough(best, probes, limits);
        if (depth > Phase1.maxDepth() or spent or satisfied)
            best
        else {
            let handovers = IdaStar.enumerate(
                Phase1.phaseOf(attempt#phase1), start, depth, handoversPerDepth());
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
        limits: { probeMin = Int32, probeMax = Int32, maxDepth = Int32 }
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
        let prefix = handover |> List.map(CubeSolve.Table.Standard.moveOfIndex);
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
                let search = CubeSolve.Solve.Domino.phase2Of(attempt#phase2);
                let state = CubeSolve.Solve.Domino.packPhase2(cperm, eperm, mperm);
                let ceiling = CubeSolve.Solve.Domino.maxPhase2Depth();
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
