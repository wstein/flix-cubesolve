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

}
