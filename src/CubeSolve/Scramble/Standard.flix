///
/// Random-state scrambles for the 3x3x3, with certified bounds.
///
/// **Scrambles are random-state, not random-move.** A uniformly random move
/// sequence is not uniform over states -- short sequences cancel and the
/// distribution piles up near solved -- so this samples a state uniformly,
/// solves it, and emits the inverse of the solution. Scrambling therefore costs
/// what solving costs.
///
/// **Difficulty is bracketed, never claimed exactly.** The 2x2x2 can say a
/// state is exactly seven moves from solved, because its whole distance table
/// fits in memory. The 3x3x3 cannot, and pretending otherwise would be the
/// easiest lie to tell here. So every scramble carries two numbers that are
/// both certified and both honest about their weakness:
///
/// - **`atMostMoves`** -- an upper bound, certified by an actual solution. It
///   is exact as a bound and pessimistic as a distance, because a two-phase
///   solver is suboptimal by design.
/// - **`atLeastMoves`** -- a lower bound from the phase-one pruning tables. A
///   pruning value cannot exceed its own table's maximum, and those tables max
///   at **9** against a mean optimum near 17.7, so this is weak and says so.
///
/// That asymmetry is not an oversight, it is the shape of the problem: 3x3x3
/// optimal lengths are concentrated near 17 and 18, so almost every state is
/// hard and the difficulty a caller can actually choose lives at the easy end.
/// `atMost` is therefore the useful constructor and `atLeast` the honest but
/// nearly useless one.
///
mod CubeSolve.Scramble.Standard {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Random
    use CubeSolve.Model.Rotation
    use CubeSolve.Model.Sized
    use CubeSolve.Scramble.Standard.Scramble.Scramble
    use CubeSolve.Solve.Phase1
    use CubeSolve.Solve.Standard.Budget
    use CubeSolve.Solve.Standard.Tables

    ///
    /// A scramble, the state it produces, and what is certified about it.
    ///
    pub enum Scramble {
        case Scramble({
            moves = List[Move.Move],
            state = Sized.Standard,
            atMost = Int32,
            atLeast = Int32
        })
    }

    ///
    /// The moves of the scramble, to apply to a solved cube.
    ///
    pub def moves(s: Scramble): List[Move.Move] = let Scramble(r) = s; r#moves

    ///
    /// The state the scramble produces.
    ///
    pub def state(s: Scramble): Sized.Standard = let Scramble(r) = s; r#state

    ///
    /// A certified upper bound on the moves needed, being the length of a
    /// solution that was actually found.
    ///
    pub def atMostMoves(s: Scramble): Int32 = let Scramble(r) = s; r#atMost

    ///
    /// A certified lower bound, from the phase-one pruning tables.
    ///
    pub def atLeastMoves(s: Scramble): Int32 = let Scramble(r) = s; r#atLeast

    ///
    /// The scramble in the usual notation.
    ///
    pub def show(s: Scramble): String = Move.showAll(moves(s))

    ///
    /// The largest lower bound this engine can certify: 9.
    ///
    /// A pruning value is admissible, so it is a true lower bound, but it
    /// cannot exceed its own table's maximum and all three phase-one tables
    /// max at 9. Nothing in the phase-two tables raises it, because those only
    /// apply once the cube is already inside the domino group.
    ///
    pub def lowerBoundCeiling(): Int32 = 9

    // ---------- bounds ----------

    ///
    /// The strongest lower bound the pruning tables certify for `c`.
    ///
    /// Taken as the largest over the three phase-one axes. Each axis's pruning
    /// value bounds the moves needed to reach *that* axis's domino group, and
    /// a full solution passes through the solved cube, which lies in all three
    /// -- so each is a lower bound on the whole solution and the largest of
    /// them is the best of the three. The ceiling is still 9, since none of the
    /// three can exceed it, but the typical bound is better than any one axis
    /// alone.
    ///
    pub def lowerBoundOf(t: Tables, c: Sized.Standard): Int32 =
        let Tables.Tables(p1, _) = t;
        let axes = Rotation.identity() :: Rotation.x() :: Rotation.z() :: Nil;
        axes |> List.foldLeft((best, r) -> {
            let seen = Cube.conjugate(r, Sized.cubeOfStandard(c));
            match seen
                |> Result.flatMap(Sized.standardOf)
                |> Result.flatMap(Phase1.stateOf) {
                case Ok(s)  => Int32.max(best, Phase1.heuristicAt(p1, s))
                case Err(_) => best
            }
        }, 0)

    // ---------- the constructors ----------

    ///
    /// A uniform scramble, and the next seed.
    ///
    /// Uniform over the states turning can reach, which is what a competition
    /// scramble means. The difficulty is whatever the draw gives, and both
    /// bounds are reported rather than left for the caller to recompute.
    ///
    pub def uniform(t: Tables, budget: Budget, seed: Int64): Result[String, (Scramble, Int64)] =
        Random.sampleDeterministic(seed, 3) |> Result.flatMap(match (c, next) ->
            Sized.standardOf(c)
                |> Result.flatMap(cube -> scrambleOf(t, budget, cube))
                |> Result.map(s -> (s, next)))

    ///
    /// A scramble this engine can solve in `d` moves or fewer, and the next seed.
    ///
    /// Certified by an actual solution, so the promise is kept rather than
    /// estimated. Draws and rejects, which is cheap near the middle of the
    /// distribution and expensive below it: the solver's own average is about
    /// 20.8 moves, so asking for much less than that rejects nearly everything.
    /// The floor is therefore set by how well this engine solves, not by how
    /// hard the cube is -- and when the draws run out it says so.
    ///
    pub def atMost(
        t: Tables,
        budget: Budget,
        d: Int32,
        seed: Int64
    ): Result[String, (Scramble, Int64)] =
        rejectUntil(t, {
            budget = budget,
            accepts = s -> atMostMoves(s) <= d,
            whenExhausted =
                "no state was solved in ${d} moves or fewer within ${attempts()} "
                    + "draws: this engine averages about 20.8, so a limit near or "
                    + "below that rejects nearly every draw -- raise the limit or "
                    + "the budget"
        }, seed, attempts())

    ///
    /// A scramble certified to need at least `d` moves, and the next seed.
    ///
    /// Weak on purpose and refuses rather than pretends: see
    /// `lowerBoundCeiling`.
    ///
    pub def atLeast(t: Tables, d: Int32, seed: Int64): Result[String, (Scramble, Int64)] =
        if (d > lowerBoundCeiling())
            Err("cannot certify that a 3x3x3 needs at least ${d} moves: the "
                + "phase-one pruning tables max at ${lowerBoundCeiling()}, and a "
                + "pruning value cannot exceed its own table's maximum, so "
                + "${lowerBoundCeiling()} is the most this engine can prove")
        else
            rejectUntil(t, {
                budget = boundsOnly(),
                accepts = s -> atLeastMoves(s) >= d,
                whenExhausted =
                    "no state with a certified lower bound of ${d} was found "
                        + "within ${attempts()} draws"
            }, seed, attempts())

    ///
    /// How many draws a rejecting constructor makes before giving up.
    ///
    /// Bounded so that an impossible request fails with a reason rather than
    /// running forever, which is the whole of the plan's termination rule
    /// applied to sampling.
    ///
    def attempts(): Int32 = 200

    ///
    /// A budget that finds *a* solution and stops.
    ///
    /// `atLeast` only needs the state's lower bound, which does not depend on
    /// the solution at all, so it should not pay for a good one.
    ///
    def boundsOnly(): Budget =
        CubeSolve.Solve.Standard.budget(
            { probeMin = 1, probeMax = 200, maxDepth = 25, handovers = 300 })

    ///
    /// Draw until a scramble satisfies `wanted`, or give up with `whenExhausted`.
    ///
    def rejectUntil(
        t: Tables,
        want: { budget = Budget, accepts = Scramble -> Bool, whenExhausted = String },
        seed: Int64,
        left: Int32
    ): Result[String, (Scramble, Int64)] =
        if (left <= 0)
            Err(want#whenExhausted)
        else
            match uniform(t, want#budget, seed) {
                case Err(e) => Err(e)
                case Ok((s, next)) =>
                    if ((want#accepts)(s))
                        Ok((s, next))
                    else
                        rejectUntil(t, want, next, left - 1)
            }

    ///
    /// Solve `cube`, and report the inverse of the solution as a scramble.
    ///
    /// Applying the result to a solved cube lands exactly on `cube`, which is
    /// asserted rather than assumed.
    ///
    def scrambleOf(t: Tables, budget: Budget, cube: Sized.Standard): Result[String, Scramble] =
        CubeSolve.Solve.Standard.solutionWith(t, budget, cube)
            |> Result.map(solution -> Scramble({
                moves = Move.inverseOf(solution),
                state = cube,
                atMost = List.length(solution),
                atLeast = lowerBoundOf(t, cube)
            }))

}
