///
/// Permutation of the Last Layer, the final step of the CFOP method.
///
/// **A human method, not a search.** `CubeSolve.Solve.Standard` answers any cube
/// with a short sequence found by looking; this answers one particular partial
/// state by recognising it and playing back an algorithm a person has memorised.
/// A PLL answer is longer than an optimal one and is not offered as a solution
/// to an arbitrary cube. Nothing in the solver calls this, and
/// `Standard.solution` is unchanged.
///
/// **The precondition is checked from decoded model state**, never assumed: the
/// first two layers solved and the last layer oriented, which is exactly where
/// `CubeSolve.Method.Oll` finishes. Both ask `CubeSolve.Method.LastLayer`.
///
/// **AUF is part of the answer.** The same case arrives turned any of four ways
/// and its algorithm assumes one, so recognition reports the `U` turn to make
/// before and the one after. Both are found by replaying: an answer is returned
/// only after it has been applied to the cube in hand and seen to solve it.
///
/// **Several algorithms per case, and none of them called fastest.** The source
/// lists many and says a longer one can be quicker for a given person, so which
/// is best is not a fact this module holds. `CubeSolve.Method.Profile` picks
/// among them by a stated rule and says which rule it applied.
///
mod CubeSolve.Method.Pll {

    use CubeSolve.Method.LastLayer
    use CubeSolve.Method.Pll.Case.Case
    use CubeSolve.Method.Profile
    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation

    ///
    /// One case: the name it is known by, the shortest anyone has published for
    /// it in the half-turn metric, and every algorithm the source records, in
    /// the order it records them.
    ///
    pub enum Case with Eq, ToString {
        case Case(String, Int32, Vector[String])
    }

    ///
    /// The name this case is known by.
    ///
    pub def name(c: Case): String = let Case(n, _, _) = c; n

    ///
    /// The shortest published length for this case, in HTM.
    ///
    /// Recorded so the gap between a chosen algorithm and the optimum is visible
    /// rather than implied.
    ///
    pub def optimalHtm(c: Case): Int32 = let Case(_, h, _) = c; h

    ///
    /// Every algorithm recorded for this case, in source order.
    ///
    pub def variants(c: Case): Vector[String] = let Case(_, _, vs) = c; vs

    ///
    /// The algorithm a caller gets when it does not ask for a profile.
    ///
    pub def algorithm(c: Case): String = Vector.get(0, variants(c))

    ///
    /// Where these came from.
    ///
    pub def source(): String =
        "https://www.speedsolving.com/wiki/index.php?title=PLL"

    ///
    /// An algorithm made to fit a cube: the turns around it, and the whole
    /// sequence they make.
    ///
    type alias Fit = { setup = Int32, finish = String, sequence = String }

    ///
    /// What a recognised cube turned out to be.
    ///
    /// `setup` is quarter turns of `U` before the algorithm, zero to three.
    /// `finish` is the turn after it, **written** rather than counted, because
    /// it is not always a `U` turn: an algorithm that leaves the cube rotated
    /// finishes with whatever face the original top layer is now showing on.
    /// `sequence` is the whole thing to execute. `ops` is the parsed sequence --
    /// a list of moves would not do, because published algorithms contain
    /// whole-cube rotations and dropping those changes what the sequence does.
    /// `choice` records which algorithm was picked and why.
    ///
    pub type alias Solution = {
        caseName = String,
        algorithm = String,
        setup = Int32,
        finish = String,
        sequence = String,
        ops = List[Notation.Op],
        optimalHtm = Int32,
        choice = Profile.Choice,
        source = String
    }

    ///
    /// Why `c` is not a PLL case, or nothing if it is one.
    ///
    pub def precondition(c: Cube.Cube): Option[String] =
        match LastLayer.faultBelowTheTop(c) {
            case Some(why) => Some(why)
            case None      =>
                if (LastLayer.topIsOriented(c))
                    None
                else
                    Some("the last layer is not oriented: a top piece does not show "
                        + "the top colour, so this is an OLL case rather than a PLL "
                        + "one")
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
    /// then chooses which to hand back. Every recorded variant solves its own
    /// case -- that is checked for all of them -- so the choice cannot change
    /// which case this is, only how it is finished. Its `U` turns are worked out
    /// again for the chosen algorithm, because a different algorithm generally
    /// wants different ones.
    ///
    pub def recognizeWith(p: Profile.Profile, c: Cube.Cube): Result[String, Solution] =
        match precondition(c) {
            case Some(why) => Err(why)
            case None      =>
                match identify(c, all() |> Vector.toList) {
                    case None      =>
                        Err("the last layer is oriented and the rest is solved, but "
                            + "no recorded case solves it: this is a PLL state the "
                            + "collection does not have")
                    case Some(one) => finishWith(p, one, c)
                }
        }

    ///
    /// The first recorded case whose own algorithm solves `c`.
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
                + "profile picked does not fit it: this is a fault in the collection")
            case Some(fit) =>
                Notation.parse(3, fit#sequence)
                    |> Result.map(ops -> {
                        caseName = name(one),
                        algorithm = choice#algorithm,
                        setup = fit#setup,
                        finish = fit#finish,
                        sequence = fit#sequence,
                        ops = ops,
                        optimalHtm = optimalHtm(one),
                        choice = choice,
                        source = source()
                    })
        }

    ///
    /// The whole sequence that solves `c`, if `alg` can be made to.
    ///
    /// **The finishing turn is named in the frame the algorithm leaves.** Most
    /// published algorithms put the cube back the way they found it, but some do
    /// not -- Y-PLL's shortest recorded algorithm contains an `x` and no `x'`,
    /// so it ends with the cube on its side. A `U` written after that turns
    /// whatever face is now uppermost, which is not the layer the AUF is about,
    /// and no pair of plain `U` turns would ever solve those cases. So the turn
    /// is worked out for the frame the solver is actually holding, and may come
    /// out as `F2` or `L'` rather than `U2`.
    ///
    def fitting(c: Cube.Cube, alg: String): Option[Fit] =
        List.range(0, 4) |> List.findMap(setup -> {
            let started = String.trim("${aufOf(setup)} ${alg}");
            match Cube.applyNotation(started, c) {
                case Err(_)    => None
                case Ok(after) => closing(c, setup, started, after)
            }
        })

    ///
    /// The finishing turn that solves it, named for how the cube is now held.
    ///
    def closing(
        c: Cube.Cube,
        setup: Int32,
        started: String,
        after: Cube.Cube
    ): Option[Fit] =
        List.range(0, 4) |> List.findMap(finish -> {
            let turn = topTurn(finish, after);
            let written = String.trim("${started} ${turn}");
            if (solvesIt(c, written))
                Some({ setup = setup, finish = turn, sequence = written })
            else
                None
        })

    ///
    /// `k` quarter turns of the layer that started on top, written for the frame
    /// `after` is in.
    ///
    def topTurn(k: Int32, after: Cube.Cube): String =
        if (Int32.modulo(k, 4) == 0)
            ""
        else
            LastLayer.topTurnWritten(k, Cube.orientation(after))

    ///
    /// Whether `written` solves `c`.
    ///
    def solvesIt(c: Cube.Cube, written: String): Bool =
        Cube.applyNotation(written, c)
            |> Result.map(Cube.isSolved)
            |> Result.getWithDefault(false)

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
    /// The 21 cases, with every algorithm the source records for each.
    ///
    /// Retrieved 2026-08-30 from the page `source` names, taking both the
    /// "Speedsolving Algorithms" and the "Optimal Algorithms" listed under each
    /// case, in that order. Seven published algorithms were left out because
    /// they do not solve the case they are filed under -- see
    /// `docs/design-review.md`.
    ///
    pub def all(): Vector[Case] =
        Vector#{
            part1(),
            part2(),
            part3(),
            part4(),
            part5(),
            part6(),
            part7(),
            part8(),
            part9(),
            part10(),
            part11()
        } |> Vector.flatten

    ///
    /// Cases 1 to 2; see `all`.
    ///
    def part1(): Vector[Case] = Vector#{
        Case("F-PLL", 14, Vector#{
            "y L R2 U R U R2 U' R' U' R2 U' R U2 L' U R'",
            "(y) R' U' F' (R U R' U') R' F R2 (U' R' U') R U R' U R",
            "(y x) R' B' U' l U R' U' R' F R2 U' R' U' R U R' U R",
            "y2 R' U2 R' d' R' F' R2 U' R' U R' F R U' F",
            "M' U2 L F' R U2 r' U r' R2 U2 R2",
            "(R' U R U') R2 (F' U' F U) (R F R' F') R2 U'",
            "(R' U R U')(R' l')(d' R' d B)(R U R' U')(R l)",
            "(y) R2 (F R F' R') (U' F' U F) R2 (U R' U' R) U",
            "R' U R U' R2 (y') R' U' R U (y x) R U R' U' R2 (x')",
            "(y2) R' U2 R' d' R' F' R2 U' R' U R' F R U' F",
            "(y') F r2 R' U2 r U' r' U2 (x') R2 U' R' U r2 u' (z')",
            "B' U' R' B U B' U' B' R B2 U' B' U' B U B' U B",
            "(y) R' U' F' R U R' U' R' F R2 U' R' U' R U R' U R",
            "L U' L' U L2 F U F' U' L' F' L F L2 U",
            "(y2) R U' R' U R2 (y) R U R' U' (x) U' R' U R U2 (x')",
            "(y' z) R U R' U' R U2 (z' y') R U R' U' (y' x') R' U' R U R2 (x)",
            "L F R' F' L' F' D2 B' L' B D2 F' R F2",
            "R' U2 R U' R' f' U' R U2 R' U' R U' R' f U' R",
            "(y) R2 B2 R2 L U' L F2 R' D L' F2 R L'",
            "(y) R2 B2 R2 L U' L F2 R' D L' F2 M (x)",
            "(y) R R F R F' R' U' F' U F R R U R' U' R",
            "R' F' U' S' R U R' S U' R' F R' B' R' B"
        }),
        Case("G-PLL a", 12, Vector#{
            "(y) R2 U (R' U R' U') R U' R2 (D U' R' U) R D'",
            "(y) R2' u (R' U R' U' R) u' R2 (y') R' U R",
            "(y) R2 U (R' U R' U' R) U' R2 D (U' R' U R) D'",
            "(y2) F2' D (R' U R' U' R) D' F2 L' U L",
            "R L U2 R' L' (y') R' U L' U2 R U' L",
            "R U2' R' U' F' R U R2 U' R' F R U R2 U2' R'",
            "(R U R' U' R') U F (R U R U' R') F' U R' U2 R",
            "(y2 z) U R U' R' U' R B U R U R' U' B' R U' R2 U (z' y2')",
            "(y) L F2 R (F' L' F U) R' U' (F' L F' L')",
            "(y) R2' S2 U l2' U' l2' u R2 U' r2' F2",
            "(y) F B U2 F' B' L' U R' U2 L U' R",
            "(y') L2 S2 D F2 D' F2 U F2 U' B2 R2 (z2)",
            "(y') L L D F' U F' U' F D' L L B' U B"
        })
    }

    ///
    /// Cases 3 to 4; see `all`.
    ///
    def part2(): Vector[Case] = Vector#{
        Case("G-PLL b", 12, Vector#{
            "R' U' R U D' R2 U R' U R U' R U' R2 D",
            "R' U' R (y) R2 u (R' U R U' R) u' R2",
            "(y) F' U' F R2 u (R' U R U' R) u' R2'",
            "(y2) R' U2 R U' F R U R' U' R' F' U' R U R U' R' (y2')",
            "R' U' R B2 D (L' U L U' L) D' B2",
            "(y2) L' U' L (y') R2' u (R' U R U' R) u' R2",
            "(y') R' U L' U2 R U' L (y) R L U2 L' R'",
            "R2 D L2 D F2 L D R' D2 L D' R' U2",
            "(y) R2 F2 U R2 D' R2 D B2 U' F2 B2 R2",
            "(y) R2 F2 U R2 D' R2 D B2 U' S2 L2 (z2)",
            "R' U' R B B D L' U L U' L D' B B"
        }),
        Case("G-PLL c", 12, Vector#{
            "(y) R2 U' R U' R U R' U R2 D' U R U' R' D",
            "(y') R2 F2 R U2 R U2 R' F R U R' U' R' F R2",
            "(y) R2' u' (R U' R U R') u R2 (y) R U' R'",
            "(y) R2' u' (R U' R U R') u R2 B U' B'",
            "(y) R2' U' (R U' R U R') U R2 (D' U R U' R' D)",
            "(y) R2' D' F U' F U F' D R2 B U' B'",
            "(y2) F2' D' L U' L U L' D F2 R U' R'",
            "L' U' L U L U' F' L' U' L' U L F U' L U2 L'",
            "(y2) R' U' R U R U' B' R' U' R' U R B U' R U2 R' (y2')",
            "(z) U' R' U R U R' F' U' R' U' R U F R' U R2 U' (z')",
            "L' R' U2 L R (y) L U' R U2 L' U R'",
            "(y') R2' F2 R U2 R U2 R' F R U R' U' R' F R2",
            "(y') l' U2' L' U l F' U' L U F R' F R",
            "(y) U F2 R2 L2 U' L2 U L2 D' L2 D R2 F2 U'",
            "(y') (z)  U2 (r' U R' U R U' r) U2 F R' F' (z') (y)",
            "B2 R2 L2 U' R2 U R2 D' R2 D L2 B2",
            "B2 M2 D' R2 D R2 U' R2 U L2 F2 (x2)",
            "F' L L B' L F L' U' B U L F' L F"
        })
    }

    ///
    /// Cases 5 to 5; see `all`.
    ///
    def part3(): Vector[Case] = Vector#{
        Case("G-PLL d", 12, Vector#{
            "(y2) R U R' U' D R2 U' R U' R' U R' U R2 D'",
            "(y2) D' R U R' U' D R2 U' R U' R' U R' U R2",
            "(y2) R U R' (y') R2 u' (R U' R' U R') u R2",
            "(y2) R U R' F2 D' (L U' L' U L') D F2",
            "(y2) L U2 L' U F' (L' U' L U L) F U (L' U' L' U L)",
            "R U2' R' U B' R' U' R U R B U R' U' R' U R",
            "(y2 z) U R2' U' R F' U' R' U R U F R U' R' U' R U (z' y2')",
            "(y2) l2 U' L2 U' F2 L' U' R U2 L' U l (x')",
            "(y) L U' R U2 L' U R' (y) R' L' U2 R L",
            "(y) f R f' R2 u' R U' R' U R' u R2",
            "(y') R' F' R F' U' L' U F R' F' L F2 R",
            "(y') R2' F' (R U R U') (R' F' R) (U2' R' U2' R') F2 R2",
            "(y z) U2 B' U R U R' U' B' U R2' U' R2 U' B2 U2' (z' y')",
            "(y2) (R U R') F2 D' L U' L' U L' D F2 U2",
            "(y2) (F U' R' F) (R2 U' R' U') (R U R' F') U2 (R U R' F') U' F  (U R U' R') F'",
            "L U L' B2 D' R U' R' U R' D B2",
            "F' L' F L' U' B' U L F' L' B L L F"
        })
    }

    ///
    /// Cases 6 to 6; see `all`.
    ///
    def part4(): Vector[Case] = Vector#{
        Case("J-PLL a, L-perm", 10, Vector#{
            "(y2) x R2' F R F' R U2 r' U r U2 x'",
            "(y2) L U' R' U L' U2 R U' R' U2 R",
            "U R U R' U' R' F R2 U' R' U2 R U R' F' R U R' U' R' F R F'",
            "(y) U R' U' R B R' U' R U l U' R2' F R (x)",
            "(y2) (F U' R' F) (R2 U' R' U') (R U R' F')2",
            "(y2) (F R U' R')2 (U R U R2') (F' R U F')",
            "(y2) R' U2 R U R' U2' L U' R U L'",
            "L' U R' U2 L U' R U L' U R' U2 L U' R",
            "y2 R' U2 R U R' U2 L U' R U L'",
            "(y) (R' U L') U2 (R U' R') U2 R L",
            "(y2) F U' R U' R' U' R U R' F' R U R' U' R' F R U F'",
            "B2 R' U' R B2 L' D L' D' L2",
            "(y2) F2 L' U' L F2 R' D R' D' R2",
            "(y2) F2 L' U' L b2 L' U L' U' r2",
            "(y2) R' U2 R U R' (z) R2' U R' D R U' (z')",
            "(y2) R' U2' R U R' (z) R2 U R' D R U' (z')",
            "(z) D R' U' R D' R (R U R' U') R2 U (z')",
            "R U' L' U R' U2 L U' L' U2' L",
            "R' L' U2 L U L' U2 R U' L U",
            "L' U2 L U L' U2 R U' L U R'",
            "R' d' R U R' U F U F' U' R U2 R' U F U",
            "L' U' L  F L' U' L U L F' L2 U L U",
            "(y2) (R' U L' U2 R U' L) U (R' U L' U2 R U' L)",
            "L2 D L D' L B2 R' U R B2",
            "(y) F' B' U U B U B' U U F U' B"
        })
    }

    ///
    /// Cases 7 to 7; see `all`.
    ///
    def part5(): Vector[Case] = Vector#{
        Case("J-PLL b", 10, Vector#{
            "(y2) R' U L U' R U2' L' U L U2 L'",
            "R U R' F' R U R' U' R' F R2 U' R' U'",
            "R U2 R' U' R U2 L' U R' U' r x",
            "R U2 (R' U' R) U2 L' (U R' U') L",
            "(y) (R U' L) U2 (R' U R) U2 L' R'",
            "L' U R U' L U2 R' U R U2 R'",
            "B2 (L U L') B2 (R D' R D) R2",
            "(y2) F2 (R U R') F2 (L D' L D) L2",
            "(y2) F2 (R U R') b2 (R U' R U) l2'",
            "(y' x') L2 u L u' L2 (x' y) (L U' L U) r2",
            "(y2 x) U2 l U l' U2 r (U' L U) r2",
            "R U' L U2 R' U L' U' R U' L U2 R' U L'",
            "B2 U D' B2 U B2 U' B2 D B2 U' B2 U",
            "(y') L2 (U D') L2 U L2 U' L2 D L2 U' L2",
            "R U R' F' R U R' U' l' U l2 F' l' U'",
            "R U2 R' U' R U2 L' U R' U' L",
            "R2 U F U F' R2 F U' F' R2 U' R2 U'",
            "R2 D' R' D R' B2 L U' L' B2",
            "(y') F B U' U' B' U' B U' U' F' U B'"
        })
    }

    ///
    /// Cases 8 to 8; see `all`.
    ///
    def part6(): Vector[Case] = Vector#{
        Case("N-PLL a", 13, Vector#{
            "(r' D r U2)5",
            "(r' D' r U2)5",
            "(l' D l U2)5",
            "(l' D' l U2)5",
            "R U R' U R U R' F' R U R' U' R' F R2 U' R' U2 R U' R'",
            "F' R U R' U' R' F R2 F U' R' U' R U F' R'",
            "R F U' R' U R U F' R2 F' R U R U' R' F",
            "(z) U' F R F' R' F' U F2' U R' F' R' F R U' F' (z')",
            "(z) B' U R U' R' U' B U2' B R' U' R' U R B' U' (z')",
            "(L U' R U2 L' U R')2 U'",
            "(z) (U R' D R2 U' R D')2 (z')",
            "L' U L2 F2 U L' F2 L U' F2 L2 U' L",
            "(y z) R' (U R' D R2 U' R D')2 (z')",
            "(R U' L U2 R' U L')2",
            "(z) (D R' U R2 D' R U')2 (z')",
            "(z) U R' D R2 U' R U (z') R' U' R (z) R2 U' R (z') R'",
            "R U' L d2 L' U L R' U' R U2 r' F l'",
            "R' U R2 B2 U R' B2 R U' B2 R2 U' R",
            "R B R' L' D' R B R' D L U' B U B' U' B'",
            "F U' B U U F' U S' L' B L L F' L B' (z)"
        })
    }

    ///
    /// Cases 9 to 9; see `all`.
    ///
    def part7(): Vector[Case] = Vector#{
        Case("N-PLL b", 13, Vector#{
            "(r D r' U2)5",
            "(r D' r' U2)5",
            "(l D l' U2)5",
            "(l D' l' U2)5",
            "R' (U r' F2 R F') M' (U r' F2 R F') r U",
            "(R' U R U') R' F' U' F (R U R' F) (R' F' R U') R",
            "(R' U R U') R' F' U' F (R U R' U') (R U' f R f')",
            "(R' U L' U2 R U' L)2 U",
            "(z) (D' R U' R2' D R' U)2 (z')",
            "B R' U' R U R B' R2' B' U R U R' U' B R",
            "(x') U R' F' R F R U' R2' U' F R F R' F' U R (x)",
            "R' B' U R U' R' U' B R2 B R' U' R' U R B'",
            "(x') R' U' F R F' R' F' U R2' U R' F' R' F R U' (x)",
            "(z) U' F' (R U R' U' R' F) U2' F (U' R' U' R U F') (z')",
            "(z) B' U' R B R' B' R' U B2' U B' R' B' R B U' (z')",
            "(z) F U' R' U R U F' U2 F' R U R U' R' F U (z')",
            "z D' R U' R2 D R' U D' R U' R2 D R' U z'",
            "(z) (U' R D' R2' U R' D)2 (z')",
            "z U' R D' R2 U R' D U' R D' R2 U R' D z'",
            "(z) U' R2 U (R U R' F' R U R' U' R' F R2 U' R' ) U2 R2 U z'",
            "L' U R' d2 R U' L R' U L' U2 l F' r",
            "r' D' F r U' r' F' D r2 U r' U' r' F r F'",
            "R2 D R' U R D' R2 U' R U' R' U' F R U R' U' R' F' R",
            "R U' R2 F2 U' R F2 R' U F2 R2 U R'",
            "L U' L2' B2' U' L B2' L' U B2' L2' U L'",
            "L' B' L R D L' B' L D' R' U B' U' B U B",
            "F' U B' U' U' F U' S R B' R' R' F R' B (z')"
        })
    }

    ///
    /// Cases 10 to 11; see `all`.
    ///
    def part8(): Vector[Case] = Vector#{
        Case("R-PLL a", 13, Vector#{
            "(y') R U' R' U' R U R D R' U' R D' R' U2 R'",
            "(y') R U R' F' R U2 R' U2 R' F R U R U2 R' U'",
            "R U2 R' U2 R B' R' U' R U R B R2 U",
            "R U2 R' U2 R B' R' U' R U l U R2 (x)",
            "(y2 z) U R2 U' R2 U F' U' R' U R U F U2 (z')",
            "(y2) L U2 L' U2 L F' L' U' L U L F L2",
            "(y') R2 B' R' U' R' U R B R' U2 R U2 R'",
            "(y) L2 F' L' U' L' U L F L' U2 L U2 L'",
            "F2 R' F' U' F' U F R F' U2 F U2 F'",
            "(y' x') R2 U' l' U' R' U l U l' U2 R U2 R'",
            "(y') R l U' l' U' R' U l U l' U2 R U2' R'",
            "F2 L2 U F U F' U' F' U' L2 F' U F' U'",
            "R U' R F2 U R U R U' R' U' F2 R2 U",
            "(y') R2 F2 U R U R' U' R' U' F2 R' U R'",
            "R U2 R' U' R' F' R U2 R U2 R' F R U' R' U",
            "(y) F U2 F' U R B' R' F R B R' U F'",
            "(y) F U2 S R B' D' F R2 F2 R' F D (z')",
            "(y') F U U F' U R B' R' F R B R' U F'",
            "(y') F U B' D B U B' D' S R F R F' (z')"
        }),
        Case("R-PLL b", 13, Vector#{
            "R' U2 R U2 R' F (R U R' U') R' F' R2' U'",
            "(y') L' U' L F L' U2 L U2 L F' L' U' L' U2 L U",
            "R' U2 R U2 R' F (R U R' U') l' U' R2 (x')",
            "(z') U' L2 U L2 U' F U L U' L' U' F' U2 (z)",
            "R' U2 R U2 R' F R U R' U' R' F' R2",
            "R' U2 R' D' R U' R' D R U R U' R' U' R",
            "y' R U2 R' U2 R' F R2 U' R' U' R U R' F' R U R' U R U2 R'",
            "y R2 F R U R U' R' F' R U2 R' U2 R",
            "(y x) R2 U l U R U' l' U' l U2 R' U2 R",
            "(y') r' L' U r U L U' r' U' r U2 L' U2 L",
            "(y2) L' U2 L U L F L' U2 L' U2 L F' L' U L U'",
            "(y) R2 F R U R U' R' F' R U2 R' U2 R",
            "(y) R2 F2 R F2 U R U2 L' U' M' B2 R (x')",
            "(y) R' U R U R' L D' L' U L D L' U R",
            "(y) R' U R U M' F' L' B L F L' B R (x')"
        })
    }

    ///
    /// Cases 12 to 13; see `all`.
    ///
    def part9(): Vector[Case] = Vector#{
        Case("T-PLL", 10, Vector#{
            "R U R' U' R' F R2 U' R' U' R U R' F'",
            "F R U' R' U R U R2 F' R U R U' R'",
            "R U R' U' R' F R2 U' R' U F' L' U L",
            "R2 U R2 U' R2 U' D R2 U' R2 U R2 D'",
            "(y2) L' U' L U L F' L2 U L U L' U' L F",
            "(y) F2 U' F2 D R2 B2 U B2 D' R2",
            "(y) F' U' F B' R' U R F' U F R' U' R B",
            "(y) F' U' S' U' L U F' L F U' L' U B (z)"
        }),
        Case("V-PLL", 14, Vector#{
            "(y) R U' R U R' D R D' R U' D R2 U R2 D' R2",
            "(y) R' U R' U' R D' R' D R3 U D' R2 U' R2' D R2",
            "R' U R U' R' f' U' (R U2 R' U' R U' R') f R",
            "R' f' (R U R' U R U2 R') U f (R U R' U') R",
            "R' U R' U' B' R' B2 U' B' U B' R B R",
            "R' U R' d' R' F' R2 U' R' U R' F R F",
            "R' U R' U' (y) R' F' R2 U' R' U R' F R F",
            "(y2 z) U' R U' R' F' U' F2 l' U' l F' U F U (z' y2')",
            "(y2 x) R U R U' B U' B' U2' R' U' B' R' B R' (x' y2')",
            "R' U R' U' B' l' (x2' y') U2 R' U' R (y) U' R U R (x)",
            "(z) D' R2 D R2 U R' D' R U' R U R' D R U'",
            "R U2 R' D R U' R U' R U R2 D R' U' R D2",
            "R' U R' U' R D' R' D R' U D' R2 U' R2 D R2",
            "(y') F' U F' U' R' F' R2 U' R' U R' F R F",
            "R2' D' R2 U R2' U' D R D' R D R' U R U' R",
            "x' (R' F R F') U (R U2 R' U') (R U' R' U2) (R U R' U')",
            "R' U R' U' B' D B' D' B2 R' B' R B R",
            "R' U R' U' B' D B' D' B B R' B' R B R"
        })
    }

    ///
    /// Cases 14 to 17; see `all`.
    ///
    def part10(): Vector[Case] = Vector#{
        Case("Y-PLL", 13, Vector#{
            "R' U' R U' L R U2 R' U' R U2 L' U R2 U R",
            "F R U' R' U' R U R' F' (R U R' U') (R' F R F')",
            "R2 U' R' U R U'  x  D' R' U R' U' R' D R",
            "F R' F R2 U' R' U' R U R' F' R U R' U' F'",
            "R' U' R F2 R' U R d R2 U' R2' U' R2",
            "R2 U' R2 U' R2 U R' F' R U R2 U' R' F R",
            "R2 U' R2 U' R2 d R U R' B2 R U' R'",
            "R2 U' R2 U' R2 U y' R U R' B2 R U' R'",
            "F2 D R2 U R2 D' R' U' R F2 R' U R",
            "(y') R2 u R2' U R2 D' R' U' R F2' R' U R",
            "(R U R' U') (R' F R F') (R U R' U') R' F (R2 U' R' U) (R U R' F')",
            "R2' U' R2 U'   R2' U R2 D' R2' U   R2 U' R2' D R2",
            "R2 U' R2 U' R2 U F U F' R2 F U' F'"
        }),
        Case("A-PLL a", 9, Vector#{
            "(U') x R' U R' D2 R U' R' D2 R2 x'",
            "x' R2 D2 R' U' R D2 R' U R' x",
            "(U2) x L2 D2' L' U' L D2' L' U L' x'",
            "(U) R' D R U' R' D' R U' R' D R U2 R' D' R",
            "R2 F2 R' B' R F2 R' B R'",
            "R B' D F' D' B' D F D' B B R'"
        }),
        Case("Ab-PLL", 9, Vector#{
            "(U') x R2' D2 R U R' D2 R U' R x'",
            "x' R U' R D2 R' U R D2 R2' x",
            "(U2) x L U' L D2' L' U L D2' L2' x'",
            "(U) R' D R U2 R' D' R U R' D R U R' D' R",
            "(y) L2 F2 L B L' F2 L B' L",
            "(y) L' B D' F D B D' F' D B' B' L"
        }),
        Case("E-PLL", 14, Vector#{
            "(U) x' R U' R' D R U R' D' R U R' D R U' R' D' x",
            "R' D' R U' R' D R U R' D' R U2 R' D R U' R' D' R U R' D R",
            "R2 U R' d' (R U R' U')2 R U R' F U' F2",
            "F' (r U R' U' r' F R) U2 (r U R' U' r' F R F')",
            "F R B R' F' R L F L' B' L F' R' L'"
        })
    }

    ///
    /// Cases 18 to 21; see `all`.
    ///
    def part11(): Vector[Case] = Vector#{
        Case("H-PLL, X-PLL", 10, Vector#{
            "M2' U M2' U2 M2' U M2'",
            "M2' U' M2' U2' M2' U' M2'",
            "M2' U2 M2' U M2' U2 M2'",
            "R2 F2 B2 L2 D' R2 F2 B2 L2",
            "M2 D S2 D2 S2 D M2",
            "R L U U R' L' F' B' U U F B"
        }),
        Case("U-PLL a", 9, Vector#{
            "R U R' U R' U' R2 U' R' U R' U R",
            "(U2) M2' U M U2 M' U M2'",
            "(U2) R U' R U R U R U' R' U' R2",
            "(U) R2 U' S' U2' S U' R2",
            "B2 U' R L' B2 R' L U' B2",
            "B2 U' M U2 M' U' B2",
            "R U B U' B' R' L' B' U' B U L",
            "R' F' M' F U F' M F U' R"
        }),
        Case("U-PLL b", 9, Vector#{
            "R' U R' U' R3 U' R' U R U R2",
            "(U2) M2 U' M U2 M' U' M2",
            "(U2) R2' U R U R' U' R3 U' R' U R'",
            "(U) R2 U' S R2' S' R2 U R2'",
            "B2' U L' R B2' L R' U B2'",
            "B2' U M U2' M' U B2'",
            "L' U' B' U B L R B U B' U' R'",
            "L F M' F' U' F M F' U L'"
        }),
        Case("Z-PLL", 12, Vector#{
            "(U) M' U M2' U M2' U M' U2 M2'",
            "M2' U M2' U M' U2 M2' U2 M'",
            "M2' U2 M U M2' U M2' U M",
            "R' U' R U' R U R U' R' U R U R2 U' R'",
            "R L' U2 D2 R L' D' R2 L2 U F2 B2",
            "M S2 M' D' M2 D S2",
            "R B' R' F B R' F B' R' B R F F",
            "M S' S' M' D M' M' D' S' S'"
        })
    }



}
