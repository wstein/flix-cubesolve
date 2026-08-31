///
/// Deriving a routine by searching for one.
///
/// A beginner routine is a short sequence that reaches a stated goal and leaves
/// everything already solved as it found it. **The goal is a predicate on the
/// decoded cube, not a coordinate**, which is what makes it different from the
/// searches in `CubeSolve.Solve`: those aim at one fixed target that a table
/// can measure the distance to, and these aim at whatever the next stage of a
/// method happens to be -- "this corner is in, and the cross still is".
///
/// So there is no heuristic here, and there cannot usefully be one: a table per
/// goal would be a table per stage of every method. What makes it tractable is
/// that the sequences being looked for are short. A routine a person memorises
/// is six to eleven moves, and iterative deepening with the usual face pruning
/// searches that range in seconds.
///
/// **This is a generator, not a solver.** It runs once to derive a corpus that
/// is then committed as source, the way the pattern collections are. Nothing on
/// a solving path calls it.
///
mod CubeSolve.Method.Derive {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    ///
    /// The shortest sequence of `moves` from `start` that satisfies `goal`, or
    /// nothing within `maxDepth`.
    ///
    enum Spec {
        case Spec(Cube.Cube -> Bool, Vector[Move.Move])
    }

    ///
    /// The shortest sequence of `moves` from `start` that satisfies `goal`, or
    /// nothing within `maxDepth`.
    ///
    /// Iterative deepening, so the first answer found is the shortest. A
    /// sequence is never allowed two turns of one face in a row -- they compose
    /// into a single turn, so trying both is searching the same thing twice --
    /// and that is the only pruning: anything cleverer would have to know what
    /// the goal means.
    ///
    pub def shortest(
        start: Cube.Cube,
        goal: Cube.Cube -> Bool,
        moves: Vector[Move.Move],
        maxDepth: Int32
    ): Option[List[Move.Move]] =
        if (goal(start))
            Some(Nil)
        else
            deepen(Spec.Spec(goal, moves), start, 1, maxDepth)

    ///
    /// Try one depth, then the next.
    ///
    def deepen(
        spec: Spec,
        start: Cube.Cube,
        depth: Int32,
        maxDepth: Int32
    ): Option[List[Move.Move]] =
        if (depth > maxDepth)
            None
        else
            match descend(spec, start, depth, -1) {
                case Some(found) => Some(found)
                case None        => deepen(spec, start, depth + 1, maxDepth)
            }

    ///
    /// Depth-first to exactly `left` more moves.
    ///
    /// The answer is built as `m :: rest` with `m` the move made here, so it
    /// comes back in the order it is performed and needs no reversing. An
    /// earlier version reversed it, which returned a sequence that reached the
    /// goal backwards -- and a test that checked only the length of the answer
    /// agreed with it.
    ///
    def descend(
        spec: Spec,
        c: Cube.Cube,
        left: Int32,
        lastFace: Int32
    ): Option[List[Move.Move]] =
        let Spec.Spec(goal, _) = spec;
        if (left == 0)
            if (goal(c)) Some(Nil) else None
        else
            tryFrom(spec, 0, c, left, lastFace)

    ///
    /// Each move in turn, skipping another turn of the face just turned.
    ///
    def tryFrom(
        spec: Spec,
        i: Int32,
        c: Cube.Cube,
        left: Int32,
        lastFace: Int32
    ): Option[List[Move.Move]] =
        let Spec.Spec(_, moves) = spec;
        if (i >= Vector.length(moves))
            None
        else {
            let m = Vector.get(i, moves);
            let face = Move.faceIndex(Move.face(m));
            let outcome = if (face == lastFace) None else attemptMove(spec, c, left, m, face);
            match outcome {
                case Some(ans) => Some(ans)
                case None      => tryFrom(spec, i + 1, c, left, lastFace)
            }
        }

    ///
    /// Attempt one valid candidate move and descend.
    ///
    def attemptMove(
        spec: Spec,
        c: Cube.Cube,
        left: Int32,
        m: Move.Move,
        face: Int32
    ): Option[List[Move.Move]] =
        match Cube.apply(m, c) {
            case Ok(after) =>
                match descend(spec, after, left - 1, face) {
                    case Some(rest) => Some(m :: rest)
                    case None       => None
                }
            case Err(_) => None
        }
}
