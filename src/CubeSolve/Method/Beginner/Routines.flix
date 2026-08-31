///
/// The routines the beginner method plays back, one record each.
///
/// **Generated source.** Every sequence here was derived by
/// `CubeSolve.Method.Derive` under the policy `beginner-routines@1`: the goal
/// and the alphabet come from `CubeSolve.Method.Beginner.Spec`, and the
/// sequence is the shortest the search found. Nothing is transcribed from any
/// guide.
///
/// It is committed rather than derived at run time on purpose. These sequences
/// are part of what the method teaches, so a change to one belongs in a diff
/// somebody can read -- the twist-1 insertion ceasing to be `R U R'` is a fact
/// about the product, not an implementation detail free to vary with a
/// tie-break. Deriving them costs milliseconds; that is not why they are here.
///
/// **What each record means is in `Spec`, not here.** A record names a
/// `Situation` and nothing else about its intent, so the case it answers, the
/// rung it establishes, what it must leave alone and how it was derived are one
/// definition rather than a sentence per record that could disagree with its
/// neighbours.
///
/// `CubeSolve.Method.Derive` remains the authority: `TestRoutines` regenerates
/// every record under its situation's own alphabet and bound, checks it equals
/// what is written here, and replays it.
///
/// This is not `CubeSolve.Patterns`. That module holds externally published
/// states and carries their provenance; these are derived here and carry ours.
///
mod CubeSolve.Method.Beginner.Routines {

    use CubeSolve.Method.Beginner.Spec.Situation

    ///
    /// One routine, and everything needed to check it again.
    ///
    /// - `situation` -- what it answers. `Spec` says what that means.
    /// - `setup` -- a sequence from solved reaching a state where the situation
    ///   holds. The routine is its inverse, so the two are a round trip.
    /// - `length` -- the derived move count, recorded so that a longer
    ///   replacement cannot arrive unnoticed.
    ///
    pub type alias Routine = {
        name = String,
        situation = Situation,
        setup = String,
        sequence = String,
        length = Int32
    }

    ///
    /// The policy the corpus was derived under.
    ///
    /// Bump it when the alphabets, the predicates in `Spec` or the search change
    /// in a way that could produce different sequences.
    ///
    pub def policy(): String = "beginner-routines@1"

    ///
    /// How the corpus was made, for anyone reading a plan that used it.
    ///
    pub def provenance(): String =
        "derived by CubeSolve.Method.Derive under ${policy()}"

    ///
    /// Every routine, in the order the method works through them.
    ///
    pub def all(): List[Routine] =
        List.append(cornerInsertions(), middleInsertions())

    ///
    /// Putting a first-layer corner in, by where it is and how it is twisted.
    ///
    /// Fourteen: four top slots by three twists, and the corner sitting in its
    /// own slot the wrong way round, which has to come out before it can go
    /// back. `Spec.cornerSituations` is the list this must cover, and
    /// `TestRoutines` checks that it does.
    ///
    pub def cornerInsertions(): List[Routine] =
        List.append(cornerFromTop(), cornerInPlace())

    ///
    /// The corner waiting in the top layer: four slots, three twists.
    ///
    pub def cornerFromTop(): List[Routine] =
        List.append(cornerFromFrontSlots(), cornerFromBackSlots())

    ///
    /// Waiting at `UR` or `UF`, the two top slots nearest the one it belongs in.
    ///
    pub def cornerFromFrontSlots(): List[Routine] =
        { name = "corner-insertion-slot-0-twist-0",
          situation = Situation.CornerInsertion(0, 0),
          setup = "R2 U R2 U' R2",
          sequence = "R2 U R2 U' R2",
          length = 5 } ::
        { name = "corner-insertion-slot-0-twist-1",
          situation = Situation.CornerInsertion(0, 1),
          setup = "R U' R'",
          sequence = "R U R'",
          length = 3 } ::
        { name = "corner-insertion-slot-0-twist-2",
          situation = Situation.CornerInsertion(0, 2),
          setup = "R U R' U'",
          sequence = "U R U' R'",
          length = 4 } ::
        { name = "corner-insertion-slot-1-twist-0",
          situation = Situation.CornerInsertion(1, 0),
          setup = "R2 U R2 U' R2 U",
          sequence = "U' R2 U R2 U' R2",
          length = 6 } ::
        { name = "corner-insertion-slot-1-twist-1",
          situation = Situation.CornerInsertion(1, 1),
          setup = "R U' R' U",
          sequence = "U' R U R'",
          length = 4 } ::
        { name = "corner-insertion-slot-1-twist-2",
          situation = Situation.CornerInsertion(1, 2),
          setup = "R U R'",
          sequence = "R U' R'",
          length = 3 } ::
        Nil

    ///
    /// Waiting at `UL` or `UB`, which take a further turn to bring round.
    ///
    pub def cornerFromBackSlots(): List[Routine] =
        { name = "corner-insertion-slot-2-twist-0",
          situation = Situation.CornerInsertion(2, 0),
          setup = "R2 U R2 U' R2 U2",
          sequence = "U2 R2 U R2 U' R2",
          length = 6 } ::
        { name = "corner-insertion-slot-2-twist-1",
          situation = Situation.CornerInsertion(2, 1),
          setup = "R U' R' U2",
          sequence = "U2 R U R'",
          length = 4 } ::
        { name = "corner-insertion-slot-2-twist-2",
          situation = Situation.CornerInsertion(2, 2),
          setup = "R U2 R'",
          sequence = "R U2 R'",
          length = 3 } ::
        { name = "corner-insertion-slot-3-twist-0",
          situation = Situation.CornerInsertion(3, 0),
          setup = "R2 U R2 U' R2 U'",
          sequence = "U R2 U R2 U' R2",
          length = 6 } ::
        { name = "corner-insertion-slot-3-twist-1",
          situation = Situation.CornerInsertion(3, 1),
          setup = "R U' R' U'",
          sequence = "U R U R'",
          length = 4 } ::
        { name = "corner-insertion-slot-3-twist-2",
          situation = Situation.CornerInsertion(3, 2),
          setup = "R U R' U2",
          sequence = "U2 R U' R'",
          length = 4 } ::
        Nil

    ///
    /// The corner already in its slot and the wrong way round.
    ///
    /// It has to come out before it can go back, which is why these are longer
    /// than the twelve above and why they are a case rather than an exception.
    ///
    pub def cornerInPlace(): List[Routine] =
        { name = "corner-insertion-slot-4-twist-1",
          situation = Situation.CornerInsertion(4, 1),
          setup = "R U R' U' R U R'",
          sequence = "R U' R' U R U' R'",
          length = 7 } ::
        { name = "corner-insertion-slot-4-twist-2",
          situation = Situation.CornerInsertion(4, 2),
          setup = "R U' R' U R U' R'",
          sequence = "R U R' U' R U R'",
          length = 7 } ::
        Nil

    ///
    /// Putting a middle edge in from the top, by where it sits and which way
    /// round it is.
    ///
    /// Eight cases, because the alphabet includes `U`: the turn that brings the
    /// edge to where the routine wants it is part of the routine, so the method
    /// needs no separate aligning step.
    ///
    pub def middleInsertions(): List[Routine] =
        { name = "middle-insert-slot-0-flip-0",
          situation = Situation.MiddleInsert(0, 0),
          setup = "R U R' U' F' U' F U", sequence = "U' F' U F U R U' R'", length = 8 } ::
        { name = "middle-insert-slot-0-flip-1",
          situation = Situation.MiddleInsert(0, 1),
          setup = "F' U F U2 R U2 R'", sequence = "R U2 R' U2 F' U' F", length = 7 } ::
        { name = "middle-insert-slot-1-flip-0",
          situation = Situation.MiddleInsert(1, 0),
          setup = "R U' R' U2 F' U2 F", sequence = "F' U2 F U2 R U R'", length = 7 } ::
        { name = "middle-insert-slot-1-flip-1",
          situation = Situation.MiddleInsert(1, 1),
          setup = "R F' U' F U F R' F'", sequence = "F R F' U' F' U F R'", length = 8 } ::
        { name = "middle-insert-slot-2-flip-0",
          situation = Situation.MiddleInsert(2, 0),
          setup = "R U R' U' F' U' F U'", sequence = "U F' U F U R U' R'", length = 8 } ::
        { name = "middle-insert-slot-2-flip-1",
          situation = Situation.MiddleInsert(2, 1),
          setup = "R' F R F' R U R'", sequence = "R U' R' F R' F' R", length = 7 } ::
        { name = "middle-insert-slot-3-flip-0",
          situation = Situation.MiddleInsert(3, 0),
          setup = "R U R' U' F' U' F", sequence = "F' U F U R U' R'", length = 7 } ::
        { name = "middle-insert-slot-3-flip-1",
          situation = Situation.MiddleInsert(3, 1),
          setup = "R' F R F' R U R' U", sequence = "U' R U' R' F R' F' R", length = 8 } ::
        Nil

    ///
    /// The routine of that name, if there is one.
    ///
    pub def named(name: String): Option[Routine] =
        all() |> List.findLeft(r -> r#name == name)

    ///
    /// The routine for a situation, if the corpus has one.
    ///
    /// This is how the method chooses: it observes a situation and asks for the
    /// routine that answers it, rather than matching on a name it built itself.
    ///
    pub def forSituation(s: Situation): Option[Routine] =
        all() |> List.findLeft(r -> r#situation == s)
}
