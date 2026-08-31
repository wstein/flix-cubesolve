///
/// Which method `solve` answers with.
///
/// **One method solves, and it says so.** `kociemba` is two-phase IDA* over the
/// whole cube: it answers any size this engine solves, it takes a `--budget`,
/// and it is complete.
///
/// `beginner` is being built and does not solve yet. Its stages, its decoded
/// -state recognition and its derived routines exist in the library; what does
/// not exist is the loop that observes a case, plays the routine for it and
/// looks again. Asking for it says so rather than falling back to something
/// else, because a command line that quietly answered with a different method
/// would be worse than one that refuses.
///
/// **`cfop` was removed rather than left working.** What stood behind it was a
/// global search over the first two layers labelled `F2L`. It solved cubes and
/// the label was false: reaching "first two layers solved" is not executing four
/// corner-edge pair insertions, and every caller, test and document that saw the
/// name would have been entitled to assume it was. It returns when it can run
/// cross, four pairs, OLL and PLL as separate observable steps.
///
mod Methods {

    use CubeSolve.Model.Cube

    ///
    /// The method asked for.
    ///
    pub enum Method with Eq, ToString {
        /// Two-phase IDA*, the engine's own solver.
        case Kociemba
        /// Layer by layer, the way a person is taught. Not yet able to solve.
        case Beginner
    }

    ///
    /// A method by name, or nothing.
    ///
    pub def ofName(s: String): Option[Method] = match String.toLowerCase(s) {
        case "kociemba" => Some(Method.Kociemba)
        case "beginner" => Some(Method.Beginner)
        case _          => None
    }

    ///
    /// What to call a method on the command line.
    ///
    pub def nameOf(m: Method): String = match m {
        case Method.Kociemba => "kociemba"
        case Method.Beginner => "beginner"
    }

    ///
    /// The methods, in the order they are offered.
    ///
    pub def all(): Vector[Method] = Vector#{Method.Kociemba, Method.Beginner}

    ///
    /// The names, for a refusal that lists what there is.
    ///
    pub def names(): String =
        all() |> Vector.map(nameOf) |> Vector.toList |> List.join(", ")

    ///
    /// The default.
    ///
    pub def standard(): Method = Method.Kociemba

    ///
    /// The method a command should use, given what `--method` carried.
    ///
    pub def named(given: Option[String]): Result[String, Method] =
        match given {
            case None       => Ok(standard())
            case Some(name) => match ofName(name) {
                case Some(m) => Ok(m)
                case None    => Err("'${name}' is not a method: there is ${names()}")
            }
        }

    ///
    /// Whether this method answers through `CubeSolve.Solve.Standard`.
    ///
    pub def twoPhase(m: Method): Bool = match m {
        case Method.Kociemba => true
        case Method.Beginner => false
    }

    ///
    /// What this method will cost before it answers, in words.
    ///
    pub def cost(m: Method, b: Budgets.Budget): String = match m {
        case Method.Kociemba =>
            "two-phase search, budget ${Budgets.nameOf(b)}; the tables are cached "
                + "after the first run"
        case Method.Beginner =>
            "not implemented: the stages and routines exist, the loop that plays "
                + "them does not"
    }

    ///
    /// Solve `c` by a human method, written out in steps.
    ///
    /// Only refusals for now. When the routine executor exists this is where it
    /// is called from.
    ///
    pub def answer(
        m: Method,
        _b: Budgets.Budget,
        _size: Int32,
        _c: Cube.Cube
    ): Result[String, String] =
        Err(notYet(m))

    ///
    /// The same answer as structured JSON.
    ///
    pub def answerJson(
        m: Method,
        _b: Budgets.Budget,
        _size: Int32,
        _c: Cube.Cube
    ): Result[String, String] =
        Err(notYet(m))

    ///
    /// Why a step method cannot answer yet.
    ///
    def notYet(m: Method): String =
        "${nameOf(m)} cannot solve yet: its stages and derived routines are in "
            + "the library, and the loop that observes a case and plays the "
            + "routine for it is not written. Use --method kociemba, which is "
            + "complete."
}
