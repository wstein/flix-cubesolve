///
/// Cube states with their size in the type.
///
/// `CubeSolve.Model.Cube` is generic in `n`, which is what lets one
/// implementation serve every size. The cost of that is that nothing stops a
/// 4x4x4 reaching a solver written for the 3x3x3, where it would be refused --
/// correctly, but at run time, on a path the caller has to handle.
///
/// These wrappers move that mismatch to compile time. They are plain newtypes
/// over the same `Cube`, so there is no second representation and no
/// conversion cost; what they add is that `standard` and `pocket` are different
/// types and cannot be passed for one another.
///
/// **A caveat worth stating.** Flix has no private enum case, so the
/// constructors are reachable and the guarantee is that a size mismatch is a
/// *type* error, not that every value was built through a smart constructor.
/// Build them with `pocketOf` and `standardOf`, which check the size and return
/// the reason when it is wrong.
///
mod CubeSolve.Model.Sized {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Cube.Cube
    use CubeSolve.Model.Sized.Pocket.Pocket
    use CubeSolve.Model.Sized.Standard.Standard

    ///
    /// A 2x2x2.
    ///
    pub enum Pocket with Eq, ToString {
        case Pocket(Cube)
    }

    ///
    /// A 3x3x3.
    ///
    pub enum Standard with Eq, ToString {
        case Standard(Cube)
    }

    ///
    /// The cube inside, for the generic operations that do not care about size.
    ///
    pub def cubeOfPocket(p: Pocket): Cube = let Pocket(c) = p; c

    ///
    /// The cube inside, for the generic operations that do not care about size.
    ///
    pub def cubeOfStandard(s: Standard): Cube = let Standard(c) = s; c

    ///
    /// `c` as a 2x2x2, or why it is not one.
    ///
    pub def pocketOf(c: Cube): Result[String, Pocket] =
        sizedAs(2, c) |> Result.map(Pocket)

    ///
    /// `c` as a 3x3x3, or why it is not one.
    ///
    pub def standardOf(c: Cube): Result[String, Standard] =
        sizedAs(3, c) |> Result.map(Standard)

    ///
    /// A solved 2x2x2.
    ///
    pub def solvedPocket(): Result[String, Pocket] =
        Cube.solved(2) |> Result.flatMap(pocketOf)

    ///
    /// A solved 3x3x3.
    ///
    pub def solvedStandard(): Result[String, Standard] =
        Cube.solved(3) |> Result.flatMap(standardOf)

    ///
    /// `c`, if it really is an `n x n x n`.
    ///
    def sizedAs(n: Int32, c: Cube): Result[String, Cube] =
        if (Cube.size(c) == n)
            Ok(c)
        else
            Err("expected a ${n}x${n}x${n} but this is a ${Cube.size(c)}x"
                + "${Cube.size(c)}x${Cube.size(c)}")

}
