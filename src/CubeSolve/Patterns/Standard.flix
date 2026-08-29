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
mod CubeSolve.Patterns.Standard {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
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
    /// See `CubeSolve.Patterns` for why the 2x2x2 cannot use it.
    ///
    pub def identify(c: Cube.Cube): Option[String] =
        Rotation.all()
            |> Vector.toList
            |> List.filterMap(r -> Facelets.token(Cube.conjugate(r, c)) |> Result.toOption)
            |> List.minimum

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
            r <- Rotation.all() |> Vector.findLeft(r ->
                Facelets.token(Cube.conjugate(r, upright)) == Ok(target))
        ) yield r

    ///
    /// Every pattern.
    ///
    ///
    /// Patterns 1 to 16; see `all`.
    def part1(): Vector[Pattern] = Vector#{
        Pattern("Pons Asinorum", "AAAAAH1cCIAA", "speedsolving",
            "M2 E2 S2",
            "B2 F2 L2 R2 D2 U2"),
        Pattern("6-Spot", "A2HhlNl3V8_4", "speedsolving",
            "M S M' S'",
            "L' R U' D B' F L' R"),
        Pattern("4-Spot", "A1j7i5sgWbgA", "speedsolving",
            "M2 S M2 S'",
            "B2 F2 U2 B2 F2 L2 B2 F2 R2 U2"),
        Pattern("Two-face checkerboard", "AAAAAAOibXgA", "speedsolving",
            "L2 F2 R2 B2 L2 F2 R2 B2 L2 F2 R2 B2",
            "F2 R2 B2 F2 R2 F2 L2 R2"),
        Pattern("Superflip", "AAAAAAAAAAf_", "speedsolving",
            "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2",
            "U2 B2 L2 F D2 U2 B R2 B L2 D2 F' D U' L' F B' D2 L2 D' L' R'"),
        Pattern("Superflip (easier, rotations)", "AAAAAAAAAAHl", "speedsolving",
            "M U M U M U M U x y' M U M U M U M U x y' M U M U M U M U x y'",
            "F' D B2 L' B D' L' D' L' D L2 B' L2 B' R2 U2 B' F2 R2 D2"),
        Pattern("Speedsolving.com logo", "A26_UJWKQIAA", "speedsolving",
            "U2 B2 U2 B2 L R F2 D2 F2 U2 L' R'",
            "F2 R2 D' U' L2 B2 L2 B2 D U F2 R2"),
        Pattern("Three faces scrambled", "AAAAAA19AwyE", "speedsolving",
            "U' D L2 U B2 D2 B2 D2 L F' U D' R U' F2 L F' B'",
            "B2 L' U2 L2 F2 R B2 U2 D' L2 F U2 B2 L2 F' R2 U D2"),
        Pattern("SpeedSolving", "A0HCSc1uFUAA", "ruwix1",
            "R' L' U2 F2 D2 F2 R L B2 U2 B2 U2",
            "F2 R2 D U L2 B2 L2 B2 D' U' F2 R2"),
        Pattern("3 sides solved", "AA8-0S7BXrEy", "ruwix1",
            "U2 D R' D B' L2 B D' R L2 U2 B2 L2 B2 D R2 L2 D R2",
            "L B R' B' D' L B2 R' D2 R2 B' F R2 F U2 R2 F' L2"),
        Pattern("All flags & crests", "A00mugWbu7__", "ruwix1",
            "B2 U' B2 L2 U B2 U R2 B2 U' L' R' B D U' L2 F2 R'",
            "U' F' B' R' F B' R L' F U D R' U2 F2 D2 L2 U2"),
        Pattern("Wire", "AC7dOJKEaAAA", "ruwix1",
            "R L F B R L F B R L F B R2 B2 L2 R2 B2 L2",
            "D' R2 B2 U2 B2 R2 U2 R2 D' U R2 U'"),
        Pattern("Checkerboard in the cube", "A2Hg_EdOyc9d", "ruwix1",
            "B D F' B' D L2 U L U' B D' R B R D' R L' F U2 D",
            "R2 F2 L U2 L B2 L F2 R' U' D B' L' F D' F' R2 F U R"),
        Pattern("Perfect Scramble", "A3d25sCQuzM2", "ruwix1",
            "U F' L' U' R2 F' R2 B' U' R F' U F D' L2 F2 L2 U'",
            "D2 L2 F2 L2 F L2 F R2 F' R F D L D' F B' D R2 B R"),
        Pattern("( ! ) (ˆ⌣ˆԅ)", "A2HfuU0x98gH", "ruwix1",
            "U' F2 R' L' U' B R2 D B U' R2 L B2 D' B2 U F2 B2 U' L2 B2 L2",
            "D B2 R L D F' L2 U' F' D R' L2 F2 U F2 D' F2 B2 D R2 F2 R2"),
        Pattern("Minority cross", "A7WRgdLkQKUk", "ruwix1",
            "L2 D' B2 L2 B2 D' F2 D U' B2 L B2 F' L B' F U' F' U L2",
            "R D2 L' B2 F2 L F2 R' F U2 F U' D L' F2 L' B' F")
    }

    /// Patterns 17 to 32; see `all`.
    def part2(): Vector[Pattern] = Vector#{
        Pattern("Perpendicular lines", "A1j7i0ySHEAA", "ruwix1",
            "R2 U2 L2 R2 U2 L2 M2",
            "R2 U2 L2 R2 U2 R2"),
        Pattern("Flipped tips", "AAAA2M6ZoAAA", "ruwix1",
            "U B D' F2 D B' U' R2 D F2 D' R2 D F2 D' R2",
            "L F U2 F' U2 F' L' F L2 B' U2 B U2 L2"),
        Pattern("Plus minus", "A1j7ix9_YDgA", "ruwix1",
            "U2 R2 L2 U2 R2 L2",
            "L2 R2 U2 L2 R2 U2"),
        Pattern("Tablecloth", "AK9WrY2373f4", "ruwix1",
            "R L U2 F' U2 D2 R2 L2 F' D2 F2 D R2 L2 F2 B2 D B2 L2",
            "R F2 D B F' U D' B' U2 R B F D2 B' U2 D2 B' L2 B2"),
        Pattern("Deckerboard", "A7WRgc3m3B1X", "ruwix1",
            "U D R L' F' B U D' R2 U R2 L2 D2 F2 B2 D",
            "B R2 L2 B2 U' D R L' B' F D' B2 U2 D2 F2 D2"),
        Pattern("Spiral pattern", "A2Hg_EdOyc64", "ruwix1",
            "L' B' D U R U' R' D2 R2 D L D' L' R' F U",
            "F U F' R F D' L D B' D' B R2 L2 U2 B' L2 F R2 D2 F' L2"),
        Pattern("Fruit bowl", "A2HhlNltgIf4", "ruwix1",
            "B2 L2 F2 R2 F2 R2 D U B2 U2 B' F' L' R' D' U'",
            "B' F R L U' D' B' F' R2 B2 L2"),
        Pattern("Flower", "AAAAAAOjpIgA", "ruwix1",
            "R2 D2 R2 U2 R2 F2 U2 D2 F2 U2",
            "L2 D U B2 U2 B2 L2 R2 D' U'"),
        Pattern("Vertical stripes", "AJnXgWRXYDgH", "ruwix1",
            "F U F R L2 B D' R D2 L D' B R2 L F U F",
            "L2 D2 B L2 B U2 F L2 F2 B' U' B2 L' F2 R2 U' L' U' R' D' F"),
        Pattern("Gift box", "BBac1vuyAIAH", "ruwix1",
            "U B2 R2 B2 L2 F2 R2 D' F2 L2 B F' L F2 D U' R2 F' L' R'",
            "R L B L2 U D' B2 R F B' U2 B2 U' F2 U2 R2 B2 R2 D2 L2 D'"),
        Pattern("Opposite corners", "A26_UOldoAAA", "ruwix1",
            "R L U2 F2 D2 F2 R L F2 D2 B2 D2",
            "B2 L2 D U R2 B2 R2 B2 D' U' F2 R2"),
        Pattern("Cross", "A2HhlCJXYAAA", "ruwix1",
            "R2 L' D F2 R' D' R' L U' D R D B2 R' U D2",
            "F D2 B2 L2 R2 B2 U2 B D2 U2 B2 U F2 B2 D2 L2 R2 D"),
        Pattern("4 crosses", "A1j7ix9_YAAA", "ruwix1",
            "U2 R2 L2 F2 B2 D2 L2 R2 F2 B2",
            "F2 R2 F2 D' U R2 F2 R2 D U'"),
        Pattern("Union Jack", "A7WRga3w4AAA", "ruwix1",
            "U F B' L2 U2 L2 F' B U2 L2 U",
            "U' B2 F2 L2 B2 F2 D2 U2 R2 D2 U'"),
        Pattern("Cube in the cube", "A2Hg_EcIYz4Y", "ruwix1",
            "F L F U' R U F2 L2 U' L' B D' B' L2 U",
            "L' F2 R' B' U B' U B' U R F2 L' B2 D2 L2"),
        Pattern("Cube in a cube in a cube", "A2HhVJs0Az4Y", "ruwix1",
            "U' L' U' F' R2 B' R F U B2 U B' L U' F U R F'",
            "U' D' L' F R2 B2 L F U' L2 U R2 F2 U' L2 D F2 L2 U2")
    }

    /// Patterns 33 to 48; see `all`.
    def part3(): Vector[Pattern] = Vector#{
        Pattern("Anaconda", "A2HhlCO880Hg", "ruwix1",
            "L U B' U' R L' B R' F B' D R D' F'",
            "F L2 R2 F B' U2 L D U' L F' B D' F' R2 D'"),
        Pattern("Python", "A7WRga4PIXHO", "ruwix1",
            "F2 R' B' U R' L F' L F' B D' R B L2",
            "B' R' U R2 U' R B R2 U F2 B2 R2 U' F2 U R2 U' F2"),
        Pattern("Black mamba", "A2HhlM-xDXSo", "ruwix1",
            "R D L F' R L' D R' U D' B U' R' D'",
            "R D B D R' D B D2 R F2 D' F2 D2 R' B2 D2"),
        Pattern("Green mamba", "A2HhlM-_GXSo", "ruwix1",
            "R D R F R' F' B D R' U' B' U D2",
            "U L2 F R L' U' L2 F' D2 F2 R' F2 B2 L B2 D2"),
        Pattern("Tangled", "A26_UMYOF3gA", "ruwix1",
            "F B U D F B U D F B U D F2 B2",
            "R2 B2 R2 B2 D U B2 R2 F2 R2 D U"),
        Pattern("Twister", "A2Hg_D4vj_QI", "ruwix1",
            "F R' U L F' L' F U' R U L' U' L F'",
            "F' L2 B L' F2 L D' B2 D B R2 L2 F2 R2 F"),
        Pattern("Kilt (Scottish skirt)", "A2HhlLmQ2aVX", "ruwix1",
            "U' R2 L2 F2 B2 U' R L F B' U F2 D2 R2 L2 F2 U2 F2 U' F2",
            "B U2 D2 R2 L2 B U' D' R L' B R2 B2 L2 U2 D2 B2 L2 B' L2"),
        Pattern("Tetris", "A27EGgaOVt1X", "ruwix1",
            "L R F B U' D' L' R'",
            "U2 L2 U2 R2 F B L2 D2 R2 D' U L R F B"),
        Pattern("Don't cross line", "A1j7i5du0wAA", "ruwix1",
            "F2 L2 R2 B2 E2",
            "B2 L2 R2 F2 D2 U2"),
        Pattern("Hi", "AAAAAAAAADgA", "ruwix1",
            "M2 U2 M2 U2",
            "L2 R2 D2 L2 R2 U2"),
        Pattern("Hi all around", "AAAAAC0SvPgA", "ruwix1",
            "U2 R2 F2 U2 D2 F2 L2 U2",
            "U2 L2 F2 D2 U2 F2 R2 U2"),
        Pattern("Displaced Motif", "A6Afmq9fBkw8", "ruwix1",
            "L2 B2 D' B2 D L2 U R2 D R2 B U R' F2 R U' B' U'",
            "U' L' U' F R2 F' U L F2 D F2 U B2 D L2 D' L2 B2"),
        Pattern("Are you high?", "AAAAAAqeNcAA", "ruwix1",
            "L R' U2 D2 L' R U2 D2 R2 L2",
            "L2 B2 F2 R2 D' U' L2 R2 D' U'"),
        Pattern("C U around", "A2HhlNiE8P64", "ruwix1",
            "U' B2 U L2 D L2 R2 D' B' R D' L R' B2 U2 F' L' U'",
            "R' U2 R U2 F L R D' R' F' R U B' R'"),
        Pattern("Order in chaos", "A2Hg-6LEs5FV", "ruwix1",
            "B L2 B' U2 B F2 U L U B U' R U' B F U' R D R B' U'",
            "U' B2 D' L D2 R F' U2 B' U' D2 F2 B2 L2 U' R2 F2 D2 F2 B2"),
        Pattern("Evenly distributed", "AAAEyZbn45qo", "ruwix1",
            "D' B2 D' L2 R2 D B2 L2 D' B2 L R' F' L2 D U' F2 R' D' U'",
            "F2 U2 R U2 F2 U2 R' B' L B D' L R' B2 U2 B' R' D' R'")
    }

    /// Patterns 49 to 64; see `all`.
    def part4(): Vector[Pattern] = Vector#{
        Pattern("The hole", "AK9WrY8BIYqv", "ruwix1",
            "R L' F' B D U'",
            "L' R B F' U' D"),
        Pattern("No entry", "A7WRgiIrYK3-", "ruwix1",
            "U' L' B R L' D' L B' U F2 R2 B2 D2 B2 R2 B2 D B2",
            "D2 F' B R2 F' B D' B R' U L R' F' R U' B"),
        Pattern("\"Plus\"", "A1j7i0dLqAgA", "ruwix1",
            "B2 F2 R2 U2 B2 F2 R2 U2 R2 U2",
            "B2 F2 R2 U2 B2 F2 R2 U2 R2 U2"),
        Pattern("3C3W", "AAEjmAWj1cRV", "ruwix1",
            "D L B' L L F L' B' U D' R L' F B D L'",
            "U2 R B2 L' D2 B' D2 F U L2 D' B' L' D B D' R'"),
        Pattern("Pong", "A1j7ix-Tx8gA", "ruwix1",
            "U R2 F2 B2 L2 U2 D R2 F2 B2 L2",
            "L2 B2 F2 R2 D' L2 B2 F2 R2 D2 U'"),
        Pattern("Spun T's", "A2HhlM-SL_QI", "ruwix1",
            "U' L2 F2 L2 F2 D' L2 F' L2 F' D U2 L' B L B' U'",
            "R' F2 D2 F2 D2 L' F2 D' F2 D' L R2 F' U F U' R'"),
        Pattern("Wifi Downstairs", "A0pVzmWpNJAA", "ruwix1",
            "R U' R F2 R' U R F2 U' B2 U D R2 U' L2 D' L2",
            "B2 D B2 D' R2 D' B2 D R2 U' F2 R2 U R2 F2 U'"),
        Pattern("Opposite pillars", "A1j7i5P9uAAA", "ruwix2",
            "R2 F2 L2 R2 F2 L2",
            "L2 F2 L2 R2 F2 R2"),
        Pattern("Viaduct", "AK9WrXvHWAgH", "ruwix2",
            "R2 U2 L2 D B2 L2 B2 R2 D' U L' D F' U' R2 F' U B2 U2 R'",
            "B R' U2 F' L' U D' B L U2 F R'"),
        Pattern("Solved in scrambled", "AAABjtHDG7iC", "ruwix2",
            "U2 L' U2 L' U2 F2 D L F' L F R2 D' B2 D' L2 D' L2 F2 R2",
            "F2 U R2 B U L U' L' B' R2 F R2 F2 U2 F' L2 D2 B' D2 L2"),
        Pattern("Hi Ohio", "A1j7i5P9uIAA", "ruwix2",
            "U2 F2 L2 R2 F2 U2",
            "U2 F2 L2 R2 F2 U2"),
        Pattern("Staircase", "AAAA2NGUHCtI", "ruwix2",
            "L2 F2 D' L2 B2 D' U' R2 B2 U' L' B2 L D L B' D L' U",
            "L' F' U2 F2 U' L F' D R' L2 B2 D' R2 D B2 R2 L2 D'"),
        Pattern("Wrapped 2x2", "ADctD1Y0h59C", "ruwix2",
            "D' B2 F2 L2 U' F2 R2 D F2 U2 L' B R' U' L' F D' F L D2",
            "B R2 F2 L2 B' U2 B L F' L2 U' F' L' R2 D L D' B"),
        Pattern("Antipodal chaos", "A2Ha7-OY4vgA", "ruwix2",
            "U2 L2 U2 L2 U2 F2 R2 F2 U2 F2",
            "F' B L2 D2 L2 D2 F' B' R2"),
        Pattern("Flower field", "A2HhlPT_6jf4", "ruwix2",
            "M S M' S' R2 L2 U2 D2 F2 B2",
            "R' L' D U' F' B R L' D2 F2 R2 L2 F2"),
        Pattern("C spirals", "A2Ha78IIXPgA", "ruwix2",
            "B' F' L2 D2 B' F U2 R2 F2",
            "D' U' B2 L2 D' U R2 F2 U2")
    }

    /// Patterns 65 to 80; see `all`.
    def part5(): Vector[Pattern] = Vector#{
        Pattern("Worms", "AAAAAABj2FgA", "ruwix2",
            "U' F2 L2 U D2 F2 B2 U F2 L2 D",
            "U' B2 R2 D2 U' L2 R2 U' B2 R2 D"),
        Pattern("Glider", "A00h8NL2rdAA", "ruwix2",
            "D2 R2 F2 R2 U2 B2 D2 F2 L2 U2 R2 U2",
            "D2 R2 F2 R2 U2 B2 D2 F2 L2 U2 R2 U2"),
        Pattern("Quote", "A1j7i0e4CkgA", "ruwix2",
            "U2 F2 D2 B2 R2 U2 B2 R2 U2 R2",
            "B2 U2 B2 L2 D2 F2 R2 U2 R2 U2"),
        Pattern("Matching pictures", "A5_xzpeIzIgs", "ruwix2",
            "R' D2 R L D2 L'",
            "L' F2 R L F2 R'"),
        Pattern("Loose strap", "A1j7i0yRfsgA", "ruwix2",
            "F2 U2 B2 U2 F2 U2",
            "F2 U2 B2 U2 F2 U2"),
        Pattern("Doubler", "AC7dOGj7wDgA", "ruwix2",
            "R L U2 R L' D2 R2 F2 U2 F2 U2 L2 F2 U2 L2",
            "L2 F2 R2 F2 D U B2 R2 F2 R2 D U"),
        Pattern("3T", "A0RhCWKUmzgA", "ruwix2",
            "B U2 L2 F2 R2 F D2 F2 R2 F' R2 U2",
            "B U2 L2 B2 L2 B' U2 B2 L2 B R2 U2"),
        Pattern("4 T", "A0zOGOUIGAAA", "ruwix2",
            "F2 D2 F' L2 D2 U2 R2 B' U2 F2",
            "B2 L2 R2 F2 D' L2 B2 F2 R2 U'"),
        Pattern("6 T", "A2Ha7-b_cTgA", "ruwix2",
            "F2 R2 U2 F' B D2 L2 F B",
            "D2 B2 L2 D U' R2 F2 D' U'"),
        Pattern("ZZ-Line", "AC7dOLzPIDgA", "ruwix2",
            "R L U2 R L' U2 F2 R2 U2 F2 D2 B2 L2 U2 L2",
            "F2 L2 B2 R2 D' U' L2 B2 R2 F2 D U"),
        Pattern("Checker zigzag", "AAAAADEIzegA", "ruwix2",
            "R2 L2 F2 B2 U F2 B2 U2 F2 B2 U",
            "B2 F2 L2 R2 U' B2 F2 U2 B2 F2 U'"),
        Pattern("Exchanged duck feet", "A6IZpkduNDoI", "ruwix2",
            "U F R2 F' D' R U B2 U2 F' R2 F D B2 R B'",
            "R' L2 F D' F2 D F' R' R2 U' B2 R2 U' B2 U2 L2 D F2 D2"),
        Pattern("Stripe dot solved", "A1j7i5P9uDgA", "ruwix2",
            "D U B2 F2 D' U'",
            "D U B2 F2 D' U'"),
        Pattern("Picnic", "A0zOGO3WUIgA", "ruwix2",
            "D2 R2 L2 F2 B2",
            "D2 B2 F2 L2 R2"),
        Pattern("Percent sign %", "AC7dOGyeLXgA", "ruwix2",
            "R L U2 R L' U2 F2 L2 U2 F2 U2 F2 R2 U2 R2",
            "F2 L2 B2 L2 D U L2 F2 R2 F2 D U"),
        Pattern("Mirror", "A1l1f4L7lfgA", "ruwix2",
            "U D F2 B2 U' D' R2 L2 B2",
            "F' B' D2 U2 F B'")
    }

    /// Patterns 81 to 96; see `all`.
    def part6(): Vector[Pattern] = Vector#{
        Pattern("Plus minus check", "A1j7iyMhzUAA", "ruwix2",
            "U D R2 L2 U D R2 L2",
            "L2 R2 D' U' L2 R2 D' U'"),
        Pattern("Hi again", "AAAAAActG0AA", "ruwix2",
            "U2 D2 L2 U2 D2 R2 F2 B2 L2 F2 B2 R2 U2 D2 F2 U2 D2 B2",
            "B2 F2 D' U' B2 L2 R2 F2 D' U'"),
        Pattern("4 plus 2 dots", "A7WRghtBSyVX", "ruwix2",
            "F U2 D2 R L U' D F B R U2 R2 U2 F2 L2 U2 F2 L2 B2",
            "L2 R2 B2 U2 D2 F L R' U' D B' F R2 U2 D2 R'"),
        Pattern("Rockets", "A0zOGHCeJ8gA", "ruwix2",
            "U R2 F2 R2 U' D F2 R2 F2 D",
            "B2 F2 L2 R2 U2 B2 F2 L2 R2"),
        Pattern("Slash", "AC7dOJKEaIAA", "ruwix2",
            "R L F B R L F B R L F B",
            "D' L2 B2 D2 F2 R2 D2 L2 D' U R2 U'"),
        Pattern("The pillars", "A1j7i5du0zgA", "ruwix2",
            "L2 R2 B2 F2",
            "B2 F2 L2 R2"),
        Pattern("Twisted duck feet", "A2Hg-5JaU0Hg", "ruwix2",
            "F R' B R U F' L' F' U2 L' U' D2 B D' F B' U2",
            "B' U2 L U B' R' F' D' F' D' R' D2 B L2 B' R2 F U2 B2 F"),
        Pattern("Ron's cube in a cube", "A02FBz1nSbAA", "ruwix2",
            "F D' F' R D F' R' D R D L' F L D R' F D'",
            "B2 L2 U2 L2 U' L2 B2 D2 F2 U F2 R2 U2 R2 U'"),
        Pattern("Crossing snake", "AC7dOJKEaLgA", "ruwix2",
            "R L U2 R L' U2 F2 R2 D2 B2 D2 B2 L2 D2 R2",
            "F2 L2 F2 L2 D' U' L2 B2 R2 F2 D' U'"),
        Pattern("Cage", "AJpYII7GuMLQ", "ruwix2",
            "L U F2 R L' U2 B' U D B2 L F B' R' L F' R",
            "B2 D U L2 F2 D B2 U F2 D2 R2 B L B2 U2 F' D' R U2 B"),
        Pattern("4 crosses (second list)", "AK-bRtpiQAAA", "ruwix2",
            "F2 B2 R F2 B2 R F2 B2 R F2 B2 R F2 B2 R F2 B2 R",
            "L' F2 B2 U2 D2 R' U2 D2 F2 B2"),
        Pattern("Pyraminx", "AAAAAACjmflC", "ruwix2",
            "D L' U R' B' R B U2 D B D' B' L U D'",
            "B2 D L F2 R2 U L B' L U' R U2 R U2 L' D2 R L B2 U2"),
        Pattern("Edge triangle", "AAAAAAAZsxS1", "ruwix2",
            "U B2 U' F' U' D L' D2 L U D' F D' L2 B2 D'",
            "B' D' L D2 L' D B' L2 D' F2 L2 D' L2 F2 D' B2 R2 U' R2"),
        Pattern("Twisted rings", "A2HhlNhrAz4Y", "ruwix2",
            "F D F' D2 L' B' U L D R U L' F' U L U2",
            "L F2 R2 F2 R' U2 R D' L' F2 L' U L' F' U B2 D R'"),
        Pattern("Exchanged rings", "A7WRga4Pleni", "ruwix2",
            "B' U' B' L' D B U D2 B U L D' L' U' L2 D",
            "F2 D R2 B2 L2 B2 U L2 U' F2 U R2 B L' D L2 D' L B"),
        Pattern("Twisted chicken feet", "A2Hg_EgUt8_4", "ruwix2",
            "F L' D F' U' B U F U' F R' F2 L U' R' D2",
            "B' L' B R2 B' R' D U' F B L F2 R' D2 L U2 L' D2 L D2")
    }

    /// Patterns 97 to 110; see `all`.
    def part7(): Vector[Pattern] = Vector#{
        Pattern("Exchanged chicken feet", "A6IZpweFZLKo", "ruwix2",
            "F L' D' B' L F U F' D' F L2 B' R' U L2 D' F",
            "R F' D2 B2 U' L B D F' R' U F R2 L D2 R B2 L' F2"),
        Pattern("Twin Peaks", "AAAA2Nx4-elC", "ruwix2",
            "U L2 B2 R2 U R2 D' U L F' U L' D B' U L B' L R' U'",
            "B U2 R2 B' D2 R2 B R2 B L2 B' U' L B' L' R F2 B' L R' F"),
        Pattern("Corner pyramid", "AAAB1GXArG3z", "ruwix2",
            "U' D B R' F R B' L' F' B L F R' B' R F' U' D",
            "D' L U F R' B' L' B2 L D L2 U2 R2 D B2 L2 D' R2 U' R2 L2"),
        Pattern("Exchanged peaks", "A55Td-AnRDAF", "ruwix2",
            "F U2 L F L' B L U B' R' L' U R' D' F' B R2",
            "B' U' R U2 R' U B' R2 U2 F2 U' F2 U' B2 D2 F2 L2 D' F2"),
        Pattern("Megatron", "A2HhVJt6ac9d", "ruwix2",
            "U L D R' F D2 R2 F2 R' F D2 B L2 U2 D' R2 U R2 B2 L2",
            "L' F2 U D L' F B' R' D F' U' F2 R2 F2 R2 F2 D B2 U2 D' R2"),
        Pattern("Six-two-one", "ABxB2qFUAOig", "ruwix2",
            "U B2 D2 L B' L' U' L' B D2 B2",
            "L' U2 R2 F' U F L F U' R2 U2"),
        Pattern("Yin Yang", "A1kAVI0SXF1X", "ruwix2",
            "R L B F R L U' D' F' B' U D",
            "B F' R L B2 U' D' B U2 D2 B F R2 L2 B'"),
        Pattern("Henry's snake", "AC7dOJDJWjgA", "ruwix2",
            "R2 F2 U' D' B2 L2 F2 L2 U D R2 F2",
            "F2 R2 D' U' L2 F2 L2 B2 D U F2 R2"),
        Pattern("Snake eyes", "AAAAAAAAMNAA", "ruwix2",
            "R2 U2 R2 U2 R2 U2",
            "R2 U2 R2 U2 R2 U2"),
        Pattern("Glitch", "AAAAAA3dZLAA", "ruwix2",
            "F' L' B' R' U' R B L F U",
            "F' L' B' R' U' R B L F U"),
        Pattern("Weirdo", "A-Hk308HXIw8", "ruwix2",
            "R' F' U F2 U' F R' F2 D2 F2 D2 F2 D F2 R2 U2",
            "R2 L' F U' F2 U F' L D' F2 D2 F2 D2 R2 U2"),
        Pattern("Twisted corners", "AAAFE_Mx4AAA", "ruwix2",
            "F U D R2 F2 U' B U B U R2 B' U L2 U B2 U2 F2 L2 U'",
            "U2 R2 D2 B2 D L2 D F2 D L2 U' F D B F' D' L2 F' D L2 B"),
        Pattern("Quick maths 1+1", "A7WRgbGTTXgA", "ruwix2",
            "R L F2 U2 R' L' F2 U2 R2 F2 U R2 L2 F2 B2 D'",
            "F2 D2 L2 B2 U' B2 F2 L2 R2 D L2 B2 U2 R2"),
        Pattern("Scrambled 2x2s", "A7WP0IsHIzW3", "ruwix2",
            "U2 B' R U' L F B2 U F' U F2 L2 U D B2 L2 B2 L2",
            "F2 L2 U2 L2 U' B2 R2 D B2 U' B R' U B' U' L U R2")
    }

    ///
    /// Every pattern. The collection is split into parts only so that no
    /// one definition is enormous.
    ///
    pub def all(): Vector[Pattern] =
        Vector.flatten(Vector#{
            part1(),
            part2(),
            part3(),
            part4(),
            part5(),
            part6(),
            part7()
        })

}
