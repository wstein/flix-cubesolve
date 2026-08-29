///
/// Reading the arguments a command was given.
///
/// Separated from `Main` so that dispatching a command and interpreting its
/// arguments are not the same module: the parser needs the model to turn a
/// scramble into a cube, and the dispatcher needs none of that.
///
mod Args {

    use Args.Needs.{Turning, Solving, Corpus}
    use CubeSolve.Model.Cube

    ///
    /// What a command needs of a cube size before it can run.
    ///
    /// Three different questions, and answering the wrong one is how a command
    /// line ends up refusing to draw a 4x4x4 -- which it can do perfectly well
    /// -- or offering to solve one, which it cannot. Every command names which
    /// it needs, and the refusal names the capability that is missing rather
    /// than saying "unsupported".
    ///
    pub enum Needs with Eq, ToString {
        case Turning
        case Solving
        case Corpus
    }

    ///
    /// Pull an optional `--size n` off the front and hand the rest on.
    ///
    /// `CubeSolve` is the authority on every capability here and is asked rather
    /// than repeated, so these refusals stop being true the moment the engine
    /// grows -- and not before.
    ///
    pub def withSize(
        args: List[String],
        needs: Needs,
        k: (Int32, List[String]) -> Result[String, String] \ ef
    ): Result[String, String] \ ef = match args {
        case "--size" :: n :: rest =>
            match Int32.fromString(n) {
                case None    => Err("'${n}' is not a size")
                case Some(s) => match refusal(needs, s) {
                    case Some(why) => Err(why)
                    case None      => k(s, rest)
                }
            }
        case rest => k(3, rest)
    }

    ///
    /// Why `n` will not do for a command that needs `needs`, if it will not.
    ///
    pub def refusal(needs: Needs, n: Int32): Option[String] =
        let cube = "${n}x${n}x${n}";
        match needs {
            case Turning =>
                if (CubeSolve.canTurn(n))
                    None
                else
                    Some("this engine turns ${written(CubeSolve.turnableSizes())}, "
                        + "not a ${cube}")
            case Solving =>
                if (CubeSolve.supports(n))
                    None
                else if (CubeSolve.canTurn(n))
                    Some("a ${cube} can be turned and drawn but not solved: there "
                        + "is no solver for it yet. This engine solves "
                        + "${written(CubeSolve.supportedSizes())}")
                else
                    Some("this engine solves ${written(CubeSolve.supportedSizes())}, "
                        + "not a ${cube}")
            case Corpus =>
                if (CubeSolve.supports(n))
                    None
                else
                    Some("there is no published pattern collection for a ${cube} "
                        + "here: the corpora cover "
                        + "${written(CubeSolve.supportedSizes())}")
        }

    ///
    /// A list of sizes, written out.
    ///
    pub def written(sizes: Vector[Int32]): String =
        sizes
            |> Vector.map(n -> "${n}x${n}x${n}")
            |> Vector.toList
            |> List.join(", ")

    ///
    /// Read a scramble from the remaining arguments and hand the cube on.
    ///
    pub def onCube(
        size: Int32,
        rest: List[String],
        k: (Int32, Cube.Cube) -> Result[String, String] \ ef
    ): Result[String, String] \ ef =
        let written = String.trim(List.join(" ", rest));
        if (String.isEmpty(written))
            Err("give a scramble, for example: R U R' U'")
        else
            Cube.solved(size)
                |> Result.flatMap(c -> Cube.applyNotation(written, c))
                |> Result.flatMap(c -> k(size, c))

}
