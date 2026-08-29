///
/// One orbit at a time: turning it, composing two, inverting one.
///
/// The arithmetic a cube is made of, kept apart from the cube itself. Slots and
/// orientations are what these functions know; sizes, frames and notation are
/// not their business. `CubeSolve.Model.Cube` assembles them into states.
///
/// The split is the same one `CubeSolve.Model.Stickers` gets: a cube type that
/// also carried the permutation arithmetic, the sticker geometry and the facelet
/// interchange would be the module everything else reaches through.
///
mod CubeSolve.Model.Orbits {

    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Face
    use Orbit64.Coord.Coord
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord, WingCoord, CenterCoord}

    ///
    /// One orbit after `k` clockwise quarter turns of `f`.
    ///
    pub def turn(
        n: Int32,
        f: Face,
        k: Int32,
        o: Coord
    ): Result[String, Coord] = match o {
        case CornerCoord(p, t) =>
            let step = turnOriented(Move.cornerPermutation(f), Move.cornerTwist(f), 3);
            let (p1, t1) = repeatTurn(k, (p, t), step);
            Ok(CornerCoord(p1, t1))
        case MidgeCoord(p, t) =>
            let step = turnOriented(Move.edgePermutation(f), Move.edgeFlip(f), 2);
            let (p1, t1) = repeatTurn(k, (p, t), step);
            Ok(MidgeCoord(p1, t1))
        case _ => Err(noTableForThisOrbit(n))
    }

    ///
    /// Why an orbit with no move table cannot be turned here.
    ///
    def noTableForThisOrbit(n: Int32): String =
        "turning a ${n}x${n}x${n} orbit by table is not implemented: there are "
            + "move tables for the corner and midge orbits only. Larger cubes "
            + "turn through the stickers instead, which is what `Cube.apply` "
            + "does, so reaching here is a bug in `Cube.apply`"

    ///
    /// `step` applied `k` times to `s`.
    ///
    pub def repeatTurn(
        k: Int32,
        s: (Vector[Int32], Vector[Int32]),
        step: ((Vector[Int32], Vector[Int32])) -> (Vector[Int32], Vector[Int32])
    ): (Vector[Int32], Vector[Int32]) =
        if (k <= 0) s else repeatTurn(k - 1, step(s), step)

    ///
    /// One clockwise quarter turn on an orbit whose pieces carry orientation.
    ///
    /// Slot-indexed throughout: the new occupant of slot `i` is whatever sat in
    /// slot `perm[i]`, and it arrives carrying that slot's orientation plus the
    /// change the turn imposes.
    ///
    /// Corners and midges differ only in how many slots they have and in what
    /// their orientation counts modulo, so they share this rather than each
    /// carrying its own copy of the same two lines.
    ///
    pub def turnOriented(
        perm: Vector[Int32],
        delta: Vector[Int32],
        modulus: Int32
    ): ((Vector[Int32], Vector[Int32])) -> (Vector[Int32], Vector[Int32]) =
        let slots = Vector.length(perm);
        match (p, t) ->
            let moved = Vector.init(i -> Vector.get(Vector.get(i, perm), p), slots);
            let turned = Vector.init(i -> {
                let carried = Vector.get(Vector.get(i, perm), t);
                Int32.modulo(carried + Vector.get(i, delta), modulus)
            }, slots);
            (moved, turned)

    ///
    /// One orbit of a composition.
    ///
    pub def afterOrbit(pair: (Coord, Coord)): Result[String, Coord] = match pair {
        case (CornerCoord(pa, oa), CornerCoord(pb, ob)) =>
            let (p, o) = combine(pa, oa, pb, ob, 3);
            Ok(CornerCoord(p, o))
        case (MidgeCoord(pa, oa), MidgeCoord(pb, ob)) =>
            let (p, o) = combine(pa, oa, pb, ob, 2);
            Ok(MidgeCoord(p, o))
        case (WingCoord(pa), WingCoord(pb)) =>
            Ok(WingCoord(Vector.map(i -> Vector.get(i, pa), pb)))
        case (CenterCoord(_), CenterCoord(_)) => Err(centresDoNotCompose())
        case _ => Err("these two cubes do not have the same orbits")
    }

    ///
    /// The permutation and orientation of a composition.
    ///
    pub def combine(
        pa: Vector[Int32],
        oa: Vector[Int32],
        pb: Vector[Int32],
        ob: Vector[Int32],
        modulus: Int32
    ): (Vector[Int32], Vector[Int32]) =
        let n = Vector.length(pa);
        let moved = Vector.init(i -> Vector.get(Vector.get(i, pb), pa), n);
        let turned = Vector.init(i -> {
            let carried = Vector.get(Vector.get(i, pb), oa);
            Int32.modulo(carried + Vector.get(i, ob), modulus)
        }, n);
        (moved, turned)

    ///
    /// One orbit, inverted.
    ///
    /// The piece in slot `i` goes home to slot `p[i]`, so the inverse sends
    /// `p[i]` to `i`. Its orientation goes with it and is negated: whatever
    /// twist it acquired on the way out it must lose on the way back.
    ///
    pub def invertOrbit(o: Coord): Result[String, Coord] = match o {
        case CornerCoord(p, t) =>
            let (q, u) = invertOriented(p, t, 3);
            Ok(CornerCoord(q, u))
        case MidgeCoord(p, t) =>
            let (q, u) = invertOriented(p, t, 2);
            Ok(MidgeCoord(q, u))
        case WingCoord(p)  => Ok(WingCoord(invertPermutation(p)))
        case CenterCoord(_) => Err(centresDoNotCompose())
    }

    ///
    /// A permutation and its orientations, inverted together.
    ///
    pub def invertOriented(
        p: Vector[Int32],
        t: Vector[Int32],
        modulus: Int32
    ): (Vector[Int32], Vector[Int32]) =
        let n = Vector.length(p);
        let inverted = invertPermutation(p);
        let twist = Vector.init(i -> {
            let came = Vector.get(i, inverted);
            Int32.modulo(modulus - Vector.get(came, t), modulus)
        }, n);
        (inverted, twist)

    ///
    /// The permutation that undoes `p`.
    ///
    pub def invertPermutation(p: Vector[Int32]): Vector[Int32] =
        let n = Vector.length(p);
        Vector.init(i -> Vector.indexOf(i, p) |> Option.getWithDefault(i), n)

    ///
    /// Why a cube with centre orbits cannot be composed with another.
    ///
    /// Centres are held as a multiset of colours rather than as a permutation of
    /// pieces, because the four centres of a face are interchangeable and
    /// pretending otherwise would make equal cubes compare unequal. The price is
    /// exactly this: composition needs to know where the right-hand state sent
    /// each slot, and a list of colours does not say. Nothing recovers it.
    ///
    /// So `after`, `inverse` and `conjugate` are defined for the 2x2x2 and the
    /// 3x3x3 and refuse anything larger. Turning is not affected -- a turn is
    /// geometry rather than composition, and goes through the stickers.
    ///
    pub def centresDoNotCompose(): String =
        "cubes with centre orbits do not compose: centres are a multiset of "
            + "colours, not a permutation of pieces, so nothing here can say "
            + "where the other cube sent each centre slot. Turning such a cube "
            + "works; composing, inverting and conjugating one does not"

}
