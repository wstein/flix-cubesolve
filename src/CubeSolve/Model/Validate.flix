///
/// Whether a cube is one that turning can reach.
///
/// There are two different questions here, and conflating them is a known way
/// to get a solver that runs forever on an input it should have refused:
///
/// - **Is this a cube at all?** Are the permutations permutations, are the
///   twists in range, do the orientations sum as they must. That is
///   `Orbit64.Coord.faultOf`, and this module defers to it rather than
///   restating it.
/// - **Is this reachable by turning?** Everything above can hold of a cube that
///   no sequence of turns produces -- a physical cube taken apart and
///   reassembled is the usual way to make one.
///
/// The second question has a different answer at every size, which is why it
/// cannot live in the codec. The coupled corner/edge permutation parity is a
/// **3x3x3** rule and applying it generally is a classic error: a 2x2x2 has no
/// such constraint, and a 4x4x4's wing permutation is unconstrained relative to
/// its corners, which is why OLL and PLL parity exist at all.
///
mod CubeSolve.Model.Validate {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Cube.Cube
    use Orbit64.Coord.Coord
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The first rule `c` breaks, or nothing when turning can reach it.
    ///
    /// The reason is a sentence naming the rule, never a bare `None` and never
    /// a coordinate: a caller that assembled a cube wrongly needs to know which
    /// rule it broke, and "state 1082564 is invalid" tells it nothing.
    ///
    pub def faultOf(c: Cube): Option[String] =
        match List.filterMap(Orbit64.Coord.faultOf, Cube.orbits(c)) {
            case why :: _ => Some(why)
            case Nil      => reachabilityFaultOf(c)
        }

    ///
    /// Whether turning can reach `c`.
    ///
    pub def isReachable(c: Cube): Bool = Option.isEmpty(faultOf(c))

    ///
    /// The reachability rule `c` breaks, given that it is a cube at all.
    ///
    /// A size whose invariants this engine has not derived is refused rather
    /// than passed. Reporting no fault would assert that the cube is reachable,
    /// which is a claim the engine cannot make: a 5x5x5 has per-orbit
    /// invariants beyond the ones the codec checks.
    ///
    def reachabilityFaultOf(c: Cube): Option[String] =
        let n = Cube.size(c);
        if (n == 2)
            // Every face turn is a 4-cycle of corners, which is an odd
            // permutation, and there is no second orbit to pair it against. So
            // every corner permutation is reachable and the twist sum -- which
            // the codec already checked -- is the only constraint.
            None
        else if (n == 3)
            parityFaultOf(Cube.orbits(c))
        else
            Some("whether a ${n}x${n}x${n} is reachable is not implemented: this "
                + "engine derives reachability invariants for the 2x2x2 and 3x3x3 "
                + "only, and reporting no fault would claim more than it knows")

    ///
    /// The 3x3x3 coupling: corner and edge permutations have the same parity.
    ///
    /// Every face turn is a 4-cycle on corners *and* a 4-cycle on edges, and a
    /// 4-cycle is odd, so a turn flips both parities at once. No sequence of
    /// turns can separate them. Exchanging two corners and nothing else is the
    /// canonical unreachable cube.
    ///
    def parityFaultOf(orbits: List[Coord]): Option[String] =
        match orbits {
            case CornerCoord(cp, _) :: MidgeCoord(ep, _) :: Nil =>
                if (parityOf(cp) == parityOf(ep))
                    None
                else
                    Some("the corner and edge permutations have opposite parity, "
                        + "which no sequence of turns can produce: every face turn "
                        + "is a 4-cycle of each, so it changes both parities "
                        + "together")
            case _ => Some("a 3x3x3 has a corner orbit and a midge orbit, in that order")
        }

    ///
    /// The parity of `p`: `0` when it is an even permutation, `1` when odd.
    ///
    /// Counted as inversions, which is `O(n^2)` and entirely adequate for the
    /// twelve entries this is ever asked about.
    ///
    def parityOf(p: Vector[Int32]): Int32 =
        let n = Vector.length(p);
        let inversions =
            Vector.range(0, n) |> Vector.map(i ->
                Vector.range(i + 1, n)
                    |> Vector.count(j -> Vector.get(i, p) > Vector.get(j, p)))
                |> Vector.sum;
        Int32.modulo(inversions, 2)

}
