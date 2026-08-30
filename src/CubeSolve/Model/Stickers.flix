///
/// The cube as stickers, and what a face turn does to them.
///
/// **Index arithmetic, and the bridge to and from orbits.** `turn` knows no cube
/// type, no orbit and no move: it takes a vector of face colours laid out as
/// `face * n^2 + row * n + column` and returns another, which is why the
/// geometry can be tested by itself. `turnOrbits` wraps it in the unfold and
/// fold that `CubeSolve.Model.Cube` needs, and lives here rather than there so
/// that the cube type does not acquire the facelet interchange as well.
///
/// See `docs/conventions.md` for the layout: faces `U R F D L B` numbered 0 to
/// 5, cells row-major from each face's top-left as drawn in the unfolded net.
///
mod CubeSolve.Model.Stickers {

    use Orbit64.Coord.Coord

    ///
    /// `orbits` after `k` clockwise quarter turns of face `f`, by unfolding the
    /// cube, turning the stickers and folding it back.
    ///
    /// The path every size above the 3x3x3 takes. Folding back is where a bad
    /// turn is caught: `fromFacelets` rejects a sticker arrangement no cube can
    /// be in, so a wrong strip shows up as a refusal rather than as a plausible
    /// wrong answer.
    ///
    /// **Slow on purpose.** Two conversions per move is not what a search would
    /// pay, and no search calls it -- this is the model layer, where being right
    /// beats being quick.
    ///
    pub def turnOrbits(
        n: Int32,
        f: Int32,
        k: Int32,
        orbits: List[Coord]
    ): Result[String, List[Coord]] =
        forM (
            before <- Orbit64.Net.toFacelets(n, orbits);
            folded <- Orbit64.Net.fromFacelets(n, turn(n, f, k, before))
        ) yield folded

    /// `orbits` after turning an inner layer `depth` in from face `f`.
    ///
    /// Unlike an outer turn, an inner turn does not spin a face; it only cycles
    /// the four strips parallel to it. This is what a 4x4x4 `Rw` needs for its
    /// second layer and what an even-cube `M` uses for its two middle slices.
    pub def turnInnerOrbits(
        n: Int32,
        f: Int32,
        depth: Int32,
        k: Int32,
        orbits: List[Coord]
    ): Result[String, List[Coord]] =
        forM (
            before <- Orbit64.Net.toFacelets(n, orbits);
            folded <- Orbit64.Net.fromFacelets(n, turnInner(n, f, depth, k, before))
        ) yield folded

    ///
    /// `fs` after `k` clockwise quarter turns of face `f`.
    ///
    /// **Geometry, uniform in `n`.** A face turn rotates that face's own
    /// stickers and cycles four strips on its neighbours, and neither rule
    /// mentions the size. That is what makes this the way to turn a cube the
    /// orbit tables do not cover: the 2x2x2 and 3x3x3 have hand-written move
    /// tables per orbit, and the 4x4x4 and 5x5x5 have wing and centre orbits
    /// that would need their own. This needs none.
    ///
    /// It is slower than a table lookup and belongs to the model layer, which is
    /// where correctness beats speed. A search never calls it.
    ///
    /// Checked against the orbit tables on every 2x2x2 and 3x3x3 move, over
    /// random states, so the two derivations agree where both exist.
    ///
    pub def turn(n: Int32, f: Int32, k: Int32, fs: Vector[Int32]): Vector[Int32] =
        if (k <= 0) fs else turn(n, f, k - 1, quarterTurn(n, f, fs))

    /// `fs` after `k` quarter turns of the layer `depth` in from `f`.
    pub def turnInner(
        n: Int32,
        f: Int32,
        depth: Int32,
        k: Int32,
        fs: Vector[Int32]
    ): Vector[Int32] =
        if (k <= 0)
            fs
        else
            let stepped = quarterInner(n, f, depth, fs);
            turnInner(n, f, depth, k - 1, stepped)

    ///
    /// One clockwise quarter turn of face `f`.
    ///
    def quarterTurn(n: Int32, f: Int32, fs: Vector[Int32]): Vector[Int32] =
        let spun = spinFace(n, f, fs);
        cycleStrips(strips(n, f), spun)

    /// One turn of an inner layer: strips move, but no face itself spins.
    def quarterInner(n: Int32, f: Int32, depth: Int32, fs: Vector[Int32]): Vector[Int32] =
        cycleStrips(innerStrips(n, f, depth), fs)

    ///
    /// Face `f`'s own stickers, rotated a quarter turn clockwise.
    ///
    /// The cell at row `r`, column `c` is filled from row `n-1-c`, column `r`,
    /// which is the clockwise rotation of a square read row-major from its
    /// top-left.
    ///
    def spinFace(n: Int32, f: Int32, fs: Vector[Int32]): Vector[Int32] =
        Vector.range(0, Vector.length(fs)) |> Vector.map(i ->
            if (i / (n * n) != f)
                Vector.get(i, fs)
            else
                let cell = Int32.modulo(i, n * n);
                let r = cell / n;
                let c = Int32.modulo(cell, n);
                Vector.get(f * n * n + (n - 1 - c) * n + r, fs))

    ///
    /// Move each strip's stickers onto the next strip round.
    ///
    def cycleStrips(ss: List[List[Int32]], fs: Vector[Int32]): Vector[Int32] =
        let count = List.length(ss);
        let onward = i -> source ->
            List.zip(source, nthStrip(ss, Int32.modulo(i + 1, count)));
        let moves = ss
            |> List.mapWithIndex(onward)
            |> List.flatten
            |> List.map(p -> (snd(p), Vector.get(fst(p), fs)))
            |> List.toMap;
        Vector.range(0, Vector.length(fs)) |> Vector.map(i ->
            Map.getWithDefault(i, Vector.get(i, fs), moves))

    ///
    /// The `i`th strip, or nothing sensible if there is no such strip.
    ///
    def nthStrip(ss: List[List[Int32]], i: Int32): List[Int32] =
        List.nth(i, ss) |> Option.getWithDefault(Nil)

    ///
    /// The four strips a turn of `f` cycles, in the order they move.
    ///
    /// Each list is read so that its `j`th sticker goes to the `j`th sticker of
    /// the next list. Where a neighbour is drawn upside down relative to the way
    /// round the cube -- `B` against `U` and `D`, `D` and `L` against `F` -- its
    /// strip is read backwards, and that is the whole of the fiddly part.
    ///
    /// Which face sends to which was settled by turning a 3x3x3 both ways and
    /// comparing against the orbit tables, not by reasoning about handedness at
    /// a whiteboard.
    ///
    def strips(n: Int32, f: Int32): List[List[Int32]] = match f {
        case 0 => aroundUp(n)
        case 1 => aroundRight(n)
        case 2 => aroundFront(n)
        case 3 => aroundDown(n)
        case 4 => aroundLeft(n)
        case _ => aroundBack(n)
    }

    ///
    /// The top rows, in the order a clockwise `U` moves them.
    ///
    def aroundUp(n: Int32): List[List[Int32]] =
        row(n, 2, 0)
            :: row(n, 4, 0)
            :: row(n, 5, 0)
            :: row(n, 1, 0)
            :: Nil

    ///
    /// The bottom rows, in the order a clockwise `D` moves them.
    ///
    def aroundDown(n: Int32): List[List[Int32]] =
        let last = n - 1;
        row(n, 2, last)
            :: row(n, 1, last)
            :: row(n, 5, last)
            :: row(n, 4, last)
            :: Nil

    ///
    /// What a clockwise `R` moves. `B` is read backwards: it is drawn facing the
    /// other way, so its left column runs against the way round the cube.
    ///
    def aroundRight(n: Int32): List[List[Int32]] =
        let last = n - 1;
        col(n, 2, last)
            :: col(n, 0, last)
            :: back(col(n, 5, 0))
            :: col(n, 3, last)
            :: Nil

    ///
    /// What a clockwise `L` moves, with `B` again read backwards.
    ///
    def aroundLeft(n: Int32): List[List[Int32]] =
        col(n, 2, 0)
            :: col(n, 3, 0)
            :: back(col(n, 5, n - 1))
            :: col(n, 0, 0)
            :: Nil

    ///
    /// What a clockwise `F` moves. Two of the four run against the way round.
    ///
    def aroundFront(n: Int32): List[List[Int32]] =
        row(n, 0, n - 1)
            :: col(n, 1, 0)
            :: back(row(n, 3, 0))
            :: back(col(n, 4, n - 1))
            :: Nil

    ///
    /// What a clockwise `B` moves.
    ///
    def aroundBack(n: Int32): List[List[Int32]] =
        back(row(n, 0, 0))
            :: col(n, 4, 0)
            :: row(n, 3, n - 1)
            :: back(col(n, 1, n - 1))
            :: Nil

    /// The four strips `depth` in from face `f`, in the same send order as an
    /// outer turn of that face. Depth zero is intentionally handled by the
    /// outer-turn path, which also spins the face itself.
    def innerStrips(n: Int32, f: Int32, depth: Int32): List[List[Int32]] = match f {
        case 0 => aroundUpInner(n, depth)
        case 1 => aroundRightInner(n, depth)
        case 2 => aroundFrontInner(n, depth)
        case 3 => aroundDownInner(n, depth)
        case 4 => aroundLeftInner(n, depth)
        case _ => aroundBackInner(n, depth)
    }

    def aroundUpInner(n: Int32, d: Int32): List[List[Int32]] =
        row(n, 2, d) :: row(n, 4, d)
            :: row(n, 5, d) :: row(n, 1, d) :: Nil

    def aroundDownInner(n: Int32, d: Int32): List[List[Int32]] = {
        let last = n - 1 - d;
        row(n, 2, last) :: row(n, 1, last)
            :: row(n, 5, last) :: row(n, 4, last) :: Nil
    }

    def aroundRightInner(n: Int32, d: Int32): List[List[Int32]] = {
        let last = n - 1 - d;
        col(n, 2, last) :: col(n, 0, last) :: back(col(n, 5, d))
            :: col(n, 3, last) :: Nil
    }

    def aroundLeftInner(n: Int32, d: Int32): List[List[Int32]] = {
        let last = n - 1 - d;
        col(n, 2, d) :: col(n, 3, d)
            :: back(col(n, 5, last)) :: col(n, 0, d) :: Nil
    }

    def aroundFrontInner(n: Int32, d: Int32): List[List[Int32]] =
        let last = n - 1 - d;
        row(n, 0, last) :: col(n, 1, d) :: back(row(n, 3, d))
            :: back(col(n, 4, last)) :: Nil

    def aroundBackInner(n: Int32, d: Int32): List[List[Int32]] =
        let last = n - 1 - d;
        back(row(n, 0, d)) :: col(n, 4, d) :: row(n, 3, last)
            :: back(col(n, 1, last)) :: Nil

    ///
    /// Row `r` of face `f`, left to right as drawn.
    ///
    def row(n: Int32, f: Int32, r: Int32): List[Int32] =
        List.range(0, n) |> List.map(c -> f * n * n + r * n + c)

    ///
    /// Column `c` of face `f`, top to bottom as drawn.
    ///
    def col(n: Int32, f: Int32, c: Int32): List[Int32] =
        List.range(0, n) |> List.map(r -> f * n * n + r * n + c)

    ///
    /// A strip read the other way.
    ///
    def back(strip: List[Int32]): List[Int32] = List.reverse(strip)

}
