///
/// A solving and scrambling engine for NxNxN twisty cubes.
///
/// Everything this package defines nests under `CubeSolve`, and the package
/// declares no top-level `main`. Both are deliberate: a library that leaks a
/// name into the root namespace collides with every consumer that does the
/// same, and a program may have only one entry point, so a library that ships
/// one cannot be depended on. Any command line lives in `CubeSolve.Cli`.
///
/// The engine is layered, and the layers are kept apart on purpose:
///
/// ```
/// CubeSolve.Model      pieces, moves, validation, sampling
/// CubeSolve.Table      packed lookup tables behind one read handle
/// CubeSolve.Solve      IDA*, phases, per-size solvers
/// CubeSolve.Scramble   random-state scrambling, over Solve's public API
/// ```
///
/// `CubeSolve.Model` is the representation you would read off a physical cube:
/// which piece sits in which slot, and how it is turned. `CubeSolve.Table` and
/// `CubeSolve.Solve` work in scalar integer coordinates instead, because a
/// search that must do tens of millions of successor steps cannot afford to
/// touch a vector. Converting between the two is explicit, and every
/// phase boundary is checked against the *model*, never against the
/// coordinate the search just wrote -- a search bug that corrupts a coordinate
/// would otherwise validate itself.
///
mod CubeSolve {

    ///
    /// The cube sizes this engine implements, in full.
    ///
    /// This says what works, not what is intended. Callers branch on it, so a
    /// size appears here only once every layer -- model, moves, tables and
    /// search -- can handle it. The 4x4x4 and 5x5x5 are the project's goal and
    /// reduce to the 3x3x3, but their wing and centre orbits have no move
    /// tables yet, so listing them would be a promise the engine cannot keep.
    ///
    /// The floor is the 2x2x2 because a 1x1x1 has nothing to permute.
    /// `Orbit64.Orbit.layout` keeps answering below and above this range, but
    /// nothing here would know what to do with the answer.
    ///
    pub def supportedSizes(): Vector[Int32] = Vector#{2, 3}

    ///
    /// The slot and move numbering every table in this engine is built under.
    ///
    /// Carried in the header of every cached table and checked when one is
    /// read. A cube table stores ordinals and no geometry, so relabelling slots
    /// by any bijection preserves every invariant and changes only the
    /// encoding: a table from a different numbering is not stale, it is a table
    /// of a different puzzle. **Change this string whenever
    /// `docs/conventions.md` changes**, so that older caches are rejected
    /// rather than misread.
    ///
    pub def convention(): String = "kociemba-htm@1"

    ///
    /// Which build wrote a table, recorded as provenance.
    ///
    /// Not checked when a cache is read: a table built by an older build of the
    /// same code, under the same convention, is still that table.
    ///
    pub def generator(): String = "cubesolve 0.1.0"

    ///
    /// Whether this engine implements an `n x n x n`.
    ///
    pub def supports(n: Int32): Bool = Vector.memberOf(n, supportedSizes())

}
