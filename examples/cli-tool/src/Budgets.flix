///
/// How hard the solver is asked to look.
///
/// `CubeSolve.Solve.Standard` counts probes rather than seconds, because a probe
/// is the same on every machine and a second is not. A larger budget buys a
/// shorter answer, and buys it with sharply diminishing returns -- the library
/// records 20.9 moves for `fast` against 20.4 for `default`, for roughly four
/// times the probes.
///
/// `deep` is this package's own, built from `Standard.budget` rather than taken
/// from the library, because the library offers nothing beyond `thorough`. Its
/// numbers are a deliberate step past `thorough` and **its effect on move count
/// is not measured here** -- what it promises is more searching, not a stated
/// average.
///
mod Budgets {

    use CubeSolve.Solve.Standard

    ///
    /// A named budget.
    ///
    pub enum Budget with Eq, ToString {
        case Fast
        case Standard
        case Thorough
        case Deep
    }

    ///
    /// The budget a name asks for, if it names one.
    ///
    pub def ofName(s: String): Option[Budget] = match String.toLowerCase(s) {
        case "fast"     => Some(Budget.Fast)
        case "default"  => Some(Budget.Standard)
        case "thorough" => Some(Budget.Thorough)
        case "deep"     => Some(Budget.Deep)
        case _          => None
    }

    ///
    /// What a budget is called.
    ///
    pub def nameOf(b: Budget): String = match b {
        case Budget.Fast     => "fast"
        case Budget.Standard => "default"
        case Budget.Thorough => "thorough"
        case Budget.Deep     => "deep"
    }

    ///
    /// The one used when none is asked for.
    ///
    pub def standard(): Budget = Budget.Standard

    ///
    /// Every budget there is, for a caller listing them.
    ///
    pub def all(): Vector[Budget] =
        Vector#{Budget.Fast, Budget.Standard, Budget.Thorough, Budget.Deep}

    ///
    /// The budgets there are, written out.
    ///
    pub def names(): String =
        all() |> Vector.map(nameOf) |> Vector.toList |> List.join(", ")

    ///
    /// What the solver is actually handed.
    ///
    /// The first three are the library's own, so their recorded averages apply.
    /// `deep` doubles `thorough`'s floor and its cap; it is this package's
    /// choice and carries no recorded average.
    ///
    pub def solverBudget(b: Budget): Standard.Budget = match b {
        case Budget.Fast     => Standard.fastBudget()
        case Budget.Standard => Standard.defaultBudget()
        case Budget.Thorough => Standard.thoroughBudget()
        case Budget.Deep     =>
            Standard.budget({
                probeMin = 1200, probeMax = 2400, maxDepth = 25, handovers = 300
            })
    }

}
