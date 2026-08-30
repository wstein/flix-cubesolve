///
/// Which method `solve` answers with.
///
/// Three, and they are different products rather than three settings of one:
///
/// - `kociemba` searches. It is the default, it takes a `--budget`, and it is
///   the only one that answers a cube of any size this engine solves.
/// - `cfop` and `beginner` work the way a person does, in named steps, and
///   answer 3x3x3 only. They ignore `--budget`: nothing about them is a search
///   with a time limit, so honouring it would be pretending.
///
/// A method answer is much longer than a searched one. That is the point of it
/// -- it says which step, which case and which moves -- and it is not offered
/// as a short solution.
///
mod Methods {

    use CubeSolve.Method.Beginner
    use CubeSolve.Method.Cfop
    use CubeSolve.Method.Plan
    use CubeSolve.Method.Profile
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Solve.TwoLayers

    ///
    /// The method asked for.
    ///
    pub enum Method with Eq, ToString {
        /// Two-phase IDA*, the engine's own solver.
        case Kociemba
        /// Cross, F2L, OLL, PLL.
        case Cfop
        /// Cross, first layer, middle edges, OLL, PLL.
        case Beginner
    }

    ///
    /// A method by name, or nothing.
    ///
    pub def ofName(s: String): Option[Method] = match String.toLowerCase(s) {
        case "kociemba" => Some(Method.Kociemba)
        case "cfop"     => Some(Method.Cfop)
        case "beginner" => Some(Method.Beginner)
        case _          => None
    }

    ///
    /// What to call a method on the command line.
    ///
    pub def nameOf(m: Method): String = match m {
        case Method.Kociemba => "kociemba"
        case Method.Cfop     => "cfop"
        case Method.Beginner => "beginner"
    }

    ///
    /// The methods, in the order they are offered.
    ///
    pub def all(): Vector[Method] =
        Vector#{Method.Kociemba, Method.Cfop, Method.Beginner}

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
    /// Whether this method searches, and so whether `--budget` means anything.
    ///
    pub def searches(m: Method): Bool = match m {
        case Method.Kociemba => true
        case Method.Cfop     => false
        case Method.Beginner => false
    }

    ///
    /// Solve `c` by a human method, written out in steps.
    ///
    /// Named `answer` rather than `solve` because `solve` is a Flix keyword.
    ///
    /// Refuses a cube that is not 3x3x3 by naming the method, rather than
    /// falling back to the searching solver: somebody who asked for CFOP on a
    /// 4x4x4 wants to be told there is no such thing here, not handed a
    /// two-phase answer under a CFOP heading.
    ///
    /// **The tables take about eighty seconds to build**, once per invocation,
    /// and both methods use the same set. A command line pays that every time
    /// it runs; a program solving many cubes should build once and keep them.
    ///
    pub def answer(m: Method, size: Int32, c: Cube.Cube): Result[String, String] =
        withPlan(m, size, c, plan -> Plan.render(plan))

    ///
    /// The same answer as structured JSON.
    ///
    /// The steps are an array rather than the rendered document, because a
    /// caller asking for JSON wants the steps as data; the flattened sequence
    /// is included because that is what gets replayed.
    ///
    pub def answerJson(
        m: Method,
        size: Int32,
        c: Cube.Cube
    ): Result[String, String] =
        withPlan(m, size, c, plan ->
            JsonOut.plan(
                size,
                Facelets.token(c) |> Result.getWithDefault("unknown"),
                nameOf(m),
                Plan.sequenceOf(plan),
                Plan.layerTurns(plan),
                plan#steps |> List.map(s -> (s#label, s#sequence))
            ))

    ///
    /// Solve by a method and hand the plan to `k`, or say why there is none.
    ///
    def withPlan(
        m: Method,
        size: Int32,
        c: Cube.Cube,
        k: Plan.Plan -> String
    ): Result[String, String] =
        if (size != 3)
            Err("${nameOf(m)} solves 3x3x3 only, and this is ${size}x${size}x${size}"
                + ": use --method kociemba")
        else
            forM (
                t <- Cfop.build();
                plan <- planFor(m, t, c)
            ) yield k(plan)

    ///
    /// The plan a method makes, or why it made none.
    ///
    def planFor(
        m: Method,
        t: TwoLayers.Tables,
        c: Cube.Cube
    ): Result[String, Plan.Plan] = match m {
        case Method.Cfop     => Cfop.solution(t, Profile.Profile.SourceFirst, c)
        case Method.Beginner =>
            Beginner.solution(Beginner.Tables.Tables(t), Profile.Profile.SourceFirst, c)
        case Method.Kociemba =>
            Err("kociemba is not a step method: this is a fault in the command "
                + "line, not in the cube")
    }
}
