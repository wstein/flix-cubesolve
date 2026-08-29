///
/// Reading and writing a cube as facelet colours and as a token.
///
/// Kept apart from `CubeSolve.Model.Cube` because it is a different concern:
/// `Cube` is what a state *is* and what turning does to it, and this is how it
/// is exchanged with anything outside the engine. Both are thin wrappers over
/// `flix-orbit64`, whose facelet tables and codec share no code with the move
/// tables here -- which is what makes agreement between them a second
/// derivation rather than a restatement.
///
mod CubeSolve.Model.Facelets {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Cube.Cube

    ///
    /// `c` as facelet colours, or why it cannot be drawn.
    ///
    /// Delegates to `flix-orbit64`, whose facelet tables share no code with the
    /// move tables here. Agreement between the two is therefore a second
    /// derivation rather than a restatement, and it is what pins turn
    /// *direction* -- a table with every cycle reversed satisfies every group
    /// law and fails here.
    ///
    /// The rendering is of the *arrangement*, in the canonical frame -- the
    /// cube as it would look rotated back upright. The frame itself is reported
    /// by `orientation`, which is the only place it lives. Splitting the two is
    /// not a shortcut: orbit64's own format excludes the fixed centres for
    /// exactly this reason, so "arrangement plus frame" is the whole state.
    ///
    pub def of(c: Cube): Result[String, Vector[Int32]] =
        Orbit64.Net.toFacelets(Cube.size(c), Cube.orbits(c))

    ///
    /// The cube those facelet colours describe.
    ///
    pub def toCube(n: Int32, fs: Vector[Int32]): Result[String, Cube] =
        Orbit64.Net.fromFacelets(n, fs) |> Result.flatMap(os -> Cube.ofOrbits(n, os))

    ///
    /// `c` as a canonical URL-safe token.
    ///
    /// Every failure in this repository reports one, so that a failing case can
    /// be replayed from the state rather than only from the seed that produced
    /// it.
    ///
    pub def token(c: Cube): Result[String, String] =
        Orbit64.encode(Cube.size(c), Cube.orbits(c))

}
