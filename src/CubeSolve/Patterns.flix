///
/// The published patterns this project knows about, and how to recognise one.
///
/// One module per puzzle, because the corpora differ in more than their
/// contents. `CubeSolve.Patterns.Standard` holds 110 3x3x3 patterns and
/// `CubeSolve.Patterns.Pocket` 89 2x2x2 ones, each with its provenance,
/// the algorithm as published, and a canonical identity.
///
/// **The two identities are computed under different equivalence relations, and
/// substituting one for the other is wrong rather than approximate.** A 3x3x3's
/// fixed centres pin the frame, so two recordings of one pattern are related by
/// *conjugation*, and the identity is the smallest token over the 24
/// conjugations. A 2x2x2 has no centres and nothing pins the frame: turning it
/// in the hand moves pieces between slots, which is what a move does and is not
/// what conjugation does, so the relation is one-sided and the whole-cube
/// rotations really are pairs of moves -- `x` is `R L'`, `y` is `U D'`, `z` is
/// `F B'`. Using the 3x3x3 relation on the 2x2x2 was tried, and it called
/// distinct orientations distinct patterns while leaving four patterns with no
/// coordinate at all.
///
/// **This is reference data, not a solver.** Nothing in the solvers consults it,
/// and recognising a scramble as a known pattern does not shorten the answer
/// given for it. A caller who wants the published algorithm asks for it.
/// A state appears once per size-specific catalogue; alternate source
/// algorithms are provenance, not a reason to add a duplicate state record.
///
mod CubeSolve.Patterns {

    ///
    /// The URL a source id refers to, across both collections.
    ///
    /// Shared rather than repeated per puzzle: `speedsolving` is a source for
    /// both, and two copies of a URL are two things to get wrong.
    ///
    pub def url(id: String): String = match id {
        case "speedsolving" =>
            "https://www.speedsolving.com/wiki/index.php/List_of_pretty_patterns"
        case "ruwix1" =>
            "https://ruwix.com/the-rubiks-cube/rubiks-cube-patterns-algorithms/"
        case "ruwix2" =>
            "https://ruwix.com/the-rubiks-cube/rubiks-cube-patterns-algorithms/"
                + "more-rubiks-patterns/"
        case "randelshofer" =>
            "https://www.randelshofer.ch/rubik/patterns_pocket.html"
        case "kewbz3" =>
            "https://kewbz.co.uk/blogs/solutions-guides/cool-3x3-rubiks-cube-patterns"
        case "kewbz4" =>
            "https://kewbz.co.uk/blogs/solutions-guides/4x4-patterns"
        case "kewbz5" =>
            "https://kewbz.co.uk/blogs/solutions-guides/5x5-patterns"
        case _ => "unknown"
    }

}
