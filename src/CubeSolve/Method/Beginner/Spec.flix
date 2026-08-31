///
/// What each routine is for, as types rather than as prose.
///
/// A routine record says which situation it answers; everything that situation
/// means -- the case that must hold before it, the rung it establishes, what it
/// must leave alone, the alphabet it was derived over and how deep the search
/// was allowed to go -- is here, in one place, in production code.
///
/// **This is deliberately not a string.** An earlier version carried the goal
/// and the preservations as sentences and matched on them in the test, with a
/// fallback for anything unrecognised. A misspelt sentence therefore selected
/// the fallback and was checked against the wrong claim, which is the one
/// failure a corpus like this must not have. A situation that this module does
/// not know is a type error, not a quiet default.
///
/// **`achieves` and `preserves` are separate on purpose, and neither is the
/// other.** A last-layer routine achieves exactly its rung -- orienting the top
/// edges says nothing about where they end up -- and preserves exactly the rungs
/// below it. Asserting more than that would let a routine that happened to
/// solve more on one fixture make the extra an undocumented requirement.
///
mod CubeSolve.Method.Beginner.Spec {

    use CubeSolve.Method.Facts
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move

    ///
    /// The situation a routine answers.
    ///
    /// The parameters are the case: where the piece is and how it sits. They
    /// are part of the type so that a record cannot name a situation without
    /// saying which one.
    ///
    pub enum Situation with Eq, ToString {
        /// The `DFR` corner is in the given top slot, twisted by the given
        /// thirds. The slot is part of the case rather than something a
        /// separate aligning rule fixes first, because the alphabet includes
        /// `U`: the turn that brings the corner over its slot is part of the
        /// routine, which keeps stage selection self-contained.
        case CornerInsertRight(Int32, Int32)
        /// The `FR` edge is in the given top slot, with the given flip.
        case MiddleInsert(Int32, Int32)
    }

    ///
    /// The family a situation belongs to, for grouping and for messages.
    ///
    pub def family(s: Situation): String = match s {
        case Situation.CornerInsertRight(_, _) => "corner-insert-right"
        case Situation.MiddleInsert(_, _)   => "middle-insert"
    }

    ///
    /// What must hold before the routine is played.
    ///
    pub def caseHolds(s: Situation): Cube.Cube -> Bool = match s {
        case Situation.CornerInsertRight(slot, twist) =>
            c -> preserves(s)(c) and (match Facts.findCorner(c, 4) {
                case Ok(p)  => p#slot == slot and p#turn == twist
                case Err(_) => false
            })
        case Situation.MiddleInsert(slot, flip) =>
            c -> preserves(s)(c) and (match Facts.findEdge(c, 8) {
                case Ok(p)  => p#slot == slot and p#turn == flip
                case Err(_) => false
            })
    }

    ///
    /// The rung the routine establishes, and nothing stronger.
    ///
    pub def achieves(s: Situation): Cube.Cube -> Bool = match s {
        case Situation.CornerInsertRight(_, _) =>
            c -> ok(Facts.cornerHome(c, 4))
        case Situation.MiddleInsert(_, _) =>
            c -> ok(Facts.edgeHome(c, 8))
    }

    ///
    /// What must be as it was afterwards: the rungs already established.
    ///
    /// The corner insertions keep the cross and the three bottom corners that
    /// are already in. The middle insertions keep the whole first layer and the
    /// three middle edges already in. Neither says anything about the top,
    /// which is what the later stages are for.
    ///
    pub def preserves(s: Situation): Cube.Cube -> Bool = match s {
        case Situation.CornerInsertRight(_, _) =>
            c -> ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, false))
                and ok(Facts.allHome(c, Vector#{5, 6, 7}, true))
        case Situation.MiddleInsert(_, _) =>
            c -> ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, false))
                and ok(Facts.allHome(c, Vector#{4, 5, 6, 7}, true))
                and ok(Facts.allHome(c, Vector#{9, 10, 11}, false))
    }

    ///
    /// What the routine must leave alone, in words, for a plan to print.
    ///
    pub def preservesWritten(s: Situation): String = match s {
        case Situation.CornerInsertRight(_, _) => "cross; corners DLF, DBL, DRB"
        case Situation.MiddleInsert(_, _)   => "first layer; edges FL, BL, BR"
    }

    ///
    /// What the routine is for, in words, for a plan to print.
    ///
    pub def achievesWritten(s: Situation): String = match s {
        case Situation.CornerInsertRight(_, _) => "the DFR corner is home and untwisted"
        case Situation.MiddleInsert(_, _)   => "the FR edge is home and unflipped"
    }

    ///
    /// The faces the search was allowed, as letters.
    ///
    /// Two for a corner, which is what a person turns; three for a middle edge,
    /// which needs the front face to take the edge out of the top and put it
    /// back.
    ///
    pub def alphabetWritten(s: Situation): String = match s {
        case Situation.CornerInsertRight(_, _) => "R U"
        case Situation.MiddleInsert(_, _)   => "R U F"
    }

    ///
    /// The alphabet as moves.
    ///
    pub def alphabet(s: Situation): Vector[Move.Move] =
        String.splitOn(substr = " ", alphabetWritten(s))
            |> List.flatMap(l -> (l :: "${l}2" :: "${l}'" :: Nil))
            |> List.filterMap(t -> Move.parseMove(t) |> Result.toOption)
            |> List.toVector

    ///
    /// How deep the derivation was allowed to search for this family.
    ///
    /// Owned by the family rather than by each record, because it is a property
    /// of the search that produced them all. A family whose routines are longer
    /// -- permuting the last layer will be -- raises its own bound here rather
    /// than every caller guessing one.
    ///
    pub def maxDepth(s: Situation): Int32 = match s {
        case Situation.CornerInsertRight(_, _) => 8
        case Situation.MiddleInsert(_, _)   => 8
    }

    ///
    /// A predicate that could not be read is a failure, not a `true`.
    ///
    def ok(r: Result[String, Bool]): Bool = Result.getWithDefault(false, r)
}
