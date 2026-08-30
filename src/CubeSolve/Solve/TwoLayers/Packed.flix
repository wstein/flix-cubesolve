///
/// Three coordinates in one machine integer.
///
/// The first two layers are tracked by three separate numberings and the search
/// carries all of them at once. Their product -- 190,080 by 136,080 by 190,080,
/// about 4.9 x 10^15 -- does not fit an `Int32` and does fit an `Int64`, and
/// `CubeSolve.Solve.IdaStar` is generic in state width, so carrying them packed
/// costs nothing.
///
/// Kept apart from the search so the arithmetic can be read, and changed,
/// without the phase definition in the way.
///
mod CubeSolve.Solve.TwoLayers.Packed {

    use CubeSolve.Table.FirstLayer
    use CubeSolve.Table.MiddleEdges

    ///
    /// Three coordinates in one machine integer.
    ///
    pub def pack(cross: Int32, corners: Int32, middles: Int32): Int64 =
        (Int32.toInt64(cross) * Int32.toInt64(FirstLayer.stateCount())
            + Int32.toInt64(corners)) * Int32.toInt64(MiddleEdges.stateCount())
            + Int32.toInt64(middles)

    ///
    /// The middle-edge part of a packed triple.
    ///
    pub def middlesOf(s: Int64): Int32 =
        narrow(Int64.modulo(s, Int32.toInt64(MiddleEdges.stateCount())))

    ///
    /// The corner part of a packed triple.
    ///
    pub def cornersOf(s: Int64): Int32 =
        narrow(Int64.modulo(s / Int32.toInt64(MiddleEdges.stateCount()),
            Int32.toInt64(FirstLayer.stateCount())))

    ///
    /// The cross part of a packed triple.
    ///
    pub def crossOf(s: Int64): Int32 =
        narrow(s / (Int32.toInt64(MiddleEdges.stateCount())
            * Int32.toInt64(FirstLayer.stateCount())))

    ///
    /// An `Int64` that is known to fit, narrowed.
    ///
    def narrow(x: Int64): Int32 = Int64.tryToInt32(x) |> Option.getWithDefault(0)

}
