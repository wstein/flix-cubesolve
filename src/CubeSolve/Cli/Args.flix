///
/// Reading the arguments a command was given.
///
/// Separated from `CubeSolve.Cli` so that dispatching a command and
/// interpreting its arguments are not the same module: the parser needs the
/// model to turn a scramble into a cube, and the dispatcher needs none of that.
///
mod CubeSolve.Cli.Args {

    use CubeSolve.Cli.Usage
    use CubeSolve.Model.Cube

    ///
    /// Pull an optional `--size n` off the front and hand the rest on.
    ///
    /// `CubeSolve.supportedSizes` is the authority on which sizes exist and is
    /// asked rather than repeated, so this stops being a lie the moment a 4x4x4
    /// arrives.
    ///
    pub def withSize(
        args: List[String],
        k: (Int32, List[String]) -> Result[String, String] \ ef
    ): Result[String, String] \ ef = match args {
        case "--size" :: n :: rest =>
            match Int32.fromString(n) {
                case None    => Err("'${n}' is not a size")
                case Some(s) =>
                    if (CubeSolve.supports(s))
                        k(s, rest)
                    else
                        Err("this engine solves ${Usage.sizes()}, not ${s}x${s}x${s}")
            }
        case rest => k(3, rest)
    }

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
