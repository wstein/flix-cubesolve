///
/// Orientation of the Last Layer, the step before `CubeSolve.Method.Pll`.
///
/// The second human method here, and the same shape as the first: recognise a
/// constrained partial state, then play back an algorithm somebody memorised
/// for it. Nothing in the solver calls it and `Solve.Standard` is unchanged.
///
/// **OLL finishes where PLL begins.** Its goal is that the first two layers are
/// solved and the last layer shows the top colour, which is exactly PLL's
/// precondition; both ask `CubeSolve.Method.LastLayer`, so the two steps cannot
/// come to disagree about the boundary between them.
///
/// **Only a setup turn, where PLL has two.** A `U` turn before the algorithm
/// decides which way the case is facing. There is no finishing turn because a
/// `U` turn cannot change whether a piece shows the top colour, so once the
/// layer is oriented it stays oriented however it is spun -- and where the
/// pieces end up is the next step's business, not this one's.
///
/// **One algorithm per case, and not claimed to be the fastest.** The source
/// lists several for most of them.
///
mod CubeSolve.Method.Oll {

    use CubeSolve.Method.LastLayer
    use CubeSolve.Method.Oll.Case.Case
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation

    ///
    /// One case: the names it goes by, and an algorithm that orients it.
    ///
    /// The names are as the source gives them, aliases and all -- most cases
    /// have several and cubers do not agree on one, so recording a single
    /// invented name would make the corpus harder to search rather than
    /// tidier.
    ///
    pub enum Case with Eq, ToString {
        case Case(String, String)
    }

    ///
    /// The names this case goes by.
    ///
    pub def name(c: Case): String = let Case(n, _) = c; n

    ///
    /// The algorithm recorded for it. Speed-oriented rather than shortest.
    ///
    pub def algorithm(c: Case): String = let Case(_, a) = c; a

    ///
    /// Where these came from.
    ///
    pub def source(): String =
        "https://www.speedsolving.com/wiki/index.php?title=OLL"

    ///
    /// What a recognised cube turned out to be.
    ///
    /// `setup` is quarter turns of `U`, zero to three. `ops` is the parsed
    /// sequence: a list of moves would not do, because published algorithms
    /// contain whole-cube rotations and wide turns, and dropping those changes
    /// what the sequence does.
    ///
    pub type alias Solution = {
        caseName = String,
        algorithm = String,
        setup = Int32,
        sequence = String,
        ops = List[Notation.Op],
        source = String
    }

    ///
    /// Why `c` is not an OLL case, or nothing if it is one.
    ///
    /// A last layer that is already oriented is refused rather than answered.
    /// It is a real state and a good one to be in, but there is no OLL case for
    /// it -- every algorithm here would break it -- and the honest answer names
    /// the step it is ready for instead.
    ///
    pub def precondition(c: Cube.Cube): Option[String] =
        match LastLayer.faultBelowTheTop(c) {
            case Some(why) => Some(why)
            case None      =>
                if (LastLayer.topIsOriented(c))
                    Some("the last layer is already oriented, so there is no OLL "
                        + "case here: this is where PLL starts")
                else
                    None
        }

    ///
    /// The case `c` is, with the turn that makes its algorithm fit.
    ///
    /// Found by trying every case against every setup turn and checking the
    /// result, so an answer is returned only after it has been applied to the
    /// cube in hand and seen to orient the layer. That is 57 by 4 replays of
    /// about ten moves, and it cannot be subtly wrong the way a derived case
    /// index can.
    ///
    pub def recognize(c: Cube.Cube): Result[String, Solution] =
        match precondition(c) {
            case Some(why) => Err(why)
            case None      =>
                match tryCases(c, all() |> Vector.toList) {
                    case Some(found) => Ok(found)
                    case None        =>
                        Err("the first two layers are solved and the last layer is "
                            + "not oriented, but no recorded case orients it: this "
                            + "is an OLL state the collection does not have")
                }
        }

    ///
    /// The first recorded case that orients `c`, if any does.
    ///
    def tryCases(c: Cube.Cube, cases: List[Case]): Option[Solution] =
        match cases {
            case Nil         => None
            case one :: rest =>
                match trySetups(c, one, List.range(0, 4)) {
                    case Some(found) => Some(found)
                    case None        => tryCases(c, rest)
                }
        }

    ///
    /// The first setup turn that makes `one` orient `c`.
    ///
    def trySetups(c: Cube.Cube, one: Case, setups: List[Int32]): Option[Solution] =
        match setups {
            case Nil            => None
            case setup :: rest  =>
                let written = String.trim("${aufOf(setup)} ${algorithm(one)}");
                if (orientsIt(c, written))
                    Notation.parse(3, written)
                        |> Result.toOption
                        |> Option.map(ops -> answer(one, setup, written, ops))
                else
                    trySetups(c, one, rest)
        }

    ///
    /// The answer to hand back once a sequence has been seen to work.
    ///
    def answer(
        one: Case,
        setup: Int32,
        written: String,
        ops: List[Notation.Op]
    ): Solution =
        {
            caseName = name(one),
            algorithm = algorithm(one),
            setup = setup,
            sequence = written,
            ops = ops,
            source = source()
        }

    ///
    /// Whether `written` leaves `c` with its first two layers solved and its
    /// last layer oriented.
    ///
    /// Both halves are checked. Orienting the top while disturbing what is below
    /// it is not what an OLL algorithm does, and a corpus entry that did would
    /// hand back an answer that ruins the solve.
    ///
    def orientsIt(c: Cube.Cube, written: String): Bool =
        match Cube.applyNotation(written, c) {
            case Err(_)    => false
            case Ok(after) =>
                Option.isEmpty(LastLayer.faultBelowTheTop(after))
                    and LastLayer.topIsOriented(after)
        }

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
    /// The 57 cases.
    ///
    /// Retrieved 2026-08-30 from the page `source` names, together with the
    /// `OCLL` template it includes for the seven corner-only cases. Each
    /// algorithm is the first listed for that case, so it is a speed-oriented
    /// choice rather than a shortest one.
    ///
    /// Split in two only because one definition of 57 rows is longer than this
    /// project lets a definition be; the halves have no meaning.
    ///
    pub def all(): Vector[Case] = Vector.append(firstHalf(), secondHalf())

    ///
    /// Cases 1 to 29; see `all`.
    ///
    def firstHalf(): Vector[Case] = Vector#{
        Case("Runway, Blank", "R U2' R2' F R F' U2 R' F R F'"),
        Case("Zamboni", "(U') R U' R2' D' r U r' D R2 U R'"),
        Case("Anti-Pinwheel, Anti-Mouse", "(U) f (R U R' U') f' U' F (R U R' U') F'"),
        Case("Pinwheel, Mouse", "f R U R' U' f' U F R U R' U' F'"),
        Case("Slash, Diagonal", "R U R' U R' F R F' U2 R' F R F'"),
        Case("Crown", "R U2 R2 F R F' U2 M' U R U' r'"),
        Case("Bunny", "S' R U R' S U' R' F R F'"),
        Case("X, Checkers", "r' R U R U R' U' r R' M' U R U' r'"),
        Case("Couch", "(U2) R' U' F U R U' R' F' R"),
        Case("Anti-Couch", "S R U R' U' R' F R f'"),
        Case("Anti-P", "(U) R' U' F' U F R"),
        Case("P", "(U2) F (U R U' R') F'"),
        Case("Sea-Mew, Wario, Anti-Moustache", "(U2) L' U' L U' L' U L U L F' L' F"),
        Case("Mario, Moustache", "(U2) R U R' U R U' R' U' R' F R F'"),
        Case("Breakneck", "F R U R' U' R U R' U' F'"),
        Case("Anti-Breakneck", "(U') F R' F' R U2 R U' R' U R U2' R'"),
        Case("Frying Pan", "l' U' L U' L' U L U' L' U2 l"),
        Case("Anti-Frying Pan", "r U R' U R U' R' U R U2' r'"),
        Case("Right back squeezy", "(U2) r U' r2' U r2 U r2' U' r"),
        Case("Right front squeezy", "(U2) R' F R2 B' R2' F' R2 B R'"),
        Case("City (C and T)", "R U R2' U' R' F R U R U' F'"),
        Case("Seein' Headlights (C and headlights)", "R' U' R' F R F' U R"),
        Case("Tying Shoelaces, Key", "R U R' U' R' F R F'"),
        Case("Suit up, T", "F R U R' U' F'"),
        Case("Highway, Freeway", "(U) R' F R U R U' R2' F' R2 U' R' U R U R'"),
        Case("Streetlights, Dead Man", "r U r' U R U' R' U R U' R' r U' r'"),
        Case("Bottlecap, Ant", "F U R U' R' U R U' R' F'"),
        Case("Rice Cooker", "R U R' U R U' B U' B' R'"),
        Case("Right back wide antisune (RBWAS), Lefty Square", "(U2) l' U2 L U L' U l")
    }

    ///
    /// Cases 30 to 57; see `all`.
    ///
    def secondHalf(): Vector[Case] = Vector#{
        Case("Right front wide antisune (RFWAS), Righty Square", "(U2) r U2 R' U' R U' r'"),
        Case("Fung", "L F' L' U' L U F U' L'"),
        Case("Anti-Fung", "R' F R U R' U' F' U R"),
        Case("Lightning, Wide Sune", "r U R' U R U2 r'"),
        Case("Wide Left Sune, Reverse Lightning", "l' U' L U' L' U2 l"),
        Case("Downstairs", "(U') r' R2 U R' U R U2' R' U M'"),
        Case("Upstairs", "(U') r R2' U' R U' R' U2 R U' r' R"),
        Case("Kite", "(U') R U R' U' R' F R2 U R' U' F'"),
        Case("Anti-Kite", "(U') R U R' U R' F R F' R U2' R'"),
        Case("Fish Salad", "R U2' R2' F R F' R U2' R'"),
        Case("Mounted Fish, Untying Shoelaces", "(U) F R' F' R U R U' R'"),
        Case("Gun, Trigger", "F U R U2' R' U' R U R' F'"),
        Case("Anti-Gun, Anti-Trigger", "R' F R U R' F' R F U' F'"),
        Case("Squeegee", "(U2) l' U' l L' U' L U l' U l"),
        Case("Anti-Squeegee", "(U2) r U r' R U R' U' r U' r'"),
        Case("Spotted Chameleon", "(U) R U R' U' R U' R' F' U' F R U R'"),
        Case("Anti-Spotted Chameleon", "(U2) F U R U2' R' U' R U2 R' U' F'"),
        Case("Awkward Fish, Dalmation", "(U2) R U R' U R U2 R' F R U R' U' F'"),
        Case("Lefty Awkward Fish, Anti-Dalmation", "R' U' R U' R' U2' R F R U R' U' F'"),
        Case("Stealth, Arrow, Arrowhead, Fish", "r U R' U' r' R U R U' R'"),
        Case("Mummy, H, I, Brick", "R U R' U' M' U R U' r'"),
        Case("Sune, S, Swimming Left", "R U R' U R U2' R'"),
        Case("Antisune, AS, S-, Swimming Right", "(y') R U2 R' U' R U' R'"),
        Case("H, Double Sune, Flip, Cross", "R U R' U R U' R' U R U2 R'"),
        Case("Pi, Bruno, Wheel, T-shirt, Antarctica", "R U2' R2' U' R2 U' R2' U2' R"),
        Case("U, Headlights, Superman", "R2' D' R U2 R' D R U2 R"),
        Case("T, Chameleon, Shark, Hammerhead, Little Horse, Stingray", "r U R' U' r' F R F'"),
        Case("L, Bowtie, Triple-Sune, Side-winder, Diagonals, Spaceship",
            "(U2) F R' F' r U R U' r'")
    }


}
