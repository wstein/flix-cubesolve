///
/// Which method `solve` answers with.
///
/// Three, and they differ in what they search, not in whether they do:
///
/// - `kociemba` is two-phase IDA* over the whole cube. It is the default and
///   the only one that answers a cube of any size this engine solves.
/// - `cfop` and `beginner` answer 3x3x3 in named steps. **They are searches
///   too.** Cross, the first layer and the first two layers are each IDA* over
///   their own tables, and they are what the runtime is spent on -- the
///   last-layer steps are a table lookup and cost nothing by comparison.
///
/// An earlier version of this file said these methods were not searches and so
/// ignored `--budget`. That was wrong, and it hid the operation that dominates
/// the wait: the first-two-layer search has been measured at over thirteen
/// million nodes from a state with the first layer already solved, and CFOP
/// enters it with only the cross done.
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
    /// What this method will cost before it answers, in words.
    ///
    /// Said at `--verbose` because the step methods build over three million
    /// states, and a long silence is indistinguishable from a hang.
    ///
    pub def cost(m: Method, b: Budgets.Budget): String =
        let nodes = "${Budgets.nodeBudget(b)} nodes per stage";
        match m {
            case Method.Kociemba =>
                "two-phase search; the tables are cached after the first run"
            case Method.Cfop =>
                "searches the first two layers as one goal, entered with only "
                    + "the cross solved, which is the widest handoff here; "
                    + "${nodes}"
            case Method.Beginner =>
                "searches the cross, the first layer and the middle edges in "
                    + "turn; ${nodes}"
        }

    ///
    /// Whether this method answers through `CubeSolve.Solve.Standard`.
    ///
    /// **Not "whether it searches" -- all three do.** This says which entry
    /// point the command line calls, because the two-phase solver takes a
    /// budget as an argument and the step methods carry their own search
    /// depths inside each stage.
    ///
    pub def twoPhase(m: Method): Bool = match m {
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
    /// **The tables are read from the on-disk cache**, and built only when it
    /// has nothing to offer. They are 3.8 million states and take a minute or
    /// two to construct, so a command line that built them on every invocation
    /// would pay that every time -- which is what this did until `0.4.2` gave
    /// the first-two-layer tables a cache at all.
    ///
    pub def answer(
        m: Method,
        b: Budgets.Budget,
        size: Int32,
        c: Cube.Cube
    ): Result[String, String] \ IO =
        forM (
            netStr <- RenderNet.colouredNet(c);
            tok <- Facelets.token(c);
            plan <- withPlan(m, b, size, c, p -> p)
        ) yield {
            let sep = String.lineSeparator();
            "${netStr}${sep}"
                + "${Plan.render(plan)}${sep}"
                + "${Plan.layerTurns(plan)} moves (HTM)${sep}"
                + "method:  ${nameOf(m)}${sep}"
                + "budget:  ${Budgets.nameOf(b)}, "
                + "${Budgets.nodeBudget(b)} nodes per stage${sep}"
                + "orbit64: ${tok}"
        }

    ///
    /// The same answer as structured JSON.
    ///
    /// The steps are an array rather than the rendered document, because a
    /// caller asking for JSON wants the steps as data; the flattened sequence
    /// is included because that is what gets replayed.
    ///
    pub def answerJson(
        m: Method,
        b: Budgets.Budget,
        size: Int32,
        c: Cube.Cube
    ): Result[String, String] \ IO =
        withPlan(m, b, size, c, plan ->
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
        b: Budgets.Budget,
        size: Int32,
        c: Cube.Cube,
        k: Plan.Plan -> a
    ): Result[String, a] \ IO =
        if (size != 3)
            Err("${nameOf(m)} solves 3x3x3 only, and this is ${size}x${size}x${size}"
                + ": use --method kociemba")
        else
            Store.cached(() -> forM (
                t <- Cfop.cachedTables();
                plan <- planFor(m, t, c, Budgets.nodeBudget(b))
            ) yield k(plan))

    ///
    /// The plan a method makes, or why it made none.
    ///
    def planFor(
        m: Method,
        t: TwoLayers.Tables,
        c: Cube.Cube,
        maxNodes: Int64
    ): Result[String, Plan.Plan] = match m {
        case Method.Cfop     =>
            Cfop.solution(t, Profile.Profile.SourceFirst, c, maxNodes)
        case Method.Beginner =>
            Beginner.solution(Beginner.Tables.Tables(t), Profile.Profile.SourceFirst, c,
                maxNodes)
        case Method.Kociemba =>
            Err("kociemba is not a step method: this is a fault in the command "
                + "line, not in the cube")
    }
}
