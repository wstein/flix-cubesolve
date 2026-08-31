///
/// The routines the beginner method plays back, one record each.
///
/// **Generated source.** Every sequence here was derived by
/// `CubeSolve.Method.Derive` under the policy `beginner-routines@1`: a goal
/// stated as a predicate on decoded model state, a restricted alphabet, and the
/// shortest sequence the search finds. Nothing is transcribed from any guide.
///
/// It is committed rather than derived at run time on purpose. These sequences
/// are part of what the method teaches, so a change to one belongs in a diff
/// somebody can read -- `corner-insert-right-twist-1` becoming something other
/// than `R U R'` is a fact about the product, not an implementation detail that
/// may vary with a tie-break. Deriving them costs milliseconds; that is not the
/// reason they are here.
///
/// **`CubeSolve.Method.Derive` remains the authority.** `TestRoutines`
/// regenerates each record under its stated alphabet and goal, checks it equals
/// what is written here, replays it from its own setup, and checks every
/// preservation the record claims. A record that drifts from the search fails
/// rather than being believed.
///
/// This is not `CubeSolve.Patterns`. That module holds externally published
/// states and carries their provenance; these are derived here and carry ours.
///
mod CubeSolve.Method.Beginner.Routines {

    ///
    /// One routine, and everything needed to check it again.
    ///
    /// - `alphabet` -- the faces the search was allowed, as letters.
    /// - `goal` -- what the routine is for, in the words the predicate means.
    /// - `preserves` -- what must be as it was afterwards, and is checked to be.
    /// - `setup` -- a sequence from solved that reaches the case this answers.
    ///   The routine is its inverse, so the two together are a round trip.
    /// - `length` -- the derived move count, recorded so a longer replacement
    ///   cannot arrive unnoticed.
    ///
    pub type alias Routine = {
        name = String,
        alphabet = String,
        goal = String,
        preserves = String,
        setup = String,
        sequence = String,
        length = Int32
    }

    ///
    /// The policy the corpus was derived under.
    ///
    /// Recorded so that a regenerated corpus can be told from this one. Bump it
    /// when the alphabet, the goal predicates or the search change in a way that
    /// could produce different sequences.
    ///
    pub def policy(): String = "beginner-routines@1"

    ///
    /// How the corpus was made, for anyone reading a plan that used it.
    ///
    pub def provenance(): String =
        "derived by CubeSolve.Method.Derive under ${policy()}"

    ///
    /// Every routine.
    ///
    pub def all(): List[Routine] =
        { name = "corner-insert-right-twist-0",
          alphabet = "R U",
          goal = "the DFR corner is home and untwisted",
          preserves = "cross; corners DLF, DBL, DRB",
          setup = "R2 U R2 U' R2",
          sequence = "R2 U R2 U' R2",
          length = 5 } ::
        { name = "corner-insert-right-twist-1",
          alphabet = "R U",
          goal = "the DFR corner is home and untwisted",
          preserves = "cross; corners DLF, DBL, DRB",
          setup = "R U' R'",
          sequence = "R U R'",
          length = 3 } ::
        { name = "corner-insert-right-twist-2",
          alphabet = "R U",
          goal = "the DFR corner is home and untwisted",
          preserves = "cross; corners DLF, DBL, DRB",
          setup = "R U R' U'",
          sequence = "U R U' R'",
          length = 4 } ::
        Nil

    ///
    /// The routine of that name, if there is one.
    ///
    pub def named(name: String): Option[Routine] =
        all() |> List.findLeft(r -> r#name == name)
}
