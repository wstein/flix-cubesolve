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
    /// The budget a command should use, given what `--budget` carried.
    ///
    /// An unknown name is refused with the ones that exist rather than quietly
    /// falling back: a caller who misspells a budget should be told, not given
    /// something else and left to wonder why the answer changed.
    ///
    pub def named(given: Option[String]): Result[String, Budget] =
        match given {
            case None       => Ok(standard())
            case Some(name) => match ofName(name) {
                case Some(b) => Ok(b)
                case None    => Err("'${name}' is not a budget: there is ${names()}")
            }
        }

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
    ///
    /// How many search nodes a step method's stage may spend.
    ///
    /// The step methods search too, so a budget means something to them: a
    /// bound that fails with a count reached rather than running on
    /// indefinitely. Nothing consumes this until the routine executor exists,
    /// and it is kept because the bound is a property of the search, not of
    /// whichever method happens to call it.
    ///
    /// **The bound is per stage, not per solve.** Cross, the first layer and
    /// the first two layers are separate searches with separate budgets, so a
    /// solve that clears three stages may spend three times this.
    ///
    /// **Only the low end is measured.** The first-two-layer search has been
    /// recorded at 13.2 million nodes from a state with the first layer solved,
    /// and CFOP enters it with only the cross done, so `fast` is deliberately
    /// below what a hard cube needs -- it is for a quick answer or a quick
    /// refusal, not for every cube. The three larger numbers are room to work
    /// rather than measurements, and will be replaced by measurements once the
    /// node counts for the wider handoff are recorded.
    ///
    pub def nodeBudget(b: Budget): Int64 = match b {
        case Budget.Fast     => 5_000_000i64
        case Budget.Standard => 50_000_000i64
        case Budget.Thorough => 200_000_000i64
        case Budget.Deep     => 2_000_000_000i64
    }

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
