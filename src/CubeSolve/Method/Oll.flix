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
    use CubeSolve.Method.Profile
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
        case Case(String, Vector[String])
    }

    ///
    /// The names this case goes by.
    ///
    pub def name(c: Case): String = let Case(n, _) = c; n

    ///
    /// Every algorithm recorded for this case, in source order.
    ///
    pub def variants(c: Case): Vector[String] = let Case(_, vs) = c; vs

    ///
    /// The algorithm a caller gets when it does not ask for a profile.
    ///
    pub def algorithm(c: Case): String = Vector.get(0, variants(c))

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
        choice = Profile.Choice,
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
    /// The case `c` is, using the algorithm the source lists first.
    ///
    pub def recognize(c: Cube.Cube): Result[String, Solution] =
        recognizeWith(Profile.Profile.SourceFirst, c)

    ///
    /// The case `c` is, with the algorithm `p` picks for it.
    ///
    /// The case is identified with the source's first algorithm, and the profile
    /// then chooses which to hand back. Every recorded variant orients its own
    /// case, so the choice cannot change which case this is, only how it is
    /// oriented. Its setup turn is worked out again for the chosen algorithm.
    ///
    pub def recognizeWith(p: Profile.Profile, c: Cube.Cube): Result[String, Solution] =
        match precondition(c) {
            case Some(why) => Err(why)
            case None      =>
                match identify(c, all() |> Vector.toList) {
                    case None      =>
                        Err("the first two layers are solved and the last layer is "
                            + "not oriented, but no recorded case orients it: this "
                            + "is an OLL state the collection does not have")
                    case Some(one) => finishWith(p, one, c)
                }
        }

    ///
    /// The first recorded case whose own algorithm orients `c`.
    ///
    def identify(c: Cube.Cube, cases: List[Case]): Option[Case] =
        match cases {
            case Nil         => None
            case one :: rest =>
                if (Option.isEmpty(fitting(c, algorithm(one))))
                    identify(c, rest)
                else
                    Some(one)
        }

    ///
    /// The answer, once the case is known and the profile has picked.
    ///
    def finishWith(p: Profile.Profile, one: Case, c: Cube.Cube): Result[String, Solution] =
        let choice = Profile.pick(p, variants(one));
        match fitting(c, choice#algorithm) {
            case None => Err("'${name(one)}' was recognised, but the algorithm the "
                + "profile picked does not orient it: this is a fault in the "
                + "collection")
            case Some(setup) =>
                let written = String.trim("${aufOf(setup)} ${choice#algorithm}");
                Notation.parse(3, written)
                    |> Result.map(ops -> {
                        caseName = name(one),
                        algorithm = choice#algorithm,
                        setup = setup,
                        sequence = written,
                        ops = ops,
                        choice = choice,
                        source = source()
                    })
        }

    ///
    /// The setup turn that makes `alg` orient `c`, if one does.
    ///
    def fitting(c: Cube.Cube, alg: String): Option[Int32] =
        List.range(0, 4)
            |> List.findLeft(setup -> orientsIt(c, String.trim("${aufOf(setup)} ${alg}")))

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
    /// The 57 cases, with every algorithm the source records for each.
    ///
    /// Retrieved 2026-08-30 from the page `source` names, together with the
    /// `OCLL` template it includes for the seven corner-only cases, taking every
    /// algorithm listed for each case in the order listed. One published
    /// algorithm was left out because it does not orient the case it is filed
    /// under -- see `docs/design-review.md`.
    ///
    pub def all(): Vector[Case] =
        Vector#{
            part1(),
            part2(),
            part3(),
            part4(),
            part5(),
            part6()
        } |> Vector.flatten

    ///
    /// Cases 1 to 8; see `all`.
    ///
    def part1(): Vector[Case] = Vector#{
        Case("Runway, Blank", Vector#{
            "R U2' R2' F R F' U2 R' F R F'",
            "(U) R U' R2 D' r U' r' D R2 U R'"
        }),
        Case("Zamboni", Vector#{
            "(U') R U' R2' D' r U r' D R2 U R'",
            "F R U R' U' S R U R' U' f'",
            "(U2) f U R U' R' S' U R U' R' F'"
        }),
        Case("Anti-Pinwheel, Anti-Mouse", Vector#{
            "(U) f (R U R' U') f' U' F (R U R' U') F'",
            "(U2) r' R2 U R' U r U2 r' U M'",
            "(U2) L' l U l' U2 l U L' U L M'",
            "(U') R' F2 R2 U2' R' F R U2' R2' F2 R"
        }),
        Case("Pinwheel, Mouse", Vector#{
            "f R U R' U' f' U F R U R' U' F'",
            "(U) l L2' U' L U' l' U2 l U' M'",
            "(U) R r' U' r U2 r' U' R U' R2' r",
            "R' F2 R2 U2' R' F' R U2' R2' F2 R"
        }),
        Case("Slash, Diagonal", Vector#{
            "R U R' U R' F R F' U2 R' F R F'",
            "(U2) F R' F' R U S' R U' R' S"
        }),
        Case("Crown", Vector#{
            "R U2 R2 F R F' U2 M' U R U' r'",
            "(U) R U R2 F' U' F U R U2' R' F R F'",
            "(U) F R U R' d R' U2 (R' F R F')",
            "(U') r U R' U R U2 r2' U' R U' R' U2 r"
        }),
        Case("Bunny", Vector#{
            "S' R U R' S U' R' F R F'",
            "(U') r' R U R U R' U' r R2 F R F'"
        }),
        Case("X, Checkers", Vector#{
            "r' R U R U R' U' r R' M' U R U' r'",
            "r U R' U' r R' M' U R U' R' U' M'",
            "S' R U R' S U' M' U R U' r'",
            "M U (R U R' U') M2' (U R U' r')"
        })
    }

    ///
    /// Cases 9 to 18; see `all`.
    ///
    def part2(): Vector[Case] = Vector#{
        Case("Couch", Vector#{
            "(U2) R' U' F U R U' R' F' R"
        }),
        Case("Anti-Couch", Vector#{
            "S R U R' U' R' F R f'",
            "(U2) L U F' U' L' U L F L'",
            "R U B' U' R' U R B R'"
        }),
        Case("Anti-P", Vector#{
            "(U) R' U' F' U F R"
        }),
        Case("P", Vector#{
            "(U2) F (U R U' R') F'",
            "f (R U R' U') f'"
        }),
        Case("Sea-Mew, Wario, Anti-Moustache", Vector#{
            "(U2) L' U' L U' L' U L U L F' L' F",
            "(U2) R U R' F' R U R' U' R' F R U' R' F R F'",
            "(U2) R' F' U' F2 U R U' R' F' R",
            "(U) R U R2' F' U' F U R2 U2' R'"
        }),
        Case("Mario, Moustache", Vector#{
            "(U2) R U R' U R U' R' U' R' F R F'"
        }),
        Case("Breakneck", Vector#{
            "F R U R' U' R U R' U' F'"
        }),
        Case("Anti-Breakneck", Vector#{
            "(U') F R' F' R U2 R U' R' U R U2' R'",
            "R' U' R' F R F' R' F R F' U R",
            "F' L' U' L U L' U' L U F",
            "(U') R' F' U' F U F' U' F U R"
        }),
        Case("Frying Pan", Vector#{
            "l' U' L U' L' U L U' L' U2 l",
            "(U') r' U2' R U R' U' R U R' U r",
            "(U2) r' U' R U' R' U R U' R' U2 r"
        }),
        Case("Anti-Frying Pan", Vector#{
            "r U R' U R U' R' U R U2' r'",
            "(U') r U2' R' U' R U R' U' R U' r'"
        })
    }

    ///
    /// Cases 19 to 28; see `all`.
    ///
    def part3(): Vector[Case] = Vector#{
        Case("Right back squeezy", Vector#{
            "(U2) r U' r2' U r2 U r2' U' r",
            "R B' R2' F R2 B R2' F' R"
        }),
        Case("Right front squeezy", Vector#{
            "(U2) R' F R2 B' R2' F' R2 B R'",
            "r' U r2 U' r2' U' r2 U r'"
        }),
        Case("City (C and T)", Vector#{
            "R U R2' U' R' F R U R U' F'",
            "R U R' U' y l' U' L U L' l",
            "(U') f R f' U' r' U' R U M'"
        }),
        Case("Seein' Headlights (C and headlights)", Vector#{
            "R' U' R' F R F' U R"
        }),
        Case("Tying Shoelaces, Key", Vector#{
            "R U R' U' R' F R F'"
        }),
        Case("Suit up, T", Vector#{
            "F R U R' U' F'"
        }),
        Case("Highway, Freeway", Vector#{
            "(U) R' F R U R U' R2' F' R2 U' R' U R U R'",
            "(U) R' F U R U' R2' F' R2 U R' U' R",
            "(U) r U2' R' U' r' R2 U R' U' r U' r'"
        }),
        Case("Streetlights, Dead Man", Vector#{
            "r U r' U R U' R' U R U' R' r U' r'",
            "r U r' U R U' R' M' U R U2' r'"
        }),
        Case("Bottlecap, Ant", Vector#{
            "F U R U' R' U R U' R' F'",
            "(U2) f R U R' U' R U R' U' f'"
        }),
        Case("Rice Cooker", Vector#{
            "R U R' U R U' B U' B' R'",
            "(U2) R' F' U' F U' R U R' U R"
        })
    }

    ///
    /// Cases 29 to 39; see `all`.
    ///
    def part4(): Vector[Case] = Vector#{
        Case("Right back wide antisune (RBWAS), Lefty Square", Vector#{
            "(U2) l' U2 L U L' U l",
            "r' U2' R U R' U r"
        }),
        Case("Right front wide antisune (RFWAS), Righty Square", Vector#{
            "(U2) r U2 R' U' R U' r'"
        }),
        Case("Fung", Vector#{
            "L F' L' U' L U F U' L'",
            "(U2) R U R' F' U' F U R U2' R'",
            "(U2) f' r U r' U' r' F r S"
        }),
        Case("Anti-Fung", Vector#{
            "R' F R U R' U' F' U R"
        }),
        Case("Lightning, Wide Sune", Vector#{
            "r U R' U R U2 r'"
        }),
        Case("Wide Left Sune, Reverse Lightning", Vector#{
            "l' U' L U' L' U2 l",
            "(U2) r' U' R U' R' U2 r",
            "R U2' R' U2 R' F R F'"
        }),
        Case("Downstairs", Vector#{
            "(U') r' R2 U R' U R U2' R' U M'",
            "(U) r U R' U R' F R F' R U2' r'"
        }),
        Case("Upstairs", Vector#{
            "(U') r R2' U' R U' R' U2 R U' r' R",
            "(U) l L2' U' L U' L' U2 L U' M'"
        }),
        Case("Kite", Vector#{
            "(U') R U R' U' R' F R2 U R' U' F'"
        }),
        Case("Anti-Kite", Vector#{
            "(U') R U R' U R' F R F' R U2' R'",
            "F U F' R' F R U' R' F' R"
        }),
        Case("Fish Salad", Vector#{
            "R U2' R2' F R F' R U2' R'"
        })
    }

    ///
    /// Cases 40 to 49; see `all`.
    ///
    def part5(): Vector[Case] = Vector#{
        Case("Mounted Fish, Untying Shoelaces", Vector#{
            "(U) F R' F' R U R U' R'"
        }),
        Case("Gun, Trigger", Vector#{
            "F U R U2' R' U' R U R' F'",
            "F U R U' R2' F' R U R U' R'",
            "r U' r' U' r U r' F' U F"
        }),
        Case("Anti-Gun, Anti-Trigger", Vector#{
            "R' F R U R' F' R F U' F'"
        }),
        Case("Squeegee", Vector#{
            "(U2) l' U' l L' U' L U l' U l",
            "r' U' r R' U' R U r' U r"
        }),
        Case("Anti-Squeegee", Vector#{
            "(U2) r U r' R U R' U' r U' r'"
        }),
        Case("Spotted Chameleon", Vector#{
            "(U) R U R' U' R U' R' F' U' F R U R'",
            "(U) R U R' U' R' F R F' R U R' U' M' U R U' r'",
            "r2' D' r U r' D r2 U' r' U' r"
        }),
        Case("Anti-Spotted Chameleon", Vector#{
            "(U2) F U R U2' R' U' R U2 R' U' F'",
            "(U') r' D' r U' r' D r2 U' r' U r U r'",
            "(U2) F R' F R2 U' R' U' R U R' F2'"
        }),
        Case("Awkward Fish, Dalmation", Vector#{
            "(U2) R U R' U R U2 R' F R U R' U' F'"
        }),
        Case("Lefty Awkward Fish, Anti-Dalmation", Vector#{
            "R' U' R U' R' U2' R F R U R' U' F'",
            "R' U' R U' R' U2' R U R' F' U' F U R",
            "(U) R' F R F' R' F R F' R U R' U' R U R'",
            "(U) F R' F' R U2 R' U' R2 U' R2' U2' R"
        }),
        Case("Stealth, Arrow, Arrowhead, Fish", Vector#{
            "r U R' U' r' R U R U' R'",
            "U2 (M' U l L') U2 (M' U l L')",
            "U2 (M' U M) U2 (M' U M)"
        })
    }

    ///
    /// Cases 50 to 57; see `all`.
    ///
    def part6(): Vector[Case] = Vector#{
        Case("Mummy, H, I, Brick", Vector#{
            "R U R' U' M' U R U' r'"
        }),
        Case("Sune, S, Swimming Left", Vector#{
            "R U R' U R U2' R'",
            "(U') R' U2' R U R' U R"
        }),
        Case("Antisune, AS, S-, Swimming Right", Vector#{
            "(y') R U2 R' U' R U' R'",
            "(U2) R' U' R U' R' U2 R",
            "(U') R U2' R' U' R U' R'",
            "L' U' L U' L' U2 L"
        }),
        Case("H, Double Sune, Flip, Cross", Vector#{
            "R U R' U R U' R' U R U2 R'",
            "(U) R U2' R' U' R U R' U' R U' R'",
            "U F (R U R' U')3 F'"
        }),
        Case("Pi, Bruno, Wheel, T-shirt, Antarctica", Vector#{
            "R U2' R2' U' R2 U' R2' U2' R",
            "f (R U R' U') S' (R U R' U') F'"
        }),
        Case("U, Headlights, Superman", Vector#{
            "R2' D' R U2 R' D R U2 R",
            "(U2) R2 D R' U2 R D' R' U2 R'",
            "(R U R' U')3 (R' F R F')3"
        }),
        Case("T, Chameleon, Shark, Hammerhead, Little Horse, Stingray", Vector#{
            "r U R' U' r' F R F'",
            "(U2) l' U' L U l F' L' F"
        }),
        Case("L, Bowtie, Triple-Sune, Side-winder, Diagonals, Spaceship", Vector#{
            "(U2) F R' F' r U R U' r'",
            "(U') F' r U R' U' r' F R",
            "(F R B R') (F' R B' R')",
            "(F l U l') (F' l U' l')"
        })
    }



}
