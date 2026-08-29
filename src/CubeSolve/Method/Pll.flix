///
/// Permutation of the Last Layer, the final step of the CFOP method.
///
/// **A human method, not a search.** `CubeSolve.Solve.Standard` answers any
/// cube with a short sequence found by looking; this answers one particular
/// partial state by recognising it and playing back an algorithm a person has
/// memorised. The two are different products and neither is a better version of
/// the other: a PLL answer is longer than an optimal one and is not offered as
/// a solution to an arbitrary cube.
///
/// Nothing in the solver calls this, and `Standard.solution` is unchanged. It is
/// opt-in.
///
/// **The precondition is checked from decoded model state**, never assumed. A
/// cube is a PLL case when the first two layers are solved and the last layer
/// is oriented -- every piece below the top in its own slot the right way round,
/// and every top piece showing the top colour. What is left is where the top
/// pieces sit, which is what PLL permutes.
///
/// **AUF is part of the answer.** The same case can arrive turned any of four
/// ways, and the algorithm for it assumes one. So recognition reports the `U`
/// turn to make before the algorithm and the one to make after, and both are
/// found by replaying rather than derived -- a returned answer has been applied
/// to the cube in hand and seen to solve it before it is offered.
///
/// **One algorithm per case, and it is not claimed to be the fastest.** The
/// source lists many for each, and says plainly that a longer algorithm may be
/// quicker for a given person, so which is best is not a fact this module can
/// hold. What is recorded is one published, replay-checked choice.
///
mod CubeSolve.Method.Pll {

    use CubeSolve.Method.Pll.Case.Case
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// One case: the name it is known by, an algorithm that solves it, and the
    /// shortest anyone has published for it in the half-turn metric.
    ///
    pub enum Case with Eq, ToString {
        case Case(String, String, Int32)
    }

    ///
    /// The name this case is known by.
    ///
    pub def name(c: Case): String = let Case(n, _, _) = c; n

    ///
    /// The algorithm recorded for it. Speed-oriented rather than optimal.
    ///
    pub def algorithm(c: Case): String = let Case(_, a, _) = c; a

    ///
    /// The shortest published length for this case, in HTM.
    ///
    /// Recorded so that the gap between the algorithm above and the optimum is
    /// visible rather than implied. They are usually different, and that is the
    /// point of a speed algorithm.
    ///
    pub def optimalHtm(c: Case): Int32 = let Case(_, _, h) = c; h

    ///
    /// Where these came from.
    ///
    pub def source(): String =
        "https://www.speedsolving.com/wiki/index.php?title=PLL"

    ///
    /// What a recognised cube turned out to be.
    ///
    /// `caseName` is the name it is known by. `setup` and `finish` are quarter
    /// turns of `U`, zero to three. `sequence`
    /// is the whole thing written out, `ops` the same thing parsed -- a list of
    /// moves would not do, because published algorithms contain whole-cube
    /// rotations and dropping those changes what the sequence does.
    ///
    pub type alias Solution = {
        caseName = String,
        algorithm = String,
        setup = Int32,
        finish = Int32,
        sequence = String,
        ops = List[Notation.Op],
        optimalHtm = Int32,
        source = String
    }

    ///
    /// Why `c` is not a PLL case, or nothing if it is one.
    ///
    /// Read off the decoded model state. Asking the search layer would be the
    /// wrong question and asking the facelets would be a slower way to ask this
    /// one.
    ///
    pub def precondition(c: Cube.Cube): Option[String] =
        if (Cube.size(c) != 3)
            Some("PLL is a 3x3x3 step, and this is a "
                + "${Cube.size(c)}x${Cube.size(c)}x${Cube.size(c)}")
        else
            match Cube.orbits(c) {
                case CornerCoord(cp, co) :: MidgeCoord(ep, eo) :: Nil =>
                    firstFault(cp, co, ep, eo)
                case _ => Some("this cube does not have the orbits a 3x3x3 has")
            }

    ///
    /// The first way `c` falls short of being a PLL case.
    ///
    def firstFault(
        cp: Vector[Int32],
        co: Vector[Int32],
        ep: Vector[Int32],
        eo: Vector[Int32]
    ): Option[String] =
        if (not homeAndUntwisted(4, 8, cp, co))
            Some("the first two layers are not solved: a bottom corner is out of "
                + "place or twisted")
        else if (not homeAndUntwisted(4, 12, ep, eo))
            Some("the first two layers are not solved: a bottom or middle edge is "
                + "out of place or flipped")
        else if (not allZero(0, 4, co))
            Some("the last layer is not oriented: a top corner is twisted, so this "
                + "is an OLL case rather than a PLL one")
        else if (not allZero(0, 4, eo))
            Some("the last layer is not oriented: a top edge is flipped, so this is "
                + "an OLL case rather than a PLL one")
        else
            None

    ///
    /// Whether every slot from `start` up to `stop` holds its own piece, unturned.
    ///
    def homeAndUntwisted(
        start: Int32,
        stop: Int32,
        perm: Vector[Int32],
        ori: Vector[Int32]
    ): Bool =
        Vector.range(start, stop) |> Vector.forAll(i ->
            Vector.get(i, perm) == i and Vector.get(i, ori) == 0)

    ///
    /// Whether every orientation from `start` up to `stop` is zero.
    ///
    def allZero(start: Int32, stop: Int32, ori: Vector[Int32]): Bool =
        Vector.range(start, stop) |> Vector.forAll(i -> Vector.get(i, ori) == 0)

    ///
    /// The case `c` is, with the turns that make its algorithm fit.
    ///
    /// Found by trying: every case, against every pair of `U` turns before and
    /// after, until one solves the cube. That is 21 by 4 by 4 replays of about
    /// fifteen moves, which costs less than deriving a case index and cannot be
    /// subtly wrong -- an answer is returned only after it has been seen to
    /// work on the cube in hand.
    ///
    pub def recognize(c: Cube.Cube): Result[String, Solution] =
        match precondition(c) {
            case Some(why) => Err(why)
            case None      =>
                match tryCases(c, all() |> Vector.toList) {
                    case Some(found) => Ok(found)
                    case None        =>
                        Err("the last layer is oriented and the rest is solved, but "
                            + "no recorded case solves it: this is a PLL state the "
                            + "collection does not have")
                }
        }

    ///
    /// The first recorded case that solves `c`, if any does.
    ///
    def tryCases(c: Cube.Cube, cases: List[Case]): Option[Solution] =
        match cases {
            case Nil          => None
            case one :: rest  =>
                match tryAufs(c, one, aufPairs()) {
                    case Some(found) => Some(found)
                    case None        => tryCases(c, rest)
                }
        }

    ///
    /// The first pair of `U` turns that makes `one` solve `c`.
    ///
    def tryAufs(c: Cube.Cube, one: Case, pairs: List[(Int32, Int32)]): Option[Solution] =
        match pairs {
            case Nil                    => None
            case (setup, finish) :: rest =>
                let written = sequenceOf(setup, algorithm(one), finish);
                if (solvesIt(c, written))
                    Notation.parse(3, written)
                        |> Result.toOption
                        |> Option.map(ops -> answer(one, setup, finish, written, ops))
                else
                    tryAufs(c, one, rest)
        }

    ///
    /// The answer to hand back once a sequence has been seen to work.
    ///
    def answer(
        one: Case,
        setup: Int32,
        finish: Int32,
        written: String,
        ops: List[Notation.Op]
    ): Solution =
        {
            caseName = name(one),
            algorithm = algorithm(one),
            setup = setup,
            finish = finish,
            sequence = written,
            ops = ops,
            optimalHtm = optimalHtm(one),
            source = source()
        }

    ///
    /// Whether `written` solves `c`.
    ///
    def solvesIt(c: Cube.Cube, written: String): Bool =
        Cube.applyNotation(written, c)
            |> Result.map(Cube.isSolved)
            |> Result.getWithDefault(false)

    ///
    /// The whole sequence: the setup turn, the algorithm, the finishing turn.
    ///
    def sequenceOf(setup: Int32, alg: String, finish: Int32): String =
        String.trim("${aufOf(setup)} ${alg} ${aufOf(finish)}")

    ///
    /// `k` quarter turns of `U`, written.
    ///
    pub def aufOf(k: Int32): String = match Int32.modulo(k, 4) {
        case 1 => "U"
        case 2 => "U2"
        case 3 => "U'"
        case _ => ""
    }

    ///
    /// Every pair of setup and finishing turns, in a fixed order.
    ///
    /// Fixed so that recognition is deterministic: a case that more than one
    /// pair would solve always comes back the same way.
    ///
    def aufPairs(): List[(Int32, Int32)] =
        let finishes = setup -> List.range(0, 4) |> List.map(finish -> (setup, finish));
        List.range(0, 4) |> List.flatMap(finishes)

    ///
    /// The 21 cases.
    ///
    /// Retrieved 2026-08-30 from the page `source` names. Each algorithm is the
    /// first listed under that case's "Speedsolving Algorithms", so it is a
    /// speed-oriented choice rather than a shortest one; `optimalHtm` records
    /// what the same page gives as optimal, and the two differ for most cases.
    ///
    pub def all(): Vector[Case] = Vector#{
        Case("A-PLL a", "(U') x R' U R' D2 R U' R' D2 R2 x'", 9),
        Case("Ab-PLL", "(U') x R2' D2 R U R' D2 R U' R x'", 9),
        Case("E-PLL", "(U) x' R U' R' D R U R' D' R U R' D R U' R' D' x", 14),
        Case("F-PLL", "y L R2 U R U R2 U' R' U' R2 U' R U2 L' U R'", 14),
        Case("G-PLL a", "(y) R2 U (R' U R' U') R U' R2 (D U' R' U) R D'", 12),
        Case("G-PLL b", "R' U' R U D' R2 U R' U R U' R U' R2 D", 12),
        Case("G-PLL c", "(y) R2 U' R U' R U R' U R2 D' U R U' R' D", 12),
        Case("G-PLL d", "(y2) R U R' U' D R2 U' R U' R' U R' U R2 D'", 12),
        Case("H-PLL, X-PLL", "M2' U M2' U2 M2' U M2'", 10),
        Case("J-PLL a, L-perm", "(y2) x R2' F R F' R U2 r' U r U2 x'", 10),
        Case("J-PLL b", "(y2) R' U L U' R U2' L' U L U2 L'", 10),
        Case("N-PLL a", "(r' D r U2)5", 13),
        Case("N-PLL b", "(r D r' U2)5", 13),
        Case("R-PLL a", "(y') R U' R' U' R U R D R' U' R D' R' U2 R'", 13),
        Case("R-PLL b", "R' U2 R U2 R' F (R U R' U') R' F' R2' U'", 13),
        Case("T-PLL", "R U R' U' R' F R2 U' R' U' R U R' F'", 10),
        Case("U-PLL a", "R U R' U R' U' R2 U' R' U R' U R", 9),
        Case("U-PLL b", "R' U R' U' R3 U' R' U R U R2", 9),
        Case("V-PLL", "(y) R U' R U R' D R D' R U' D R2 U R2 D' R2", 14),
        Case("Y-PLL", "R' U' R U' L R U2 R' U' R U2 L' U R2 U R", 13),
        Case("Z-PLL", "(U) M' U M2' U M2' U M' U2 M2'", 12)
    }

}
