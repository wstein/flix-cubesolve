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
    /// The cube sizes this engine solves.
    ///
    /// The floor is the 2x2x2 because a 1x1x1 has nothing to permute. The
    /// ceiling is the 5x5x5 because that is the largest size for which a
    /// reduction is implemented; `Orbit64.Orbit.layout` keeps answering above
    /// it, but nothing here would know what to do with the answer.
    ///
    pub def supportedSizes(): Vector[Int32] = Vector#{2, 3, 4, 5}

    ///
    /// Whether this engine can solve an `n x n x n`.
    ///
    pub def supports(n: Int32): Bool = Vector.memberOf(n, supportedSizes())

}
