///
/// Iterative-deepening A*, over any phase that can describe itself in integers.
///
/// This is the engine's only search. Every phase of every size uses it
/// unchanged, supplying four things: how many moves its alphabet has, where a
/// move leads, a lower bound on the distance remaining, and how to recognise
/// the goal.
///
/// **The heuristic must be admissible** -- never larger than the true distance.
/// Every heuristic here comes from a homomorphic projection of the state, which
/// is admissible for a structural reason rather than by inspection: if a move
/// acts on the projection without reference to what was projected away, then
/// the projection of a path is itself a path, so the quotient distance can only
/// be shorter.
///
/// **An inadmissible heuristic returns a longer solution, never a shorter
/// one.** The search returns an actual path, so its length is always at least
/// the true distance; what an inadmissible heuristic does is prune the branch
/// the optimal solution was on. A test that only checks "the answer is not too
/// short" therefore proves nothing, which is why the tests check admissibility
/// exhaustively and optimality against the exact oracle.
///
mod CubeSolve.Solve.IdaStar {

    use CubeSolve.Solve.IdaStar.Phase.Phase
    use CubeSolve.Solve.IdaStar.Found.Found

    ///
    /// Everything the search needs to know about one phase.
    ///
    /// State is a single machine integer, and the phase says which width. That
    /// is not a simplification: it is what lets a successor be one array read,
    /// which is the whole reason the search layer does not speak the model's
    /// language.
    ///
    /// The width is a parameter because one width does not fit every phase. The
    /// 2x2x2's whole space is 3,674,160 states and rides in an `Int32`; the
    /// 3x3x3's phase one is `Twist x Flip x UDSlice`, which is 2,217,093,120
    /// and does not. Flix monomorphises, so the choice costs nothing at run
    /// time -- each phase gets a specialised search rather than a boxed one.
    ///
    pub type alias Spec[s] = {
        moves = Int32,
        successor = (s, Int32) -> s,
        heuristic = s -> Int32,
        isGoal = s -> Bool,
        allows = (Int32, Int32) -> Bool
    }

    ///
    /// One phase of a search, over states of type `s`.
    ///
    pub enum Phase[s] {
        case Phase(Spec[s])
    }

    ///
    /// A solution, and what it cost to find.
    ///
    /// The node count is reported because it is the only honest measure of a
    /// search change: a heuristic that halves the nodes is an improvement
    /// whatever the clock says that day, and a regression in it is visible
    /// where a timing is not.
    ///
    pub enum Found {
        case Found({ moves = List[Int32], nodes = Int64 })
    }

    ///
    /// The moves of the solution, in order.
    ///
    pub def moves(f: Found): List[Int32] = let Found(r) = f; r#moves

    ///
    /// How many nodes the search visited.
    ///
    pub def nodes(f: Found): Int64 = let Found(r) = f; r#nodes

    ///
    /// How long the solution is.
    ///
    pub def length(f: Found): Int32 = List.length(moves(f))

    ///
    /// A phase over `moveCount` moves.
    ///
    /// `successor(state, move)` is where a move leads, `heuristic(state)` is a
    /// lower bound on the moves still needed, `isGoal(state)` recognises the
    /// target, and `allows(lastMove, move)` prunes redundant orderings, with
    /// `lastMove` negative at the root.
    ///
    pub def phase(
        moveCount: Int32,
        successor: (s, Int32) -> s,
        heuristic: s -> Int32,
        isGoal: s -> Bool,
        allows: (Int32, Int32) -> Bool
    ): Phase[s] =
        Phase({
            moves = moveCount,
            successor = successor,
            heuristic = heuristic,
            isGoal = isGoal,
            allows = allows
        })

    ///
    /// One depth-bounded pass: the phase, the scratch it writes to, and the
    /// bound it is working to.
    ///
    /// Grouped because all four are constant through a pass and threading them
    /// separately would put six arguments on the hot recursion.
    ///
    type alias Pass[s: Type, r: Region] = {
        spec = Spec[s],
        path = Array[Int32, r],
        visited = Ref[Int64, r],
        bound = Int32
    }

    ///
    /// The shortest solution `p` admits from `start`, or why there is none.
    ///
    /// Deepens one move at a time from the heuristic's own estimate, so the
    /// first solution found is the shortest -- given an admissible heuristic.
    /// `maxDepth` is a quality constraint rather than a safety net: passing it
    /// is reported as exhaustion naming the depth reached, so a caller can
    /// raise it deliberately instead of guessing.
    ///
    pub def search(p: Phase[s], start: s, maxDepth: Int32): Result[String, Found] =
        region rc {
            let Phase(spec) = p;
            let pass = {
                spec = spec,
                path = Array.repeat(rc, maxDepth + 1, 0),
                visited = Ref.fresh(rc, 0i64),
                bound = (spec#heuristic)(start)
            };
            deepen(pass, start, maxDepth)
        }

    ///
    /// Try one bound, then the next, until the solution is found or `maxDepth`
    /// is passed.
    ///
    def deepen(pass: Pass[s, r], start: s, maxDepth: Int32): Result[String, Found] \ r =
        if (pass#bound > maxDepth)
            Err("no solution of ${maxDepth} moves or fewer: the heuristic still "
                + "demands more at depth ${maxDepth}, so raise the depth rather "
                + "than retrying this search unchanged")
        else if (descend(pass, start, 0, -1))
            Ok(Found({
                moves = List.take(pass#bound, Array.toList(pass#path)),
                nodes = Ref.get(pass#visited)
            }))
        else
            deepen(atBound(pass, pass#bound + 1), start, maxDepth)

    ///
    /// The same pass, working to a deeper bound.
    ///
    def atBound(pass: Pass[s, r], bound: Int32): Pass[s, r] =
        { spec = pass#spec, path = pass#path, visited = pass#visited, bound = bound }

    ///
    /// Depth-first to the pass's bound, writing moves into the path as it goes.
    ///
    /// The path is written in place rather than returned, so abandoning a node
    /// costs nothing. Only a successful path is ever read, and only its first
    /// `bound` entries mean anything.
    ///
    def descend(pass: Pass[s, r], state: s, depth: Int32, lastMove: Int32): Bool \ r =
        Ref.put(Ref.get(pass#visited) + 1i64, pass#visited);
        let spec = pass#spec;
        if (depth + (spec#heuristic)(state) > pass#bound)
            false
        else if ((spec#isGoal)(state))
            depth == pass#bound
        else if (depth >= pass#bound)
            false
        else
            tryMoves(pass, state, depth, lastMove, 0)

    ///
    /// Every move the pruning rule allows, in order, until one succeeds.
    ///
    def tryMoves(
        pass: Pass[s, r],
        state: s,
        depth: Int32,
        lastMove: Int32,
        m: Int32
    ): Bool \ r =
        let spec = pass#spec;
        if (m >= spec#moves)
            false
        else if (not (spec#allows)(lastMove, m))
            tryMoves(pass, state, depth, lastMove, m + 1)
        else {
            Array.put(m, depth, pass#path);
            if (descend(pass, (spec#successor)(state, m), depth + 1, m))
                true
            else
                tryMoves(pass, state, depth, lastMove, m + 1)
        }

    // ---------- enumerating, for a two-phase search ----------

    ///
    /// Up to `limit` solutions of exactly `depth` moves, from `start`.
    ///
    /// A two-phase solver needs more than the first answer. Its first phase
    /// hands over to its second, and the *shortest* first-phase solution
    /// frequently leads to a long second phase, so the good total solutions come
    /// from trying several handovers rather than the best one. This is what
    /// makes that possible.
    ///
    /// Exactly `depth`, not at most: the caller works upwards through depths so
    /// that it sees short handovers first, and letting a shorter solution appear
    /// again at a deeper bound would repeat work.
    ///
    pub def enumerate(
        p: Phase[s],
        start: s,
        depth: Int32,
        limit: Int32
    ): List[List[Int32]] =
        region rc {
            let Phase(spec) = p;
            let scratch = Array.repeat(rc, depth + 1, 0);
            let sweep = {
                spec = spec,
                path = scratch,
                found = MutList.empty(rc),
                limit = limit,
                depth = depth
            };
            collect(sweep, start, 0, -1);
            MutList.toList(sweep#found) |> List.reverse
        }

    ///
    /// An enumeration in progress: the phase, the scratch path, what has been
    /// found, and the bounds it is working to.
    ///
    type alias Gather[s: Type, r: Region] = {
        spec = Spec[s],
        path = Array[Int32, r],
        found = MutList[List[Int32], r],
        limit = Int32,
        depth = Int32
    }

    ///
    /// Depth-first at a fixed bound, keeping every path that reaches the goal.
    ///
    def collect(sweep: Gather[s, r], state: s, at: Int32, lastMove: Int32): Unit \ r =
        let spec = sweep#spec;
        if (MutList.size(sweep#found) >= sweep#limit)
            ()
        else if (at == sweep#depth) {
            if ((spec#isGoal)(state))
                MutList.push(List.take(sweep#depth, Array.toList(sweep#path)), sweep#found)
            else ()
        } else if (at + (spec#heuristic)(state) > sweep#depth)
            ()
        else
            eachMove(sweep, state, at, lastMove, 0)

    ///
    /// Every move the pruning rule allows, at one node.
    ///
    def eachMove(
        sweep: Gather[s, r],
        state: s,
        at: Int32,
        lastMove: Int32,
        m: Int32
    ): Unit \ r =
        let spec = sweep#spec;
        if (m >= spec#moves or MutList.size(sweep#found) >= sweep#limit)
            ()
        else {
            if ((spec#allows)(lastMove, m)) {
                Array.put(m, at, sweep#path);
                collect(sweep, (spec#successor)(state, m), at + 1, m)
            } else ();
            eachMove(sweep, state, at, lastMove, m + 1)
        }

}
