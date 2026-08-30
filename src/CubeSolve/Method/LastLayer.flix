///
/// What is solved and what is oriented, read off the model.
///
/// The two questions the last-layer methods ask before they claim anything.
/// They are here rather than in either method because **the goal of one step is
/// the precondition of the next**: OLL finishes when the first two layers are
/// solved and the last layer is oriented, and that is exactly when PLL may
/// begin. Writing that twice would let the two drift, and a method that
/// disagreed with its neighbour about when it had finished would be very hard
/// to see.
///
/// Both are decided from decoded model state -- which piece sits in which slot,
/// and which way round. Asking a search coordinate would be the wrong layer, and
/// asking the facelets would be a slower way to ask the same thing.
///
mod CubeSolve.Method.LastLayer {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face.U
    use CubeSolve.Model.Move.Move.Turn
    use CubeSolve.Model.Rotation
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The slots a 3x3x3's last layer occupies.
    ///
    /// Corners `URF UFL ULB UBR` and edges `UR UF UL UB` are the first four of
    /// each orbit, so everything from four onward is below the top. See
    /// `docs/conventions.md`.
    ///
    def lastLayerSlots(): Int32 = 4

    ///
    /// Why `c` is not a 3x3x3 with its first two layers solved, if it is not.
    ///
    pub def faultBelowTheTop(c: Cube.Cube): Option[String] =
        if (Cube.size(c) != 3)
            Some("this is a step of the 3x3x3 method, and this is a "
                + "${Cube.size(c)}x${Cube.size(c)}x${Cube.size(c)}")
        else
            match Cube.orbits(c) {
                case CornerCoord(cp, co) :: MidgeCoord(ep, eo) :: Nil =>
                    if (not settled(lastLayerSlots(), 8, cp, co))
                        Some("the first two layers are not solved: a bottom corner "
                            + "is out of place or twisted")
                    else if (not settled(lastLayerSlots(), 12, ep, eo))
                        Some("the first two layers are not solved: a bottom or "
                            + "middle edge is out of place or flipped")
                    else
                        None
                case _ => Some("this cube does not have the orbits a 3x3x3 has")
            }

    ///
    /// Whether every piece of `c`'s last layer shows the top colour.
    ///
    /// Orientation only. Where those pieces sit is what the next step is for.
    ///
    pub def topIsOriented(c: Cube.Cube): Bool =
        match Cube.orbits(c) {
            case CornerCoord(_, co) :: MidgeCoord(_, eo) :: Nil =>
                unturned(0, lastLayerSlots(), co) and unturned(0, lastLayerSlots(), eo)
            case _ => false
        }

    ///
    /// `k` quarter turns of the layer that started on top, written for a cube
    /// now held at `orientation`.
    ///
    /// Most published algorithms put the cube back the way they found it and
    /// this comes out as a plain `U` turn. Some do not -- an algorithm with an
    /// `x` and no `x'` ends with the cube on its side -- and then the layer the
    /// turn is about is no longer uppermost, so the turn is named for the face
    /// it is actually on. Writing `U` there would turn the wrong face.
    ///
    pub def topTurnWritten(k: Int32, orientation: Rotation.Rotation): String =
        if (Int32.modulo(k, 4) == 0)
            ""
        else
            Move.show(Rotation.reframe(Turn(U, k), Rotation.inverse(orientation)))

    ///
    /// Whether every slot from `start` up to `stop` holds its own piece the
    /// right way round.
    ///
    def settled(
        start: Int32,
        stop: Int32,
        perm: Vector[Int32],
        ori: Vector[Int32]
    ): Bool =
        Vector.range(start, stop) |> Vector.forAll(i ->
            Vector.get(i, perm) == i and Vector.get(i, ori) == 0)

    ///
    /// Whether every orientation from `start` up to `stop` is zero.
    ///
    def unturned(start: Int32, stop: Int32, ori: Vector[Int32]): Bool =
        Vector.range(start, stop) |> Vector.forAll(i -> Vector.get(i, ori) == 0)

}
