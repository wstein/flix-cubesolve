///
/// Reading the arguments a command was given.
///
/// Separated from `Main` so that dispatching a command and interpreting its
/// arguments are not the same module: the parser needs the model to turn a
/// scramble into a cube, and the dispatcher needs none of that.
///
mod Args {

    use Args.Needs.{Turning, Solving, Corpus}
    use CubeSolve.Method.Profile
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
    /// Pull an optional `--json` flag off the argument list and pass the boolean to `k`.
    ///
    pub def withJson(
        args: List[String],
        k: (Bool, List[String]) -> a \ ef
    ): a \ ef =
        let isJson = List.exists(a -> a == "--json", args);
        let rest = List.filter(a -> a != "--json", args);
        k(isJson, rest)

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
    /// Pull an optional `--profile <name>` off the front and hand the rest on.
    ///
    /// Defaults to `default`, which is the algorithm the source lists first. An
    /// unknown name is refused with the ones that exist, rather than quietly
    /// falling back -- a caller who misspells a profile should be told, not
    /// given something else.
    ///
    pub def withProfile(
        args: List[String],
        k: (Profile.Profile, List[String]) -> Result[String, String] \ ef
    ): Result[String, String] \ ef = match args {
        case "--profile" :: name :: rest =>
            match Profile.ofName(name) {
                case Some(p) => k(p, rest)
                case None    =>
                    Err("'${name}' is not a profile: there is ${profileNames()}")
            }
        case rest => k(Profile.Profile.SourceFirst, rest)
    }

    ///
    /// The profiles there are, written out.
    ///
    pub def profileNames(): String =
        Profile.all()
            |> Vector.map(Profile.nameOf)
            |> Vector.toList
            |> List.join(", ")

    ///
    /// Read move notation, a state token, or URL and hand the cube on.
    ///
    pub def onCube(
        size: Int32,
        rest: List[String],
        k: (Int32, Cube.Cube) -> Result[String, String] \ ef
    ): Result[String, String] \ ef =
        let written = String.trim(List.join(" ", rest));
        if (String.isEmpty(written))
            Err("give move notation or a state token, for example: R U R' U' or AAAAAAAAAAf_")
        else
            parseCube(size, written)
                |> Result.flatMap(c -> k(Cube.size(c), c))

    def isTokenChar(c: Char): Bool =
        Char.isLetter(c) or Char.isDigit(c) or c == '_' or c == '-'

    def cleanInput(raw: String): String = {
        let trimmed = String.trim(raw);
        if (String.contains(substr = "#", trimmed)) {
            match String.split(regex = "#", trimmed) {
                case _ :: fragment :: _ => String.trim(fragment)
                case _ => trimmed
            }
        } else trimmed
    }

    def autodetectSize(token: String): Option[Int32] = match String.length(token) {
        case 8  => Some(2)
        case 12 => Some(3)
        case 27 => Some(4)
        case 42 => Some(5)
        case _  => None
    }

    def parseCube(size: Int32, raw: String): Result[String, Cube.Cube] = {
        let input = cleanInput(raw);
        let isTokenLike = not String.isEmpty(input)
            and not String.contains(substr = " ", input)
            and List.forAll(isTokenChar, String.toList(input));
        if (isTokenLike) {
            let targetSize = match autodetectSize(input) {
                case Some(s) if size == 3 => s
                case _ => size
            };
            match CubeSolve.Model.Holding.ofToken(targetSize, input) {
                case Ok(c) => Ok(c)
                case Err(_) =>
                    Cube.solved(size)
                        |> Result.flatMap(c -> Cube.applyNotation(input, c))
            }
        } else {
            Cube.solved(size)
                |> Result.flatMap(c -> Cube.applyNotation(input, c))
        }
    }

}
