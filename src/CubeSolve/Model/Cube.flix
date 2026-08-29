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
    use CubeSolve.Model.Notation
    use CubeSolve.Model.Notation.Op.{Layer, Frame}
    use CubeSolve.Model.Orbits
    use CubeSolve.Model.Rotation
    use CubeSolve.Model.Stickers
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
        case Cube(Int32, Rotation.Rotation, List[Coord])
    }

    ///
    /// The number of layers: `3` for a 3x3x3.
    ///
    pub def size(c: Cube): Int32 = let Cube(n, _, _) = c; n

    ///
    /// The whole-cube rotation `c` has undergone, relative to the canonical
    /// frame in which its `orbits` are stated.
    ///
    /// The orbit coordinates always describe the cube as it would look rotated
    /// back to canonical, so this is the only record of how it is actually
    /// sitting -- and it is what a layer turn is resolved through, and what a
    /// solution is re-expressed with.
    ///
    pub def orientation(c: Cube): Rotation.Rotation = let Cube(_, o, _) = c; o

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
            Err(noSuchSize(n))
        else
            Ok(Cube(n, Rotation.identity(), Orbit64.solved(n)))

    ///
    /// What to say about a size with nothing to permute.
    ///
    def noSuchSize(n: Int32): String =
        "there is no ${n}x${n}x${n}: the smallest cube with anything to "
            + "permute is the 2x2x2"

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
            Err(noSuchSize(n))
        else if (List.map(Orbit64.Coord.kind, orbits) != expected)
            Err("a ${n}x${n}x${n} has the orbits ${expected}, but these are "
                + "${List.map(Orbit64.Coord.kind, orbits)}")
        else
            match List.filterMap(Orbit64.Coord.faultOf, orbits) {
                case why :: _ => Err(why)
                case Nil      => Ok(Cube(n, Rotation.identity(), orbits))
            }

    ///
    /// Whether `c` is solved: every piece with its neighbours, every orbit at
    /// its identity.
    ///
    /// The frame is deliberately not part of this. A solved cube held at an
    /// angle is still solved -- no piece has moved relative to any other -- and
    /// a solver that insisted otherwise would demand rotations at the end of
    /// every solution.
    ///
    pub def isSolved(c: Cube): Bool = orbits(c) == Orbit64.solved(size(c))

    // ---------- turning ----------

    ///
    /// `c` after the move `m`, or why the move could not be applied.
    ///
    /// Every size turns. The 2x2x2 and 3x3x3 go through per-orbit move tables
    /// and everything larger through the sticker geometry, for the reasons the
    /// two functions below give. A caller cannot tell which was used except by
    /// timing it.
    ///
    pub def apply(m: Move.Move, c: Cube): Result[String, Cube] =
        let inFrame = Rotation.reframe(m, orientation(c));
        let f = Move.face(inFrame);
        let k = Move.amount(inFrame);
        if (size(c) <= 3) byOrbitTable(f, k, c) else byFacelets(f, k, c)

    ///
    /// A turn applied through the per-orbit move tables.
    ///
    /// The path the 2x2x2 and 3x3x3 take. These are the sizes the search layer
    /// works in, and its coordinate tables are built from the same
    /// `Move.cornerPermutation` and `Move.edgePermutation` this uses, so model
    /// and search cannot disagree about what a move does.
    ///
    def byOrbitTable(f: Face, k: Int32, c: Cube): Result[String, Cube] =
        orbits(c)
            |> Result.traverse(o -> Orbits.turn(size(c), f, k, o))
            |> Result.map(os -> Cube(size(c), orientation(c), os))

    ///
    /// A turn applied through the facelets.
    ///
    /// The path everything larger takes. A 4x4x4 has wing and centre orbits with
    /// no move tables here, and writing four more tables per orbit is work the
    /// geometry does not need: a face turn spins one face and cycles four strips
    /// whatever the size. `CubeSolve.Model.Stickers` does it and says how.
    ///
    def byFacelets(f: Face, k: Int32, c: Cube): Result[String, Cube] =
        Stickers.turnOrbits(size(c), Move.faceIndex(f), k, orbits(c))
            |> Result.map(os -> Cube(size(c), orientation(c), os))

    ///
    /// `c` rotated bodily by `r`. No piece moves relative to any other.
    ///
    pub def rotate(r: Rotation.Rotation, c: Cube): Cube =
        Cube(size(c), Rotation.andThen(orientation(c), r), orbits(c))

    ///
    /// `c` after one step of a written sequence.
    ///
    pub def applyOp(op: Notation.Op, c: Cube): Result[String, Cube] = match op {
        case Layer(m) => apply(m, c)
        case Frame(r) => Ok(rotate(r, c))
    }

    ///
    /// `c` after every move of `ms`, in order.
    ///
    pub def applyAll(ms: List[Move.Move], c: Cube): Result[String, Cube] =
        let step = (acc, m) -> Result.flatMap(x -> apply(m, x), acc);
        List.foldLeft(step, Ok(c), ms)

    ///
    /// `c` after the moves `notation` names, or why it names none.
    ///
    /// Accepts the full written alphabet -- face turns, slice moves, whole-cube
    /// rotations and wide turns -- not only the eighteen face turns a search
    /// works in. See `CubeSolve.Model.Notation`.
    ///
    pub def applyNotation(notation: String, c: Cube): Result[String, Cube] =
        let step = (acc, op) -> Result.flatMap(x -> applyOp(op, x), acc);
        Notation.parse(size(c), notation)
            |> Result.flatMap(ops -> List.foldLeft(step, Ok(c), ops))

    ///
    /// `ms`, named in `c`'s current frame, renamed into the frame `c` started in.
    ///
    /// A solver works in the canonical frame, so its answer is a sequence of
    /// canonical face turns. If the caller's scramble contained a rotation, the
    /// faces they can reach are named differently, and handing back the
    /// canonical names would tell them to turn the wrong side of the cube.
    ///
    pub def reframeSolution(ms: List[Move.Move], c: Cube): List[Move.Move] =
        ms |> List.map(m -> Rotation.reframe(m, orientation(c)))




    ///
    /// `c` as it would be recorded from a frame turned by `r`.
    ///
    /// Not the same as `rotate`, and the difference is the whole point.
    /// `rotate` says the cube is being held differently and leaves the
    /// coordinates alone. This *re-records* the same arrangement against
    /// rotated slots, so the coordinates change while the cube does not.
    ///
    /// It is what lets one solver look at the cube along three different axes.
    /// The 3x3x3's phase one aims at the `U`/`D` axis specifically, and its
    /// Flip coordinate is defined against that axis -- a cube with every edge
    /// oriented in the `U`/`D` sense need not be oriented in the `F`/`B` sense.
    /// So conjugating by a rotation that carries another axis onto `U`/`D` lets
    /// the same tables aim at it, and a scramble awkward for one axis is often
    /// easy for another.
    ///
    /// This is a conjugation in the group sense -- `r' . c . r` -- rather than
    /// a hand-derived relabelling. Deriving the orientation bookkeeping
    /// geometrically is where this went wrong the first time: it produced a
    /// rotated solved cube that read as twisted, which cannot be right. Written
    /// as a composition, a solved cube stays solved because the identity is
    /// conjugate only to itself, and nothing has to be argued.
    ///
    pub def conjugate(r: Rotation.Rotation, c: Cube): Result[String, Cube] =
        forM (
            turned <- asState(size(c), r);
            left <- after(turned, c);
            back <- inverse(turned);
            both <- after(left, back)
        ) yield both

    ///
    /// The state a solved cube is in after being turned bodily by `r`.
    ///
    /// A rotation is not a move, but its effect on the pieces can be written as
    /// one, and that is what makes it composable with states.
    ///
    def asState(n: Int32, r: Rotation.Rotation): Result[String, Cube] =
        if (n > 3)
            // There are wing and centre orbits to fill and no rotation tables
            // for them. Returning a two-orbit cube anyway is what this used to
            // do, and `after` then zipped it against a three-orbit cube and
            // silently dropped the last orbit.
            Err(Orbits.centresDoNotCompose())
        else
            let corners =
                CornerCoord(Rotation.cornerPermutation(r), Rotation.cornerTwist(r));
            let midges = MidgeCoord(Rotation.edgePermutation(r), Rotation.edgeFlip(r));
            let os = if (n == 2) corners :: Nil else corners :: midges :: Nil;
            Ok(Cube(n, Rotation.identity(), os))

    ///
    /// `first`, and then `second`.
    ///
    /// Cubie multiplication: the piece at slot `i` afterwards is whatever
    /// `first` had at the slot `second` draws that slot from, and it carries
    /// both orientations.
    ///
    pub def after(first: Cube, second: Cube): Result[String, Cube] =
        // Checked rather than left to `List.zip`, which truncates to the shorter
        // list: two cubes with different orbits would otherwise compose into one
        // missing an orbit, which is a wrong cube rather than a refusal.
        if (List.length(orbits(first)) != List.length(orbits(second)))
            Err("these two cubes do not have the same orbits, so they do not "
                + "compose: ${size(first)}x${size(first)}x${size(first)} against "
                + "${size(second)}x${size(second)}x${size(second)}")
        else
            List.zip(orbits(first), orbits(second))
                |> Result.traverse(Orbits.afterOrbit)
                |> Result.map(os -> Cube(size(first), orientation(first), os))




    ///
    /// The state that undoes `c`.
    ///
    /// If `c` is what a scramble produced, this is what its inverse would
    /// produce. The two are equally far from solved -- inversion is a symmetry
    /// of the cube group -- but a *two-phase* search does not treat them alike,
    /// because phase one aims at a particular subgroup and the two states sit
    /// differently with respect to it. Searching both and keeping the shorter
    /// answer is a real refinement rather than a restatement.
    ///
    pub def inverse(c: Cube): Result[String, Cube] =
        orbits(c)
            |> Result.traverse(Orbits.invertOrbit)
            |> Result.map(os -> Cube(size(c), orientation(c), os))

}
