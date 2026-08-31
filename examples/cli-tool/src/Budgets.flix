///
/// How hard the solver is asked to look.
///
/// `CubeSolve.Solve.Standard` counts probes rather than seconds, because a probe
/// is the same on every machine and a second is not. A larger budget buys a
/// shorter answer, and buys it with sharply diminishing returns -- the library
/// records 20.9 moves for `fast` against 20.8 for `default`, for roughly four
/// times the probes.
///
/// `max` is this package's own, built from `Standard.budget` rather than taken
/// from the library, because the library offers nothing beyond `deep`. Its
/// numbers are a deliberate step past `deep` and **its effect on move count
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
        case Deep
        case Max
    }

    ///
    /// The budget a name asks for, if it names one.
    ///
    pub def ofName(s: String): Option[Budget] = match String.toLowerCase(s) {
        case "fast"       => Some(Budget.Fast)
        case "default"    => Some(Budget.Standard)
        case "deep"       => Some(Budget.Deep)
        case "thorough"   => Some(Budget.Deep)
        case "max" => Some(Budget.Max)
        case _            => None
    }

    ///
    /// What a budget is called.
    ///
    pub def nameOf(b: Budget): String = match b {
        case Budget.Fast       => "fast"
        case Budget.Standard   => "default"
        case Budget.Deep       => "deep"
        case Budget.Max        => "max"
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
        Vector#{Budget.Fast, Budget.Standard, Budget.Deep, Budget.Max}

    ///
    /// The budgets there are, written out.
    ///
    pub def names(): String =
        all() |> Vector.map(nameOf) |> Vector.toList |> List.join(", ")

    ///
    /// What the solver is actually handed.
    ///
    /// The first three are the library's own, so their recorded averages apply.
    /// `max` takes every view and doubles `deep`'s handovers; it is this package's
    /// choice and carries no recorded average.
    ///
    pub def nodeBudget(b: Budget): Int64 = match b {
        case Budget.Fast       => 5_000_000i64
        case Budget.Standard   => 50_000_000i64
        case Budget.Deep       => 200_000_000i64
        case Budget.Max => 2_000_000_000i64
    }

    pub def solverBudget(b: Budget): Standard.Budget = match b {
        case Budget.Fast       => Standard.fastBudget()
        case Budget.Standard   => Standard.defaultBudget()
        case Budget.Deep       => Standard.deepBudget()
        case Budget.Max => Standard.maxBudget()
    }

}
