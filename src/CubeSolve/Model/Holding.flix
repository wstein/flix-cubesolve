///
/// A cube's identity up to how it is being held.
///
/// Two cubes are the same *state* when every piece sits in the same slot the
/// same way round. They are the same **pattern** when one is the other picked up
/// and turned in the hand. This module answers the second question; `Eq` on
/// `CubeSolve.Model.Cube` answers the first and is left alone, because the group
/// laws, the round trips and the sticker geometry all depend on `==` meaning
/// *identical* rather than *equivalent*.
///
/// It lives in the model rather than in `CubeSolve.Patterns` because it is a
/// fact about cubes, not about the published collections. The corpora merely
/// happen to be the first thing that needed it, and both had grown their own
/// copy of it.
///
/// **The relation is not the same at every size, and substituting one for the
/// other is wrong rather than approximate.**
///
/// - A **3x3x3** has fixed centres, which pin the frame. Two recordings of one
///   pattern are related by *conjugation*, and the identity is the smallest
///   token over the 24 conjugations.
/// - A **2x2x2** has no centres, so nothing pins the frame. Turning it in the
///   hand moves pieces between slots -- which is what a move does and is not
///   what conjugation does -- so the relation is one-sided, and the whole-cube
///   rotations really are pairs of moves. Using the 3x3x3 relation here was
///   tried, and it called distinct orientations distinct patterns while leaving
///   four patterns with no coordinate at all.
/// - **Anything larger has no answer here yet.** A cube with centre orbits
///   cannot be composed with another -- centres are a multiset of colours, so
///   nothing can say where the other state sent each slot -- and the one-sided
///   relation has not been established for those sizes either. `identityOf`
///   returns `None`, which is honest rather than a guess.
///
mod CubeSolve.Model.Holding {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Rotation

    ///
    /// This cube's identity up to how it is held, or nothing if this engine
    /// cannot say.
    ///
    /// The smallest token over every holding of `c`. Being the smallest makes it
    /// canonical: every holding of one pattern gives the same answer, and a
    /// canonical token is its own identity.
    ///
    /// **This is not a `Facelets.token`.** That describes the cube as it sits;
    /// this describes the pattern whichever way it is turned. Comparing one
    /// against the other reports a pattern as unknown when it is merely held
    /// differently.
    ///
    pub def identityOf(c: Cube.Cube): Option[String] = match Cube.size(c) {
        case 2 => smallest(reorientations()
            |> Vector.toList
            |> List.filterMap(e -> tokenAfter(snd(e), c)))
        case 3 => smallest(Rotation.all()
            |> Vector.toList
            |> List.filterMap(r ->
                Cube.conjugate(r, c) |> Result.flatMap(Facelets.token) |> Result.toOption))
        case _ => None
    }

    ///
    /// Whether `a` and `b` are the same pattern, however each is held.
    ///
    /// `false` when either identity is unavailable. A size this engine cannot
    /// canonicalise is not a size at which two cubes quietly compare equal:
    /// answering "no" to a question that cannot be answered is safe, and
    /// answering "yes" is not.
    ///
    pub def sameUpToHolding(a: Cube.Cube, b: Cube.Cube): Bool =
        match (identityOf(a), identityOf(b)) {
            case (Some(x), Some(y)) => x == y
            case _                  => false
        }

    ///
    /// The cube a token describes.
    ///
    /// `Orbit64.decode` inverts the encoding `Facelets.token` uses, so this
    /// round-trips any token that came from one. The cube comes back in the
    /// canonical frame: a token records the state, not the whole-cube rotation
    /// the original was sitting at, and that part is not recoverable.
    ///
    /// A *canonical* token decodes to one particular holding of its pattern.
    /// Which one is not meaningful; that `identityOf` of it is the token again
    /// is.
    ///
    pub def ofToken(n: Int32, token: String): Result[String, Cube.Cube] =
        Orbit64.decode(n, token) |> Result.flatMap(os -> Cube.ofOrbits(n, os))

    ///
    /// The moves that reach the holding `r` names, if it is one of the 24.
    ///
    pub def wordFor(r: Rotation.Rotation): Option[String] =
        reorientations() |> Vector.findLeft(e -> fst(e) == r) |> Option.map(snd)

    ///
    /// The smallest of some tokens, or nothing when there are none.
    ///
    def smallest(tokens: List[String]): Option[String] = List.minimum(tokens)

    ///
    /// The 24 ways a centreless cube can be held, each as a rotation and the
    /// moves that reach it.
    ///
    /// **On this puzzle a whole-cube turn is a pair of moves.** `x` is `R L'`,
    /// `y` is `U D'`, `z` is `F B'`: with no centres to hold still, turning both
    /// layers of an axis turns the cube. So these are `Layer` moves and not
    /// `Frame` ones, and applying one changes the state rather than the frame --
    /// which is the whole reason this corpus cannot use the 3x3x3's conjugation.
    ///
    /// Closed over the three generators rather than written out, so the table
    /// cannot disagree with the group it is meant to be.
    ///
    pub def reorientations(): Vector[(Rotation.Rotation, String)] =
        grow(List#{(Rotation.identity(), "")}) |> List.toVector
    ///
    /// `c`'s token after the moves `word`, if both work out.
    ///
    pub def tokenAfter(word: String, c: Cube.Cube): Option[String] =
        Cube.applyNotation(word, c) |> Result.flatMap(Facelets.token) |> Result.toOption
    ///
    /// The generators of the re-holding group, with the moves that make them.
    ///
    def generators(): List[(Rotation.Rotation, String)] = List#{
        (Rotation.x(), "R L'"),
        (Rotation.y(), "U D'"),
        (Rotation.z(), "F B'")
    }
    ///
    /// `found` closed under the generators.
    ///
    def grow(found: List[(Rotation.Rotation, String)]): List[(Rotation.Rotation, String)] =
        let seen = found |> List.map(fst) |> List.toSet;
        let fresh = found
            |> List.flatMap(e -> generators() |> List.map(g -> extend(e, g)))
            |> List.filter(e -> not Set.memberOf(fst(e), seen))
            |> firstOfEachRotation;
        if (List.isEmpty(fresh)) found else grow(List.append(found, fresh))
    ///
    /// One entry followed by one generator.
    ///
    def extend(
        e: (Rotation.Rotation, String),
        g: (Rotation.Rotation, String)
    ): (Rotation.Rotation, String) =
        let (r, w) = e;
        let (gr, gw) = g;
        (Rotation.andThen(r, gr), if (String.isEmpty(w)) gw else "${w} ${gw}")
    ///
    /// `es` with later entries for an already-seen rotation dropped.
    ///
    /// Keeping the first means the word for a rotation is the shortest one the
    /// closure reached it by, which is what makes the table's words readable.
    ///
    def firstOfEachRotation(
        es: List[(Rotation.Rotation, String)]
    ): List[(Rotation.Rotation, String)] =
        let keep = (acc, e) ->
            if (List.exists(a -> fst(a) == fst(e), acc))
                acc
            else
                List.append(acc, e :: Nil);
        List.foldLeft(keep, Nil, es)
}
