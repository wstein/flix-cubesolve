///
/// Whole-cube rotations: the twenty-four ways a cube can sit in space.
///
/// A rotation moves no piece relative to any other. What it changes is the
/// *frame* -- which physical face is currently called U, which is called F --
/// and so it changes what a later `R` means without changing what the cube
/// looks like.
///
/// `flix-orbit64` has no notion of this. It excludes an odd cube's six fixed
/// centres because they define the frame rather than carrying state, and its
/// `fromFacelets` refuses a cube whose fixed centres have moved. A codec may do
/// that. A solver may not: `M`, `E`, `S`, `x`, `y`, `z` and the wide turns used
/// by WCA scrambles all move centres relative to the frame, and users paste
/// them. Tracking the rotation is how a solution found after one is expressed
/// back in the frame the caller started in.
///
/// A rotation is represented by its action on the six faces and by nothing
/// else. That is sound because the action is faithful -- only the identity
/// fixes every face -- and it is asserted rather than assumed.
///
mod CubeSolve.Model.Rotation {

    use CubeSolve.Model.Move
    use CubeSolve.Model.Move.Move.Turn

    ///
    /// A rotation, as the face sitting at each position after it is applied.
    ///
    /// Slot-indexed like every other permutation here: entry `i` names the face
    /// that ends up at position `i`. So the identity is `U R F D L B`, in the
    /// face numbering of `CubeSolve.Model.Move`.
    ///
    pub enum Rotation with Eq, Order {
        case Rotation(Vector[Int32])
    }

    instance ToString[Rotation] {
        pub def toString(r: Rotation): String = show(r)
    }

    ///
    /// The rotation that changes nothing.
    ///
    pub def identity(): Rotation = Rotation(Vector.range(0, 6))

    ///
    /// A quarter turn of the whole cube about the R/L axis, in the direction of
    /// an `R` turn: the front face goes to the top.
    ///
    pub def x(): Rotation = Rotation(Vector#{2, 1, 3, 5, 4, 0})

    ///
    /// A quarter turn about the U/D axis, in the direction of a `U` turn: the
    /// right face goes to the front.
    ///
    pub def y(): Rotation = Rotation(Vector#{0, 5, 1, 3, 2, 4})

    ///
    /// A quarter turn about the F/B axis, in the direction of an `F` turn: the
    /// left face goes to the top.
    ///
    pub def z(): Rotation = Rotation(Vector#{4, 0, 2, 1, 3, 5})

    ///
    /// The face sitting at each position after `r`.
    ///
    pub def faceMap(r: Rotation): Vector[Int32] = let Rotation(m) = r; m

    ///
    /// `r` written as the six faces it puts at each position.
    ///
    pub def show(r: Rotation): String =
        faceMap(r) |> Vector.map(faceLetter) |> Vector.join("")

    ///
    /// The letter of the face with index `i`.
    ///
    def faceLetter(i: Int32): String =
        Move.faceOfIndex(i)
            |> Option.map(f -> "${f}")
            |> Option.getWithDefault("?")

    ///
    /// `first`, then `second`.
    ///
    /// Slot-indexed composition, matching the convention for pieces: after
    /// `first` the face at position `i` is `first[i]`, and applying `second`
    /// brings the face from position `second[i]`, so the combined map is
    /// `first[second[i]]`.
    ///
    pub def andThen(first: Rotation, second: Rotation): Rotation =
        let a = faceMap(first);
        let b = faceMap(second);
        Rotation(Vector.init(i -> Vector.get(Vector.get(i, b), a), 6))

    ///
    /// The rotation that undoes `r`.
    ///
    pub def inverse(r: Rotation): Rotation =
        let m = faceMap(r);
        Rotation(Vector.init(i -> Vector.indexOf(i, m) |> Option.getWithDefault(i), 6))

    ///
    /// All twenty-four rotations, identity first.
    ///
    /// Generated as the closure of `x`, `y` and `z` rather than written out, so
    /// that the count is a result rather than a claim -- a wrong generator gives
    /// a subgroup of the wrong size and fails loudly.
    ///
    pub def all(): Vector[Rotation] =
        close(identity() :: Nil, identity() :: Nil) |> List.toVector

    ///
    /// Breadth-first closure of `frontier` under the three generators.
    ///
    def close(found: List[Rotation], frontier: List[Rotation]): List[Rotation] =
        match frontier {
            case Nil => List.reverse(found)
            case _   =>
                let generators = x() :: y() :: z() :: Nil;
                let step = r -> generators |> List.map(g -> andThen(r, g));
                let grown = frontier |> List.flatMap(step);
                let unseen = grown |> List.filter(r -> not List.memberOf(r, found));
                let fresh = List.distinct(unseen);
                close(List.append(List.reverse(fresh), found), fresh)
        }

    ///
    /// The move `m` names in the frame `r` produced, expressed in the frame
    /// before it.
    ///
    /// Turning the face now at position `f` is turning whichever face `r` put
    /// there, and the amount is untouched. This is the step that takes a
    /// solution found after a rotation and states it in the caller's terms.
    ///
    pub def reframe(m: Move.Move, r: Rotation): Move.Move =
        let renamed = Vector.get(Move.faceIndex(Move.face(m)), faceMap(r));
        match Move.faceOfIndex(renamed) {
            case Some(f) => Turn(f, Move.amount(m))
            case None    => m
        }

    // ---------- what a rotation does to pieces ----------

    ///
    /// Where each corner slot's piece comes from, when the cube is turned by `r`.
    ///
    /// Derived from the face map rather than written out. A slot is the set of
    /// faces it touches, a rotation permutes faces, so the slot a piece lands in
    /// is found by mapping its faces and looking up the result.
    ///
    pub def cornerPermutation(r: Rotation): Vector[Int32] =
        slotMap(Move.cornerFaces(), r)

    ///
    /// Where each edge slot's piece comes from, when the cube is turned by `r`.
    ///
    pub def edgePermutation(r: Rotation): Vector[Int32] =
        slotMap(Move.edgeFaces(), r)

    ///
    /// The twist each corner slot's piece shows, after the cube is turned by `r`.
    ///
    /// A rotation moves no piece relative to any other, but it does change which
    /// facelet each *slot* calls its first, so the recorded twist changes even
    /// though nothing turned. This is that bookkeeping.
    ///
    pub def cornerTwist(r: Rotation): Vector[Int32] =
        orientationShift(Move.cornerFaces(), r, 3)

    ///
    /// The flip each edge slot's piece shows, after the cube is turned by `r`.
    ///
    pub def edgeFlip(r: Rotation): Vector[Int32] =
        orientationShift(Move.edgeFaces(), r, 2)

    ///
    /// For each destination slot, the slot whose piece arrives there.
    ///
    def slotMap(faces: Vector[Vector[Int32]], r: Rotation): Vector[Int32] =
        let n = Vector.length(faces);
        let arrivals = Vector.init(source -> destinationOf(faces, r, source), n);
        Vector.init(dest ->
            Vector.indexOf(dest, arrivals) |> Option.getWithDefault(dest), n)

    ///
    /// The slot the piece at `source` lands in, under `r`.
    ///
    def destinationOf(faces: Vector[Vector[Int32]], r: Rotation, source: Int32): Int32 =
        let moved = Vector.get(source, faces) |> Vector.map(f -> facePositionOf(f, r));
        let n = Vector.length(faces);
        Vector.range(0, n)
            |> Vector.findLeft(slot -> sameFaces(Vector.get(slot, faces), moved))
            |> Option.getWithDefault(source)

    ///
    /// Where face `f` ends up under `r`.
    ///
    /// The face map says which face arrives at each position; this is the other
    /// direction.
    ///
    def facePositionOf(f: Int32, r: Rotation): Int32 =
        Vector.indexOf(f, faceMap(r)) |> Option.getWithDefault(f)

    ///
    /// Whether two slots touch the same faces, in any order.
    ///
    def sameFaces(a: Vector[Int32], b: Vector[Int32]): Bool =
        let alsoInB = f -> Vector.memberOf(f, b);
        Vector.length(a) == Vector.length(b) and Vector.forAll(alsoInB, a)

    ///
    /// For each destination slot, how far its arriving piece's first face has
    /// rotated away from the slot's own first face.
    ///
    def orientationShift(
        faces: Vector[Vector[Int32]],
        r: Rotation,
        modulus: Int32
    ): Vector[Int32] =
        let n = Vector.length(faces);
        let comingFrom = slotMap(faces, r);
        Vector.init(dest -> {
            let source = Vector.get(dest, comingFrom);
            let primary = facePositionOf(Vector.get(0, Vector.get(source, faces)), r);
            Vector.indexOf(primary, Vector.get(dest, faces))
                |> Option.getWithDefault(0)
                |> (i -> Int32.modulo(i, modulus))
        }, n)

}
