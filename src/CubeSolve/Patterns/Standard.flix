///
/// Every published 3x3x3 pattern this project knows about.
///
/// **Provenance.** Retrieved 2026-08-29:
///
/// - `speedsolving` -- the 3x3x3 section of
///   <https://www.speedsolving.com/wiki/index.php/List_of_pretty_patterns>
/// - `ruwix1` -- <https://ruwix.com/the-rubiks-cube/rubiks-cube-patterns-algorithms/>
/// - `ruwix2` -- <https://ruwix.com/the-rubiks-cube/rubiks-cube-patterns-algorithms/
///   more-rubiks-patterns/>
///
/// 121 algorithms were collected and 11 dropped as renames, leaving **110
/// patterns**. Where a pattern appears in more than one collection the
/// speedsolving name is the one kept, which is why the checkerboard is here as
/// `Pons Asinorum` rather than ruwix's `The easy checkerboard`.
///
/// **A rename is decided by the pattern, not by the name.** Two algorithms make
/// the same pattern when they reach the same state up to how the cube is held.
/// A 3x3x3's centres pin the frame, so the orbit coordinates are already
/// stated in the upright frame and the relation between two orientations of one
/// pattern is *conjugation*; the key is therefore the smallest `flix-orbit64`
/// token over all 24 conjugations. That matters: `M S M' S'` and `(M z)4` reach
/// states with different tokens and are the same six-spot, one being the other
/// turned in the hand.
///
/// Dropped as renames:
///
/// - `The easy checkerboard` is `Pons Asinorum`
/// - `6-Spot (alternative)` is `6-Spot`
/// - `Six spots` is `6-Spot`
/// - `Four spots` is `4-Spot`
/// - `Two-face checkerboard (alt)` is `Two-face checkerboard`
/// - `Facing checkerboards` is `Two-face checkerboard`
/// - `Superflip (easier)` is `Superflip`
/// - `The Superflip` is `Superflip`
/// - `Yan Ying` is `Tetris`
/// - `Headlights` is `Hi`
/// - `Twisted peaks` is `Staircase`
///
/// Three of those are duplicates *within* ruwix's own list.
///
/// **One name collides without the patterns colliding.** Both ruwix pages
/// publish a "4 crosses" and they are different patterns, so the second is
/// listed as `4 crosses (second list)`.
///
/// **`half` is the pattern in the half-turn metric.** The published algorithms
/// use slice moves, which no sequence of face turns can reproduce -- a slice
/// move turns the centres and face turns cannot. What face turns can reach is
/// the same pattern *held differently*, and that is what `half` is: produced by
/// solving the pattern and inverting the solution, so it is a real sequence
/// rather than a transcription, and it is checked against the published one on
/// every test run.
///
/// Generated. Regenerate rather than editing by hand.
///
pub mod CubeSolve.Patterns.Standard {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Holding
    use CubeSolve.Model.Move
    use CubeSolve.Model.Rotation
    use CubeSolve.Patterns.Standard.Pattern.Pattern

    ///
    /// A pattern: its name, where it came from, the published algorithm, the
    /// same pattern using face turns only, and its identity as a state.
    ///
    pub enum Pattern with Eq, ToString {
        case Pattern(String, String, String, String, String)
    }

    ///
    /// The pattern's usual name.
    ///
    pub def name(p: Pattern): String = let Pattern(n, _, _, _, _) = p; n

    ///
    /// Which collection it was taken from.
    ///
    pub def source(p: Pattern): String = let Pattern(_, _, s, _, _) = p; s

    ///
    /// The algorithm as published.
    ///
    pub def notation(p: Pattern): String = let Pattern(_, _, _, a, _) = p; a

    ///
    /// The same pattern using face turns only.
    ///
    /// Its inverse is a solution, which is what `knownSolution` returns. It is
    /// a *known* one and not an optimal one -- see there.
    ///
    pub def faceTurns(p: Pattern): String = let Pattern(_, _, _, _, h) = p; h

    ///
    /// The pattern's identity: the smallest token over all 24 orientations.
    ///
    pub def canonical(p: Pattern): String = let Pattern(_, c, _, _, _) = p; c

    ///
    /// The URL this pattern's source refers to.
    ///
    /// Delegates to `CubeSolve.Patterns.url`, which knows both collections.
    ///
    pub def url(id: String): String = CubeSolve.Patterns.url(id)

    ///
    /// A face-turn solution for the pattern as recorded upright.
    ///
    /// **Known, not optimal.** It is the recorded `faceTurns` run backwards, so
    /// it is exactly as long as that sequence and nothing here claims it is the
    /// shortest way to undo the pattern. The 3x3x3's optimal distances are not
    /// known for these states and this project does not compute them; for a short
    /// answer, ask the solver. The 2x2x2 corpus is the one that can promise
    /// optimality, and it says so with a different name.
    ///
    pub def knownSolution(p: Pattern): Result[String, List[Move.Move]] =
        Move.parse(faceTurns(p)) |> Result.map(Move.inverseOf)

    ///
    /// `knownSolution` renamed into the frame `witness` describes.
    ///
    /// `recognize` hands back the witness that goes with the cube it was given,
    /// and this is what that witness is for: the corpus records every pattern
    /// upright, so a cube held any other way needs the solution's face names
    /// carried across before it applies.
    ///
    pub def solutionFor(
        p: Pattern,
        witness: Rotation.Rotation
    ): Result[String, List[Move.Move]] =
        knownSolution(p) |> Result.map(List.map(m -> Rotation.reframe(m, witness)))

    ///
    /// This cube's pattern identity: the smallest token over the 24
    /// conjugations, or nothing if it is not a cube.
    ///
    /// Conjugation is the relation here because a 3x3x3's centres pin the frame.
    /// `CubeSolve.Model.Holding` owns that rule and the 2x2x2's different one;
    /// this is the name the corpus knows it by.
    ///
    pub def identify(c: Cube.Cube): Option[String] = Holding.identityOf(c)

    ///
    /// The published pattern `c` is, and how it is being held.
    ///
    /// Nothing else in the engine calls this. Recognising a scramble as a known
    /// pattern does not make the solver answer differently, by design: a
    /// shortcut that fired on 110 states out of 43 quintillion would be
    /// untestable in the ordinary case and would make solution length depend on
    /// whether a state happened to be famous.
    ///
    pub def recognize(c: Cube.Cube): Option[(Pattern, Rotation.Rotation)] =
        forM (
            id <- identify(c);
            found <- all() |> Vector.findLeft(p -> canonical(p) == id);
            held <- heldAs(found, c)
        ) yield (found, held)

    ///
    /// Which rotation carries the recorded pattern onto `c`.
    ///
    /// Recomputed from `faceTurns` rather than stored: a second copy of each
    /// state in the source would be 110 more literals to keep in step with the
    /// algorithms they came from, and this runs once per recognition rather than
    /// in any loop worth counting.
    ///
    def heldAs(p: Pattern, c: Cube.Cube): Option[Rotation.Rotation] =
        forM (
            upright <- Cube.solved(3)
                |> Result.flatMap(s -> Cube.applyNotation(faceTurns(p), s))
                |> Result.toOption;
            target <- Facelets.token(c) |> Result.toOption;
            r <- Rotation.all()
                |> Vector.findLeft(
                    r ->
                        Cube.conjugate(r, upright)
                            |> Result.flatMap(Facelets.token)
                            == Ok(target)
                )
        ) yield r

    ///
    /// Every pattern.
    ///
    ///
    /// Patterns 1 to 16; see `all`.
    def part1(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Pons Asinorum",
                "AAAAD6uBEAA",
                "speedsolving",
                "M2 E2 S2",
                "B2 F2 L2 R2 D2 U2"
            ),
            Pattern(
                "6-Spot",
                "B8bp0I-9kD_",
                "speedsolving",
                "M S M' S'",
                "L' R U' D B' F L' R"
            ),
            Pattern(
                "4-Spot",
                "Ku8ZrUJVEAA",
                "speedsolving",
                "M2 S M2 S'",
                "B2 F2 U2 B2 F2 L2 B2 F2 R2 U2"
            ),
            Pattern(
                "Two-face checkerboard",
                "AAAAAHRNrgA",
                "speedsolving",
                "L2 F2 R2 B2 L2 F2 R2 B2 L2 F2 R2 B2",
                "F2 R2 B2 F2 R2 F2 L2 R2"
            ),
            Pattern(
                "Superflip",
                "AAAAAAAAAf_",
                "speedsolving",
                "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2",
                "U2 B2 L2 F D2 U2 B R2 B L2 D2 F' D U' L' F B' D2 L2 D' L' R'"
            ),
            Pattern(
                "Superflip (easier, rotations)",
                "AAAAAAAAAJp",
                "speedsolving",
                "M U M U M U M U x y' M U M U M U M U x y' M U M U M U M U x y'",
                "F' D B2 L' B D' L' D' L' D L2 B' L2 B' R2 U2 B' F2 R2 D2"
            ),
            Pattern(
                "Speedsolving.com logo",
                "LdZB1Pr2qAA",
                "speedsolving",
                "U2 B2 U2 B2 L R F2 D2 F2 U2 L' R'",
                "F2 R2 D' U' L2 B2 L2 B2 D U F2 R2"
            ),
            Pattern(
                "Three faces scrambled",
                "AAAAAAYixLg",
                "speedsolving",
                "U' D L2 U B2 D2 B2 D2 L F' U D' R U' F2 L F' B'",
                "B2 L' U2 L2 F2 R B2 U2 D' L2 F U2 B2 L2 F' R2 U D2"
            ),
            Pattern(
                "SpeedSolving",
                "MyEW7riTAAA",
                "ruwix1",
                "R' L' U2 F2 D2 F2 R L B2 U2 B2 U2",
                "F2 R2 D U L2 B2 L2 B2 D' U' F2 R2"
            ),
            Pattern(
                "3 sides solved",
                "AADz7WwQtwA",
                "ruwix1",
                "U2 D R' D B' L2 B D' R L2 U2 B2 L2 B2 D R2 L2 D R2",
                "L B R' B' D' L B2 R' D2 R2 B' F R2 F U2 R2 F' L2"
            ),
            Pattern(
                "All flags & crests",
                "AZWDDcqoZf_",
                "ruwix1",
                "B2 U' B2 L2 U B2 U R2 B2 U' L' R' B D U' L2 F2 R'",
                "U' F' B' R' F B' R L' F U D R' U2 F2 D2 L2 U2"
            ),
            Pattern(
                "Wire",
                "BdunElCNAAA",
                "ruwix1",
                "R L F B R L F B R L F B R2 B2 L2 R2 B2 L2",
                "D' R2 B2 U2 B2 R2 U2 R2 D' U R2 U'"
            ),
            Pattern(
                "Checkerboard in the cube",
                "B8aYOtgvMV9",
                "ruwix1",
                "B D F' B' D L2 U L U' B D' R B R D' R L' F U2 D",
                "R2 F2 L U2 L B2 L F2 R' U' D B' L' F D' F' R2 F U R"
            ),
            Pattern(
                "Perfect Scramble",
                "B-KsoLk8uSZ",
                "ruwix1",
                "U F' L' U' R2 F' R2 B' U' R F' U F D' L2 F2 L2 U'",
                "D2 L2 F2 L2 F L2 F R2 F' R F D L D' F B' D R2 B R"
            ),
            Pattern(
                "( ! ) (ˆ⌣ˆԅ)",
                "B8crR9WRkcA",
                "ruwix1",
                "U' F2 R' L' U' B R2 D B U' R2 L B2 D' B2 U F2 B2 U' L2 B2 L2",
                "D B2 R L D F' L2 U' F' D R' L2 F2 U F2 D' F2 B2 D R2 F2 R2"
            ),
            Pattern(
                "Minority cross",
                "E9Xfc2rlqNX",
                "ruwix1",
                "L2 D' B2 L2 B2 D' F2 D U' B2 L B2 F' L B' F U' F' U L2",
                "R D2 L' B2 F2 L F2 R' F U2 F U' D L' F2 L' B' F"
            )
        }

    /// Patterns 17 to 32; see `all`.
    def part2(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Perpendicular lines",
                "Ku8ZqIWNngA",
                "ruwix1",
                "R2 U2 L2 R2 U2 L2 M2",
                "R2 U2 L2 R2 U2 R2"
            ),
            Pattern(
                "Flipped tips",
                "AAA5NoT8AAA",
                "ruwix1",
                "U B D' F2 D B' U' R2 D F2 D' R2 D F2 D' R2",
                "L F U2 F' U2 F' L' F L2 B' U2 B U2 L2"
            ),
            Pattern(
                "Plus minus",
                "Ku8ZqIWNmAA",
                "ruwix1",
                "U2 R2 L2 U2 R2 L2",
                "L2 R2 U2 L2 R2 U2"
            ),
            Pattern(
                "Tablecloth",
                "FerVsbb97j_",
                "ruwix1",
                "R L U2 F' U2 D2 R2 L2 F' D2 F2 D R2 L2 F2 B2 D B2 L2",
                "R F2 D B F' U D' B' U2 R B F D2 B' U2 D2 B' L2 B2"
            ),
            Pattern(
                "Deckerboard",
                "E9XfZ-ntY9V",
                "ruwix1",
                "U D R L' F' B U D' R2 U R2 L2 D2 F2 B2 D",
                "B R2 L2 B2 U' D R L' B' F D' B2 U2 D2 F2 D2"
            ),
            Pattern(
                "Spiral pattern",
                "B8aYOtgvMC-",
                "ruwix1",
                "L' B' D U R U' R' D2 R2 D L D' L' R' F U",
                "F U F' R F D' L D B' D' B R2 L2 U2 B' L2 F R2 D2 F' L2"
            ),
            Pattern(
                "Fruit bowl",
                "B8bp0P54xj_",
                "ruwix1",
                "B2 L2 F2 R2 F2 R2 D U B2 U2 B' F' L' R' D' U'",
                "B' F R L U' D' B' F' R2 B2 L2"
            ),
            Pattern(
                "Flower",
                "AAAAAHR0kAA",
                "ruwix1",
                "R2 D2 R2 U2 R2 F2 U2 D2 F2 U2",
                "L2 D U B2 U2 B2 L2 R2 D' U'"
            ),
            Pattern(
                "Vertical stripes",
                "EzrwLIrsB8A",
                "ruwix1",
                "F U F R L2 B D' R D2 L D' B R2 L F U F",
                "L2 D2 B L2 B U2 F L2 F2 B' U' B2 L' F2 R2 U' L' U' R' D' F"
            ),
            Pattern(
                "Gift box",
                "gtOa33ZAEcA",
                "ruwix1",
                "U B2 R2 B2 L2 F2 R2 D' F2 L2 B F' L F2 D U' R2 F' L' R'",
                "R L B L2 U D' B2 R F B' U2 B2 U' F2 U2 R2 B2 R2 D2 L2 D'"
            ),
            Pattern(
                "Opposite corners",
                "LdZB2KDjNgA",
                "ruwix1",
                "R L U2 F2 D2 F2 R L F2 D2 B2 D2",
                "B2 L2 D U R2 B2 R2 B2 D' U' F2 R2"
            ),
            Pattern(
                "Cross",
                "B8bpvVLsAAA",
                "ruwix1",
                "R2 L' D F2 R' D' R' L U' D R D B2 R' U D2",
                "F D2 B2 L2 R2 B2 U2 B D2 U2 B2 U F2 B2 D2 L2 R2 D"
            ),
            Pattern(
                "4 crosses",
                "Ku8ZqBFAAAA",
                "ruwix1",
                "U2 R2 L2 F2 B2 D2 L2 R2 F2 B2",
                "F2 R2 F2 D' U R2 F2 R2 D U'"
            ),
            Pattern(
                "Union Jack",
                "E9XfXq4MAAA",
                "ruwix1",
                "U F B' L2 U2 L2 F' B U2 L2 U",
                "U' B2 F2 L2 B2 F2 D2 U2 R2 D2 U'"
            ),
            Pattern(
                "Cube in the cube",
                "B8aYNvLfzA8",
                "ruwix1",
                "F L F U' R U F2 L2 U' L' B D' B' L2 U",
                "L' F2 R' B' U B' U B' U R F2 L' B2 D2 L2"
            ),
            Pattern(
                "Cube in a cube in a cube",
                "B8c67nMTzA8",
                "ruwix1",
                "U' L' U' F' R2 B' R F U B2 U B' L U' F U R F'",
                "U' D' L' F R2 B2 L F U' L2 U R2 F2 U' L2 D F2 L2 U2"
            )
        }

    /// Patterns 33 to 48; see `all`.
    def part3(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Anaconda",
                "B8bp0GHTejD",
                "ruwix1",
                "L U B' U' R L' B R' F B' D R D' F'",
                "F L2 R2 F B' U2 L D U' L F' B D' F' R2 D'"
            ),
            Pattern(
                "Python",
                "E9XfXs_7iiC",
                "ruwix1",
                "F2 R' B' U R' L F' L F' B D' R B L2",
                "B' R' U R2 U' R B R2 U F2 B2 R2 U' F2 U R2 U' F2"
            ),
            Pattern(
                "Black mamba",
                "B8bp0MYvBCl",
                "ruwix1",
                "R D L F' R L' D R' U D' B U' R' D'",
                "R D B D R' D B D2 R F2 D' F2 D2 R' B2 D2"
            ),
            Pattern(
                "Green mamba",
                "B8bp0MYwVBl",
                "ruwix1",
                "R D R F R' F' B D R' U' B' U D2",
                "U L2 F R L' U' L2 F' D2 F2 R' F2 B2 L B2 D2"
            ),
            Pattern(
                "Tangled",
                "LdZB3ehqMAA",
                "ruwix1",
                "F B U D F B U D F B U D F2 B2",
                "R2 B2 R2 B2 D U B2 R2 F2 R2 D U"
            ),
            Pattern(
                "Twister",
                "B8aYNvHfSAk",
                "ruwix1",
                "F R' U L F' L' F U' R U L' U' L F'",
                "F' L2 B L' F2 L D' B2 D B R2 L2 F2 R2 F"
            ),
            Pattern(
                "Kilt (Scottish skirt)",
                "B8bpwVGrg9V",
                "ruwix1",
                "U' R2 L2 F2 B2 U' R L F B' U F2 D2 R2 L2 F2 U2 F2 U' F2",
                "B U2 D2 R2 L2 B U' D' R L' B R2 B2 L2 U2 D2 B2 L2 B' L2"
            ),
            Pattern(
                "Tetris",
                "LdbYCb7KIj_",
                "ruwix1",
                "L R F B U' D' L' R'",
                "U2 L2 U2 R2 F B L2 D2 R2 D' U L R F B"
            ),
            Pattern(
                "Don't cross line",
                "Ku8Zsv_5qAA",
                "ruwix1",
                "F2 L2 R2 B2 E2",
                "B2 L2 R2 F2 D2 U2"
            ),
            Pattern(
                "Hi",
                "AAAAAAAABgA",
                "ruwix1",
                "M2 U2 M2 U2",
                "L2 R2 D2 L2 R2 U2"
            ),
            Pattern(
                "Hi all around",
                "AAAABaJXngA",
                "ruwix1",
                "U2 R2 F2 U2 D2 F2 L2 U2",
                "U2 L2 F2 D2 U2 F2 R2 U2"
            ),
            Pattern(
                "Displaced Motif",
                "ARPu8WETuAo",
                "ruwix1",
                "L2 B2 D' B2 D L2 U R2 D R2 B U R' F2 R U' B' U'",
                "U' L' U' F R2 F' U L F2 D F2 U B2 D L2 D' L2 B2"
            ),
            Pattern(
                "Are you high?",
                "AAAAAVPGuAA",
                "ruwix1",
                "L R' U2 D2 L' R U2 D2 R2 L2",
                "L2 B2 F2 R2 D' U' L2 R2 D' U'"
            ),
            Pattern(
                "C U around",
                "B8bp0McbuC9",
                "ruwix1",
                "U' B2 U L2 D L2 R2 D' B' R D' L R' B2 U2 F' L' U'",
                "R' U2 R U2 F L R D' R' F' R U B' R'"
            ),
            Pattern(
                "Order in chaos",
                "B8aYOq1bgdR",
                "ruwix1",
                "B L2 B' U2 B F2 U L U B U' R U' B F U' R D R B' U'",
                "U' B2 D' L D2 R F' U2 B' U' D2 F2 B2 L2 U' R2 F2 D2 F2 B2"
            ),
            Pattern(
                "Evenly distributed",
                "AACWM8Gr08A",
                "ruwix1",
                "D' B2 D' L2 R2 D B2 L2 D' B2 L R' F' L2 D U' F2 R' D' U'",
                "F2 U2 R U2 F2 U2 R' B' L B D' L R' B2 U2 B' R' D' R'"
            )
        }

    /// Patterns 49 to 64; see `all`.
    def part4(): Vector[Pattern] =
        Vector#{
            Pattern(
                "The hole",
                "FerVseAkMeq",
                "ruwix1",
                "R L' F' B D U'",
                "L' R B F' U' D"
            ),
            Pattern(
                "No entry",
                "E9XfXtGZFCq",
                "ruwix1",
                "U' L' B R L' D' L B' U F2 R2 B2 D2 B2 R2 B2 D B2",
                "D2 F' B R2 F' B D' B R' U L R' F' R U' B"
            ),
            Pattern(
                "\"Plus\"",
                "Ku8ZqBFGGgA",
                "ruwix1",
                "B2 F2 R2 U2 B2 F2 R2 U2 R2 U2",
                "B2 F2 R2 U2 B2 F2 R2 U2 R2 U2"
            ),
            Pattern(
                "3C3W",
                "ACTv6YL6uVR",
                "ruwix1",
                "D L B' L L F L' B' U D' R L' F B D L'",
                "U2 R B2 L' D2 B' D2 F U L2 D' B' L' D B D' R'"
            ),
            Pattern(
                "Pong",
                "Ku8ZqBFtAAA",
                "ruwix1",
                "U R2 F2 B2 L2 U2 D R2 F2 B2 L2",
                "L2 B2 F2 R2 D' L2 B2 F2 R2 D2 U'"
            ),
            Pattern(
                "Spun T's",
                "B8bpvYVzSAk",
                "ruwix1",
                "U' L2 F2 L2 F2 D' L2 F' L2 F' D U2 L' B L B' U'",
                "R' F2 D2 F2 D2 L' F2 D' F2 D' L R2 F' U F U' R'"
            ),
            Pattern(
                "Wifi Downstairs",
                "IkRtraGniAA",
                "ruwix1",
                "R U' R F2 R' U R F2 U' B2 U D R2 U' L2 D' L2",
                "B2 D B2 D' R2 D' B2 D R2 U' F2 R2 U R2 F2 U'"
            ),
            Pattern(
                "Opposite pillars",
                "Ku8ZqBFAEAA",
                "ruwix2",
                "R2 F2 L2 R2 F2 L2",
                "L2 F2 L2 R2 F2 R2"
            ),
            Pattern(
                "Viaduct",
                "FerVr3jrAcA",
                "ruwix2",
                "R2 U2 L2 D B2 L2 B2 R2 D' U L' D F' U' R2 F' U B2 U2 R'",
                "B R' U2 F' L' U D' B L U2 F R'"
            ),
            Pattern(
                "Solved in scrambled",
                "AAA03Rb5tAo",
                "ruwix2",
                "U2 L' U2 L' U2 F2 D L F' L F R2 D' B2 D' L2 D' L2 F2 R2",
                "F2 U R2 B U L U' L' B' R2 F R2 F2 U2 F' L2 D2 B' D2 L2"
            ),
            Pattern(
                "Hi Ohio",
                "Ku8ZqWUGuAA",
                "ruwix2",
                "U2 F2 L2 R2 F2 U2",
                "U2 F2 L2 R2 F2 U2"
            ),
            Pattern(
                "Staircase",
                "AAA5UO3m7hp",
                "ruwix2",
                "L2 F2 D' L2 B2 D' U' R2 B2 U' L' B2 L D L B' D L' U",
                "L' F' U2 F2 U' L F' D R' L2 B2 D' R2 D B2 R2 L2 D'"
            ),
            Pattern(
                "Wrapped 2x2",
                "BuWh19dgex8",
                "ruwix2",
                "D' B2 F2 L2 U' F2 R2 D F2 U2 L' B R' U' L' F D' F L D2",
                "B R2 F2 L2 B' U2 B L F' L2 U' F' L' R2 D L D' B"
            ),
            Pattern(
                "Antipodal chaos",
                "B8ZTpUFpAgA",
                "ruwix2",
                "U2 L2 U2 L2 U2 F2 R2 F2 U2 F2",
                "F' B L2 D2 L2 D2 F' B' R2"
            ),
            Pattern(
                "Flower field",
                "B8bp1pgTrj_",
                "ruwix2",
                "M S M' S' R2 L2 U2 D2 F2 B2",
                "R' L' D U' F' B R L' D2 F2 R2 L2 F2"
            ),
            Pattern(
                "C spirals",
                "B8ZTpbBLngA",
                "ruwix2",
                "B' F' L2 D2 B' F U2 R2 F2",
                "D' U' B2 L2 D' U R2 F2 U2"
            )
        }

    /// Patterns 65 to 80; see `all`.
    def part5(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Worms",
                "AAAAAAx7CgA",
                "ruwix2",
                "U' F2 L2 U D2 F2 B2 U F2 L2 D",
                "U' B2 R2 D2 U' L2 R2 U' B2 R2 D"
            ),
            Pattern(
                "Glider",
                "AZTs4s0NvgA",
                "ruwix2",
                "D2 R2 F2 R2 U2 B2 D2 F2 L2 U2 R2 U2",
                "D2 R2 F2 R2 U2 B2 D2 F2 L2 U2 R2 U2"
            ),
            Pattern(
                "Quote",
                "Ku8ZqBFtBAA",
                "ruwix2",
                "U2 F2 D2 B2 R2 U2 B2 R2 U2 R2",
                "B2 U2 B2 L2 D2 F2 R2 U2 R2 U2"
            ),
            Pattern(
                "Matching pictures",
                "ARKp0UI3pgA",
                "ruwix2",
                "R' D2 R L D2 L'",
                "L' F2 R L F2 R'"
            ),
            Pattern(
                "Loose strap",
                "Ku8ZqIW0gAA",
                "ruwix2",
                "F2 U2 B2 U2 F2 U2",
                "F2 U2 B2 U2 F2 U2"
            ),
            Pattern(
                "Doubler",
                "BdunDR94BgA",
                "ruwix2",
                "R L U2 R L' D2 R2 F2 U2 F2 U2 L2 F2 U2 L2",
                "L2 F2 R2 F2 D U B2 R2 F2 R2 D U"
            ),
            Pattern(
                "3T",
                "B9ht4QdWLgA",
                "ruwix2",
                "B U2 L2 F2 R2 F D2 F2 R2 F' R2 U2",
                "B U2 L2 B2 L2 B' U2 B2 L2 B R2 U2"
            ),
            Pattern(
                "4 T",
                "AA8-hs1AEAA",
                "ruwix2",
                "F2 D2 F' L2 D2 U2 R2 B' U2 F2",
                "B2 L2 R2 F2 D' L2 B2 F2 R2 U'"
            ),
            Pattern(
                "6 T",
                "B8ZTqk8uJgA",
                "ruwix2",
                "F2 R2 U2 F' B D2 L2 F B",
                "D2 B2 L2 D U' R2 F2 D' U'"
            ),
            Pattern(
                "ZZ-Line",
                "BdunF5nkBgA",
                "ruwix2",
                "R L U2 R L' U2 F2 R2 U2 F2 D2 B2 L2 U2 L2",
                "F2 L2 B2 R2 D' U' L2 B2 R2 F2 D U"
            ),
            Pattern(
                "Checker zigzag",
                "AAAABiEZvAA",
                "ruwix2",
                "R2 L2 F2 B2 U F2 B2 U2 F2 B2 U",
                "B2 F2 L2 R2 U' B2 F2 U2 B2 F2 U'"
            ),
            Pattern(
                "Exchanged duck feet",
                "Au4Ic9-kOXD",
                "ruwix2",
                "U F R2 F' D' R U B2 U2 F' R2 F D B2 R B'",
                "R' L2 F D' F2 D F' R' R2 U' B2 R2 U' B2 U2 L2 D F2 D2"
            ),
            Pattern(
                "Stripe dot solved",
                "Ku8ZqIWNqAA",
                "ruwix2",
                "D U B2 F2 D' U'",
                "D U B2 F2 D' U'"
            ),
            Pattern(
                "Picnic",
                "AA8-kUfZEAA",
                "ruwix2",
                "D2 R2 L2 F2 B2",
                "D2 B2 F2 L2 R2"
            ),
            Pattern(
                "Percent sign %",
                "BdunDZPFrgA",
                "ruwix2",
                "R L U2 R L' U2 F2 L2 U2 F2 U2 F2 R2 U2 R2",
                "F2 L2 B2 L2 D U L2 F2 R2 F2 D U"
            ),
            Pattern(
                "Mirror",
                "LHTIAuw0OAA",
                "ruwix2",
                "U D F2 B2 U' D' R2 L2 B2",
                "F' B' D2 U2 F B'"
            )
        }

    /// Patterns 81 to 96; see `all`.
    def part6(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Plus minus check",
                "Ku8Zsv_5mAA",
                "ruwix2",
                "U D R2 L2 U D R2 L2",
                "L2 R2 D' U' L2 R2 D' U'"
            ),
            Pattern(
                "Hi again",
                "AAAAAOWjaAA",
                "ruwix2",
                "U2 D2 L2 U2 D2 R2 F2 B2 L2 F2 B2 R2 U2 D2 F2 U2 D2 B2",
                "B2 F2 D' U' B2 L2 R2 F2 D' U'"
            ),
            Pattern(
                "4 plus 2 dots",
                "E9XfYqzLg9V",
                "ruwix2",
                "F U2 D2 R L U' D F B R U2 R2 U2 F2 L2 U2 F2 L2 B2",
                "L2 R2 B2 U2 D2 F L R' U' D B' F R2 U2 D2 R'"
            ),
            Pattern(
                "Rockets",
                "AA8-i_4oAAA",
                "ruwix2",
                "U R2 F2 R2 U' D F2 R2 F2 D",
                "B2 F2 L2 R2 U2 B2 F2 L2 R2"
            ),
            Pattern(
                "Slash",
                "BdunElCNEAA",
                "ruwix2",
                "R L F B R L F B R L F B",
                "D' L2 B2 D2 F2 R2 D2 L2 D' U R2 U'"
            ),
            Pattern(
                "The pillars",
                "Ku8ZsousEAA",
                "ruwix2",
                "L2 R2 B2 F2",
                "B2 F2 L2 R2"
            ),
            Pattern(
                "Twisted duck feet",
                "B8aYSc4_ejD",
                "ruwix2",
                "F R' B R U F' L' F' U2 L' U' D2 B D' F B' U2",
                "B' U2 L U B' R' F' D' F' D' R' D2 B L2 B' R2 F U2 B2 F"
            ),
            Pattern(
                "Ron's cube in a cube",
                "Bd2O3flNBAA",
                "ruwix2",
                "F D' F' R D F' R' D R D L' F L D R' F D'",
                "B2 L2 U2 L2 U' L2 B2 D2 F2 U F2 R2 U2 R2 U'"
            ),
            Pattern(
                "Crossing snake",
                "BdunElCNFgA",
                "ruwix2",
                "R L U2 R L' U2 F2 R2 D2 B2 D2 B2 L2 D2 R2",
                "F2 L2 F2 L2 D' U' L2 B2 R2 F2 D' U'"
            ),
            Pattern(
                "Cage",
                "E0sEEdjXGBa",
                "ruwix2",
                "L U F2 R L' U2 B' U D B2 L F B' R' L F' R",
                "B2 D U L2 F2 D B2 U F2 D2 R2 B L B2 U2 F' D' R U2 B"
            ),
            Pattern(
                "4 crosses (second list)",
                "FfNo20xIAAA",
                "ruwix2",
                "F2 B2 R F2 B2 R F2 B2 R F2 B2 R F2 B2 R F2 B2 R",
                "L' F2 B2 U2 D2 R' U2 D2 F2 B2"
            ),
            Pattern(
                "Pyraminx",
                "AAAAABRzPoU",
                "ruwix2",
                "D L' U R' B' R B U2 D B D' B' L U D'",
                "B2 D L F2 R2 U L B' L U' R U2 R U2 L' D2 R L B2 U2"
            ),
            Pattern(
                "Edge triangle",
                "AAAAAAM2Y1p",
                "ruwix2",
                "U B2 U' F' U' D L' D2 L U D' F D' L2 B2 D'",
                "B' D' L D2 L' D B' L2 D' F2 L2 D' L2 F2 D' B2 R2 U' R2"
            ),
            Pattern(
                "Twisted rings",
                "B8bpvYZzzA8",
                "ruwix2",
                "F D F' D2 L' B' U L D R U L' F' U L U2",
                "L F2 R2 F2 R' U2 R D' L' F2 L' U L' F' U B2 D R'"
            ),
            Pattern(
                "Exchanged rings",
                "E9XfXtBfYiC",
                "ruwix2",
                "B' U' B' L' D B U D2 B U L D' L' U' L2 D",
                "F2 D R2 B2 L2 B2 U L2 U' F2 U R2 B L' D L2 D' L B"
            ),
            Pattern(
                "Twisted chicken feet",
                "B8aYSfwpkD_",
                "ruwix2",
                "F L' D F' U' B U F U' F R' F2 L U' R' D2",
                "B' L' B R2 B' R' D U' F B L F2 R' D2 L U2 L' D2 L D2"
            )
        }

    /// Patterns 97 to 110; see `all`.
    def part7(): Vector[Pattern] =
        Vector#{
            Pattern(
                "Exchanged chicken feet",
                "Au4Ic-LW5f_",
                "ruwix2",
                "F L' D' B' L F U F' D' F L2 B' R' U L2 D' F",
                "R F' D2 B2 U' L B D F' R' U F R2 L D2 R B2 L' F2"
            ),
            Pattern(
                "Twin Peaks",
                "AAA5Peox9pB",
                "ruwix2",
                "U L2 B2 R2 U R2 D' U L F' U L' D B' U L B' L R' U'",
                "B U2 R2 B' D2 R2 B R2 B L2 B' U' L B' L' R F2 B' L R' F"
            ),
            Pattern(
                "Corner pyramid",
                "AAA3VRznG31",
                "ruwix2",
                "U' D B R' F R B' L' F' B L F R' B' R F' U' D",
                "D' L U F R' B' L' B2 L D L2 U2 R2 D B2 L2 D' R2 U' R2 L2"
            ),
            Pattern(
                "Exchanged peaks",
                "ADNzExkJZIA",
                "ruwix2",
                "F U2 L F L' B L U B' R' L' U R' D' F' B R2",
                "B' U' R U2 R' U B' R2 U2 F2 U' F2 U' B2 D2 F2 L2 D' F2"
            ),
            Pattern(
                "Megatron",
                "B8c68lhjMV9",
                "ruwix2",
                "U L D R' F D2 R2 F2 R' F D2 B L2 U2 D' R2 U R2 B2 L2",
                "L' F2 U D L' F B' R' D F' U' F2 R2 F2 R2 F2 D B2 U2 D' R2"
            ),
            Pattern(
                "Six-two-one",
                "A4h45CngHAo",
                "ruwix2",
                "U B2 D2 L B' L' U' L' B D2 B2",
                "L' U2 R2 F' U F L F U' R2 U2"
            ),
            Pattern(
                "Yin Yang",
                "Ku-v22EapD_",
                "ruwix2",
                "R L B F R L U' D' F' B' U D",
                "B F' R L B2 U' D' B U2 D2 B F R2 L2 B'"
            ),
            Pattern(
                "Henry's snake",
                "BdunEhkrRgA",
                "ruwix2",
                "R2 F2 U' D' B2 L2 F2 L2 U D R2 F2",
                "F2 R2 D' U' L2 F2 L2 B2 D U F2 R2"
            ),
            Pattern(
                "Snake eyes",
                "AAAAAAAGGgA",
                "ruwix2",
                "R2 U2 R2 U2 R2 U2",
                "R2 U2 R2 U2 R2 U2"
            ),
            Pattern(
                "Glitch",
                "AAAAAAAAyAA",
                "ruwix2",
                "F' L' B' R' U' R B L F U",
                "F' L' B' R' U' R B L F U"
            ),
            Pattern(
                "Weirdo",
                "A-wUefJHJa0",
                "ruwix2",
                "R' F' U F2 U' F R' F2 D2 F2 D2 F2 D F2 R2 U2",
                "R2 L' F U' F2 U F' L D' F2 D2 F2 D2 R2 U2"
            ),
            Pattern(
                "Twisted corners",
                "AACifmY8AAA",
                "ruwix2",
                "F U D R2 F2 U' B U B U R2 B' U L2 U B2 U2 F2 L2 U'",
                "U2 R2 D2 B2 D L2 D F2 D L2 U' F D B F' D' L2 F' D L2 B"
            ),
            Pattern(
                "Quick maths 1+1",
                "E9XfY6e_NgA",
                "ruwix2",
                "R L F2 U2 R' L' F2 U2 R2 F2 U R2 L2 F2 B2 D'",
                "F2 D2 L2 B2 U' B2 F2 L2 R2 D L2 B2 U2 R2"
            ),
            Pattern(
                "Scrambled 2x2s",
                "E9WN6xYr1Ro",
                "ruwix2",
                "U2 B' R U' L F B2 U F' U F2 L2 U D B2 L2 B2 L2",
                "F2 L2 U2 L2 U' B2 R2 D B2 U' B R' U B' U' L U R2"
            )
        }

    /// Kewbz variants whose states are not already in the canonical collection.
    def part8(): Vector[Pattern] =
        Vector#{
            Pattern(
                "4H",
                "AAAAAOWjXgA",
                "kewbz3",
                "(M2 U2 M2 U2 y)x2",
                "B2 L2 B2 D U' R2 F2 R2 D U'"
            ),
            Pattern(
                "4I",
                "AAAAAAAAEAA",
                "kewbz3",
                "(M2 U2 M2 U2 x)x2",
                "B2 L2 R2 F2 D2 L2 R2 U2"
            )
        }

    ///
    /// Every pattern. The collection is split into parts only so that no
    /// one definition is enormous.
    ///
    pub def all(): Vector[Pattern] =
        Vector.flatten(
            Vector#{
                part1(),
                part2(),
                part3(),
                part4(),
                part5(),
                part6(),
                part7(),
                part8()
            }
        )

}
