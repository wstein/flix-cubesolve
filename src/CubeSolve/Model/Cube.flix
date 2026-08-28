///
/// Cube state as you would read it off a physical cube.
///
/// This is the *model* representation: which piece sits in which slot, and how
/// it is turned. It is the one the validator, the tests, the facelet
/// interchange and every phase boundary speak. The search does not use it --
/// see `CubeSolve.Table` and `CubeSolve.Solve`, which work in scalar integer
/// coordinates because a search cannot afford to touch a vector.
///
/// Keeping the two apart is deliberate. An integer coordinate cannot say why it
/// is invalid, and a search bug that corrupts a coordinate would validate
/// itself if the coordinate were asked. So legality is always decided here.
///
mod CubeSolve.Model.Cube {

    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face
    use CubeSolve.Model.Move.Move.Turn
    use Orbit64.Coord.Coord
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord, WingCoord, CenterCoord}

    ///
    /// An `n x n x n` in a known frame.
    ///
    /// `orbits` is in `Orbit64.Orbit.layout` order, which is the order the
    /// codec packs them and the only thing that tells two centre orbits apart.
    ///
    /// `orientation` is the whole-cube rotation this state is expressed in, one
    /// of 24, with `0` being U on top and F in front. `flix-orbit64` has no such
    /// field -- it excludes an odd cube's fixed centres because they define the
    /// frame rather than carrying state, and its `fromFacelets` refuses a cube
    /// whose fixed centres have moved. A codec may refuse those. A solver may
    /// not: `M`, `E`, `S`, `x`, `y`, `z` and the wide turns in WCA 4x4x4 and
    /// 5x5x5 scrambles all move centres relative to the frame. Carrying the
    /// rotation here is what lets the boundary normalise, solve, and re-express
    /// the answer in the frame the caller used.
    ///
    pub enum Cube with Eq, ToString {
        case Cube(Int32, Int32, List[Coord])
    }

    ///
    /// The number of layers: `3` for a 3x3x3.
    ///
    pub def size(c: Cube): Int32 = let Cube(n, _, _) = c; n

    ///
    /// The whole-cube rotation `c` is expressed in, one of 24. `0` is canonical.
    ///
    pub def orientation(c: Cube): Int32 = let Cube(_, o, _) = c; o

    ///
    /// The orbit coordinates, in `Orbit64.Orbit.layout` order.
    ///
    pub def orbits(c: Cube): List[Coord] = let Cube(_, _, os) = c; os

    ///
    /// A solved `n x n x n` in the canonical frame.
    ///
    /// Refuses anything below a 2x2x2: a 1x1x1 is one cubie with nothing to
    /// permute, and there is no 0x0x0. Without that floor the orbit arithmetic
    /// keeps answering anyway, and answers wrongly.
    ///
    pub def solved(n: Int32): Result[String, Cube] =
        if (n < 2)
            Err("there is no ${n}x${n}x${n}: the smallest cube with anything to permute is the 2x2x2")
        else
            Ok(Cube(n, 0, Orbit64.solved(n)))

    ///
    /// The cube `orbits` describes, or the first rule it breaks.
    ///
    /// Checks two things the type cannot: that each coordinate is a state a
    /// cube can be in, and that the orbits are the ones an `n x n x n` has, in
    /// layout order. The second matters because the orbit list is positional --
    /// a 5x5x5's two centre orbits are told apart by nothing else.
    ///
    pub def ofOrbits(n: Int32, orbits: List[Coord]): Result[String, Cube] =
        let expected = Orbit64.Orbit.layout(n);
        if (List.isEmpty(expected))
            Err("there is no ${n}x${n}x${n}: the smallest cube with anything to permute is the 2x2x2")
        else if (List.map(Orbit64.Coord.kind, orbits) != expected)
            Err("a ${n}x${n}x${n} has the orbits ${expected}, but these are "
                + "${List.map(Orbit64.Coord.kind, orbits)}")
        else
            match List.filterMap(Orbit64.Coord.faultOf, orbits) {
                case why :: _ => Err(why)
                case Nil      => Ok(Cube(n, 0, orbits))
            }

    ///
    /// Whether `c` is solved: every orbit at its identity, in the canonical frame.
    ///
    pub def isSolved(c: Cube): Bool =
        orientation(c) == 0 and orbits(c) == Orbit64.solved(size(c))

    // ---------- turning ----------

    ///
    /// `c` after the move `m`, or why the move could not be applied.
    ///
    /// The refusal is by size rather than by orbit kind, because "this engine
    /// cannot turn a 4x4x4 yet" is what the caller can act on, and "there is no
    /// move table for the Wings orbit" is not.
    ///
    pub def apply(m: Move.Move, c: Cube): Result[String, Cube] =
        let f = Move.face(m);
        let k = Move.amount(m);
        orbits(c)
            |> Result.traverse(o -> turn(size(c), f, k, o))
            |> Result.map(os -> Cube(size(c), orientation(c), os))

    ///
    /// `c` after every move of `ms`, in order.
    ///
    pub def applyAll(ms: List[Move.Move], c: Cube): Result[String, Cube] =
        List.foldLeft((acc, m) -> Result.flatMap(x -> apply(m, x), acc), Ok(c), ms)

    ///
    /// `c` after the moves `notation` names, or why it names none.
    ///
    pub def applyNotation(notation: String, c: Cube): Result[String, Cube] =
        Move.parse(notation) |> Result.flatMap(ms -> applyAll(ms, c))

    ///
    /// One orbit after `k` clockwise quarter turns of `f`.
    ///
    def turn(n: Int32, f: Face, k: Int32, o: Coord): Result[String, Coord] = match o {
        case CornerCoord(p, t) =>
            let (p1, t1) = repeatTurn(k, (p, t), turnCorners(f));
            Ok(CornerCoord(p1, t1))
        case MidgeCoord(p, t) =>
            let (p1, t1) = repeatTurn(k, (p, t), turnMidges(f));
            Ok(MidgeCoord(p1, t1))
        case _ =>
            Err("turning a ${n}x${n}x${n} is not implemented: this engine has move "
                + "tables for the corner and midge orbits, so for the 2x2x2 and 3x3x3")
    }

    ///
    /// `step` applied `k` times to `s`.
    ///
    def repeatTurn(
        k: Int32,
        s: (Vector[Int32], Vector[Int32]),
        step: ((Vector[Int32], Vector[Int32])) -> (Vector[Int32], Vector[Int32])
    ): (Vector[Int32], Vector[Int32]) =
        if (k <= 0) s else repeatTurn(k - 1, step(s), step)

    ///
    /// One clockwise quarter turn of `f`, on the corner orbit.
    ///
    /// Slot-indexed throughout: the new occupant of slot `i` is whatever sat in
    /// slot `perm[i]`, and it arrives carrying that slot's orientation plus the
    /// twist the turn imposes.
    ///
    def turnCorners(f: Face): ((Vector[Int32], Vector[Int32])) -> (Vector[Int32], Vector[Int32]) =
        let perm = Move.cornerPermutation(f);
        let delta = Move.cornerTwist(f);
        match (p, t) ->
            ( Vector.init(i -> Vector.get(Vector.get(i, perm), p), 8)
            , Vector.init(i ->
                Int32.modulo(Vector.get(Vector.get(i, perm), t) + Vector.get(i, delta), 3), 8)
            )

    ///
    /// One clockwise quarter turn of `f`, on the midge orbit.
    ///
    def turnMidges(f: Face): ((Vector[Int32], Vector[Int32])) -> (Vector[Int32], Vector[Int32]) =
        let perm = Move.edgePermutation(f);
        let delta = Move.edgeFlip(f);
        match (p, t) ->
            ( Vector.init(i -> Vector.get(Vector.get(i, perm), p), 12)
            , Vector.init(i ->
                Int32.modulo(Vector.get(Vector.get(i, perm), t) + Vector.get(i, delta), 2), 12)
            )

    // ---------- interchange ----------

    ///
    /// `c` as facelet colours, or why it cannot be drawn.
    ///
    /// Delegates to `flix-orbit64`, whose facelet tables share no code with the
    /// move tables here. Agreement between the two is therefore a second
    /// derivation rather than a restatement, and it is what pins turn
    /// *direction* -- a table with every cycle reversed satisfies every group
    /// law and fails here.
    ///
    pub def facelets(c: Cube): Result[String, Vector[Int32]] =
        Orbit64.Net.toFacelets(size(c), orbits(c))

    ///
    /// The cube those facelet colours describe.
    ///
    pub def ofFacelets(n: Int32, fs: Vector[Int32]): Result[String, Cube] =
        Orbit64.Net.fromFacelets(n, fs) |> Result.flatMap(os -> ofOrbits(n, os))

    ///
    /// `c` as a canonical URL-safe token.
    ///
    /// Every failure in this repository reports one, so that a failing case can
    /// be replayed from the state rather than only from the seed that produced
    /// it.
    ///
    pub def token(c: Cube): Result[String, String] =
        Orbit64.encode(size(c), orbits(c))

}
