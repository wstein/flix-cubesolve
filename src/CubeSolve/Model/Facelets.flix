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
pub mod CubeSolve.Model.Facelets {

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
    /// The rendering is of the *arrangement*. Odd cubes are read in the
    /// canonical pose, where the fixed centers are the frame. Even cubes are
    /// read in the framed pose, so a moved corner stays where the engine put
    /// it. The whole-cube orientation on `Cube` is separate and is not written
    /// into the token.
    ///
    pub def of(c: Cube): Result[String, Vector[Int32]] =
        CubeSolve.Model.Pieces.toFacelets(Cube.size(c), Cube.orbits(c))

    ///
    /// The cube those facelet colours describe.
    ///
    pub def toCube(n: Int32, fs: Vector[Int32]): Result[String, Cube] =
        CubeSolve.Model.Pieces.fromFacelets(n, fs) |> Result.flatMap(os -> Cube.ofOrbits(n, os))

    ///
    /// `c` as a canonical URL-safe token.
    ///
    /// Every failure in this repository reports one, so that a failing case can
    /// be replayed from the state rather than only from the seed that produced
    /// it.
    ///
    pub def token(c: Cube): Result[String, String] =
        CubeSolve.Model.Pieces.encode(Cube.size(c), Cube.orbits(c))

}
