///
/// Every published 3x3x3 pattern this project knows about, as a fixture.
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
mod PatternFixtures {

    use PatternFixtures.Pattern.Pattern

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
    pub def source(p: Pattern): String = let Pattern(_, s, _, _, _) = p; s

    ///
    /// The algorithm as published.
    ///
    pub def notation(p: Pattern): String = let Pattern(_, _, a, _, _) = p; a

    ///
    /// The same pattern using face turns only.
    ///
    pub def htm(p: Pattern): String = let Pattern(_, _, _, h, _) = p; h

    ///
    /// The pattern's identity: the smallest token over all 24 orientations.
    ///
    pub def canonical(p: Pattern): String = let Pattern(_, _, _, _, c) = p; c

    ///
    /// The URL a source id refers to.
    ///
    pub def url(id: String): String = match id {
        case "speedsolving" => "https://www.speedsolving.com/wiki/index.php/List_of_pretty_patterns"
        case "ruwix1" => "https://ruwix.com/the-rubiks-cube/rubiks-cube-patterns-algorithms/"
        case "ruwix2" =>
            "https://ruwix.com/the-rubiks-cube/rubiks-cube-patterns-algorithms/"
                + "more-rubiks-patterns/"
        case _ => "unknown"
    }

    ///
    /// Every pattern.
    ///
    ///
    /// Patterns 1 to 16; see `all`.
    def part1(): Vector[Pattern] = Vector#{
        Pattern("Pons Asinorum", "speedsolving",
            "M2 E2 S2",
            "B2 F2 L2 R2 D2 U2", "AAAAAH1cCIAA"),
        Pattern("6-Spot", "speedsolving",
            "M S M' S'",
            "L' R U' D B' F L' R", "A2HhlNl3V8_4"),
        Pattern("4-Spot", "speedsolving",
            "M2 S M2 S'",
            "B2 F2 U2 B2 F2 L2 B2 F2 R2 U2", "A1j7i5sgWbgA"),
        Pattern("Two-face checkerboard", "speedsolving",
            "L2 F2 R2 B2 L2 F2 R2 B2 L2 F2 R2 B2",
            "F2 R2 B2 F2 R2 F2 L2 R2", "AAAAAAOibXgA"),
        Pattern("Superflip", "speedsolving",
            "U R2 F B R B2 R U2 L B2 R U' D' R2 F R' L B2 U2 F2",
            "U2 B2 L2 F D2 U2 B R2 B L2 D2 F' D U' L' F B' D2 L2 D' L' R'", "AAAAAAAAAAf_"),
        Pattern("Superflip (easier, rotations)", "speedsolving",
            "M U M U M U M U x y' M U M U M U M U x y' M U M U M U M U x y'",
            "F' D B2 L' B D' L' D' L' D L2 B' L2 B' R2 U2 B' F2 R2 D2", "AAAAAAAAAAHl"),
        Pattern("Speedsolving.com logo", "speedsolving",
            "U2 B2 U2 B2 L R F2 D2 F2 U2 L' R'",
            "F2 R2 D' U' L2 B2 L2 B2 D U F2 R2", "A26_UJWKQIAA"),
        Pattern("Three faces scrambled", "speedsolving",
            "U' D L2 U B2 D2 B2 D2 L F' U D' R U' F2 L F' B'",
            "B2 L' U2 L2 F2 R B2 U2 D' L2 F U2 B2 L2 F' R2 U D2", "AAAAAA19AwyE"),
        Pattern("SpeedSolving", "ruwix1",
            "R' L' U2 F2 D2 F2 R L B2 U2 B2 U2",
            "F2 R2 D U L2 B2 L2 B2 D' U' F2 R2", "A0HCSc1uFUAA"),
        Pattern("3 sides solved", "ruwix1",
            "U2 D R' D B' L2 B D' R L2 U2 B2 L2 B2 D R2 L2 D R2",
            "L B R' B' D' L B2 R' D2 R2 B' F R2 F U2 R2 F' L2", "AA8-0S7BXrEy"),
        Pattern("All flags & crests", "ruwix1",
            "B2 U' B2 L2 U B2 U R2 B2 U' L' R' B D U' L2 F2 R'",
            "U' F' B' R' F B' R L' F U D R' U2 F2 D2 L2 U2", "A00mugWbu7__"),
        Pattern("Wire", "ruwix1",
            "R L F B R L F B R L F B R2 B2 L2 R2 B2 L2",
            "D' R2 B2 U2 B2 R2 U2 R2 D' U R2 U'", "AC7dOJKEaAAA"),
        Pattern("Checkerboard in the cube", "ruwix1",
            "B D F' B' D L2 U L U' B D' R B R D' R L' F U2 D",
            "R2 F2 L U2 L B2 L F2 R' U' D B' L' F D' F' R2 F U R", "A2Hg_EdOyc9d"),
        Pattern("Perfect Scramble", "ruwix1",
            "U F' L' U' R2 F' R2 B' U' R F' U F D' L2 F2 L2 U'",
            "D2 L2 F2 L2 F L2 F R2 F' R F D L D' F B' D R2 B R", "A3d25sCQuzM2"),
        Pattern("( ! ) (ˆ⌣ˆԅ)", "ruwix1",
            "U' F2 R' L' U' B R2 D B U' R2 L B2 D' B2 U F2 B2 U' L2 B2 L2",
            "D B2 R L D F' L2 U' F' D R' L2 F2 U F2 D' F2 B2 D R2 F2 R2", "A2HfuU0x98gH"),
        Pattern("Minority cross", "ruwix1",
            "L2 D' B2 L2 B2 D' F2 D U' B2 L B2 F' L B' F U' F' U L2",
            "U2 B D2 U2 B' U2 F' D2 L2 U2 B' D' L' F2 B2 R D' F B'", "A7WRgdLkQKUk")
    }

    /// Patterns 17 to 32; see `all`.
    def part2(): Vector[Pattern] = Vector#{
        Pattern("Perpendicular lines", "ruwix1",
            "R2 U2 L2 R2 U2 L2 M2",
            "R2 U2 L2 R2 U2 R2", "A1j7i0ySHEAA"),
        Pattern("Flipped tips", "ruwix1",
            "U B D' F2 D B' U' R2 D F2 D' R2 D F2 D' R2",
            "L F U2 F' U2 F' L' F L2 B' U2 B U2 L2", "AAAA2M6ZoAAA"),
        Pattern("Plus minus", "ruwix1",
            "U2 R2 L2 U2 R2 L2",
            "L2 R2 U2 L2 R2 U2", "A1j7ix9_YDgA"),
        Pattern("Tablecloth", "ruwix1",
            "R L U2 F' U2 D2 R2 L2 F' D2 F2 D R2 L2 F2 B2 D B2 L2",
            "R F2 D B F' U D' B' U2 R B F D2 B' U2 D2 B' L2 B2", "AK9WrY2373f4"),
        Pattern("Deckerboard", "ruwix1",
            "U D R L' F' B U D' R2 U R2 L2 D2 F2 B2 D",
            "L2 F' B U2 F' L2 R2 F2 D2 U2 B' D U L' R F B", "A7WRgc3m3B1X"),
        Pattern("Spiral pattern", "ruwix1",
            "L' B' D U R U' R' D2 R2 D L D' L' R' F U",
            "F U F' R F D' L D B' D' B R2 L2 U2 B' L2 F R2 D2 F' L2", "A2Hg_EdOyc64"),
        Pattern("Fruit bowl", "ruwix1",
            "B2 L2 F2 R2 F2 R2 D U B2 U2 B' F' L' R' D' U'",
            "B' F R L U' D' B' F' R2 B2 L2", "A2HhlNltgIf4"),
        Pattern("Flower", "ruwix1",
            "R2 D2 R2 U2 R2 F2 U2 D2 F2 U2",
            "L2 D U B2 U2 B2 L2 R2 D' U'", "AAAAAAOjpIgA"),
        Pattern("Vertical stripes", "ruwix1",
            "F U F R L2 B D' R D2 L D' B R2 L F U F",
            "L2 D2 B L2 B U2 F L2 F2 B' U' B2 L' F2 R2 U' L' U' R' D' F", "AJnXgWRXYDgH"),
        Pattern("Gift box", "ruwix1",
            "U B2 R2 B2 L2 F2 R2 D' F2 L2 B F' L F2 D U' R2 F' L' R'",
            "R L B L2 U D' B2 R F B' U2 B2 U' F2 U2 R2 B2 R2 D2 L2 D'", "BBac1vuyAIAH"),
        Pattern("Opposite corners", "ruwix1",
            "R L U2 F2 D2 F2 R L F2 D2 B2 D2",
            "B2 L2 D U R2 B2 R2 B2 D' U' F2 R2", "A26_UOldoAAA"),
        Pattern("Cross", "ruwix1",
            "R2 L' D F2 R' D' R' L U' D R D B2 R' U D2",
            "F D2 B2 L2 R2 B2 U2 B D2 U2 B2 U F2 B2 D2 L2 R2 D", "A2HhlCJXYAAA"),
        Pattern("4 crosses", "ruwix1",
            "U2 R2 L2 F2 B2 D2 L2 R2 F2 B2",
            "F2 R2 F2 D' U R2 F2 R2 D U'", "A1j7ix9_YAAA"),
        Pattern("Union Jack", "ruwix1",
            "U F B' L2 U2 L2 F' B U2 L2 U",
            "U' B2 F2 L2 B2 F2 D2 U2 R2 D2 U'", "A7WRga3w4AAA"),
        Pattern("Cube in the cube", "ruwix1",
            "F L F U' R U F2 L2 U' L' B D' B' L2 U",
            "L' F2 R' B' U B' U B' U R F2 L' B2 D2 L2", "A2Hg_EcIYz4Y"),
        Pattern("Cube in a cube in a cube", "ruwix1",
            "U' L' U' F' R2 B' R F U B2 U B' L U' F U R F'",
            "U' D' L' F R2 B2 L F U' L2 U R2 F2 U' L2 D F2 L2 U2", "A2HhVJs0Az4Y")
    }

    /// Patterns 33 to 48; see `all`.
    def part3(): Vector[Pattern] = Vector#{
        Pattern("Anaconda", "ruwix1",
            "L U B' U' R L' B R' F B' D R D' F'",
            "F L2 R2 F B' U2 L D U' L F' B D' F' R2 D'", "A2HhlCO880Hg"),
        Pattern("Python", "ruwix1",
            "F2 R' B' U R' L F' L F' B D' R B L2",
            "B' R' U R2 U' R B R2 U F2 B2 R2 U' F2 U R2 U' F2", "A7WRga4PIXHO"),
        Pattern("Black mamba", "ruwix1",
            "R D L F' R L' D R' U D' B U' R' D'",
            "R F2 L2 U2 F2 R2 U2 R' U' F2 U2 F R2 F2 R F2 L2 F", "A2HhlM-xDXSo"),
        Pattern("Green mamba", "ruwix1",
            "R D R F R' F' B D R' U' B' U D2",
            "U' B' U2 D L2 F B2 U' L F U R2 F2 R2 U' D2 R2 F2 U F2", "A2HhlM-_GXSo"),
        Pattern("Tangled", "ruwix1",
            "F B U D F B U D F B U D F2 B2",
            "R2 B2 R2 B2 D U B2 R2 F2 R2 D U", "A26_UMYOF3gA"),
        Pattern("Twister", "ruwix1",
            "F R' U L F' L' F U' R U L' U' L F'",
            "F' L2 B L' F2 L D' B2 D B R2 L2 F2 R2 F", "A2Hg_D4vj_QI"),
        Pattern("Kilt (Scottish skirt)", "ruwix1",
            "U' R2 L2 F2 B2 U' R L F B' U F2 D2 R2 L2 F2 U2 F2 U' F2",
            "B U2 D2 R2 L2 B U' D' R L' B R2 B2 L2 U2 D2 B2 L2 B' L2", "A2HhlLmQ2aVX"),
        Pattern("Tetris", "ruwix1",
            "L R F B U' D' L' R'",
            "U2 L2 U2 R2 F B L2 D2 R2 D' U L R F B", "A27EGgaOVt1X"),
        Pattern("Don't cross line", "ruwix1",
            "F2 L2 R2 B2 E2",
            "B2 L2 R2 F2 D2 U2", "A1j7i5du0wAA"),
        Pattern("Hi", "ruwix1",
            "M2 U2 M2 U2",
            "L2 R2 D2 L2 R2 U2", "AAAAAAAAADgA"),
        Pattern("Hi all around", "ruwix1",
            "U2 R2 F2 U2 D2 F2 L2 U2",
            "U2 L2 F2 D2 U2 F2 R2 U2", "AAAAAC0SvPgA"),
        Pattern("Displaced Motif", "ruwix1",
            "L2 B2 D' B2 D L2 U R2 D R2 B U R' F2 R U' B' U'",
            "U' L' U' F R2 F' U L F2 D F2 U B2 D L2 D' L2 B2", "A6Afmq9fBkw8"),
        Pattern("Are you high?", "ruwix1",
            "L R' U2 D2 L' R U2 D2 R2 L2",
            "L2 B2 F2 R2 D' U' L2 R2 D' U'", "AAAAAAqeNcAA"),
        Pattern("C U around", "ruwix1",
            "U' B2 U L2 D L2 R2 D' B' R D' L R' B2 U2 F' L' U'",
            "R' U2 R U2 F L R D' R' F' R U B' R'", "A2HhlNiE8P64"),
        Pattern("Order in chaos", "ruwix1",
            "B L2 B' U2 B F2 U L U B U' R U' B F U' R D R B' U'",
            "U' B2 D' L D2 R F' U2 B' U' D2 F2 B2 L2 U' R2 F2 D2 F2 B2", "A2Hg-6LEs5FV"),
        Pattern("Evenly distributed", "ruwix1",
            "D' B2 D' L2 R2 D B2 L2 D' B2 L R' F' L2 D U' F2 R' D' U'",
            "B F L D2 B F' R2 D R' L U2 F R2 U2 F' R2 L2 F U2 F", "AAAEyZbn45qo")
    }

    /// Patterns 49 to 64; see `all`.
    def part4(): Vector[Pattern] = Vector#{
        Pattern("The hole", "ruwix1",
            "R L' F' B D U'",
            "L' R B F' U' D", "AK9WrY8BIYqv"),
        Pattern("No entry", "ruwix1",
            "U' L' B R L' D' L B' U F2 R2 B2 D2 B2 R2 B2 D B2",
            "D2 F' B R2 F' B D' B R' U L R' F' R U' B", "A7WRgiIrYK3-"),
        Pattern("\"Plus\"", "ruwix1",
            "B2 F2 R2 U2 B2 F2 R2 U2 R2 U2",
            "B2 F2 R2 U2 B2 F2 R2 U2 R2 U2", "A1j7i0dLqAgA"),
        Pattern("3C3W", "ruwix1",
            "D L B' L L F L' B' U D' R L' F B D L'",
            "L2 U' R2 U L2 D' F2 U2 B2 L B2 F D B U' B2 R' B", "AAEjmAWj1cRV"),
        Pattern("Pong", "ruwix1",
            "U R2 F2 B2 L2 U2 D R2 F2 B2 L2",
            "L2 B2 F2 R2 D' L2 B2 F2 R2 D2 U'", "A1j7ix-Tx8gA"),
        Pattern("Spun T's", "ruwix1",
            "U' L2 F2 L2 F2 D' L2 F' L2 F' D U2 L' B L B' U'",
            "R' F2 D2 F2 D2 L' F2 D' F2 D' L R2 F' U F U' R'", "A2HhlM-SL_QI"),
        Pattern("Wifi Downstairs", "ruwix1",
            "R U' R F2 R' U R F2 U' B2 U D R2 U' L2 D' L2",
            "B2 D B2 D' R2 D' B2 D R2 U' F2 R2 U R2 F2 U'", "A0pVzmWpNJAA"),
        Pattern("Opposite pillars", "ruwix2",
            "R2 F2 L2 R2 F2 L2",
            "L2 F2 L2 R2 F2 R2", "A1j7i5P9uAAA"),
        Pattern("Viaduct", "ruwix2",
            "R2 U2 L2 D B2 L2 B2 R2 D' U L' D F' U' R2 F' U B2 U2 R'",
            "F2 R U2 L' B' R2 U D' F2 R B U2 F' L2", "AK9WrXvHWAgH"),
        Pattern("Solved in scrambled", "ruwix2",
            "U2 L' U2 L' U2 F2 D L F' L F R2 D' B2 D' L2 D' L2 F2 R2",
            "L' F2 B2 U' D2 B U' B' R U2 R2 F2 R2 B2 L2 D R2 B2 D2 F2 D", "AAABjtHDG7iC"),
        Pattern("Hi Ohio", "ruwix2",
            "U2 F2 L2 R2 F2 U2",
            "U2 F2 L2 R2 F2 U2", "A1j7i5P9uIAA"),
        Pattern("Staircase", "ruwix2",
            "L2 F2 D' L2 B2 D' U' R2 B2 U' L' B2 L D L B' D L' U",
            "L' F' U2 F2 U' L F' D R' L2 B2 D' R2 D B2 R2 L2 D'", "AAAA2NGUHCtI"),
        Pattern("Wrapped 2x2", "ruwix2",
            "D' B2 F2 L2 U' F2 R2 D F2 U2 L' B R' U' L' F D' F L D2",
            "B R2 F2 L2 B' U2 B L F' L2 U' F' L' R2 D L D' B", "ADctD1Y0h59C"),
        Pattern("Antipodal chaos", "ruwix2",
            "U2 L2 U2 L2 U2 F2 R2 F2 U2 F2",
            "U2 L2 U2 L2 U2 F2 R2 F2 U2 F2", "A2Ha7-OY4vgA"),
        Pattern("Flower field", "ruwix2",
            "M S M' S' R2 L2 U2 D2 F2 B2",
            "R' L' D U' F' B R L' D2 F2 R2 L2 F2", "A2HhlPT_6jf4"),
        Pattern("C spirals", "ruwix2",
            "B' F' L2 D2 B' F U2 R2 F2",
            "D' U' B2 L2 D' U R2 F2 U2", "A2Ha78IIXPgA")
    }

    /// Patterns 65 to 80; see `all`.
    def part5(): Vector[Pattern] = Vector#{
        Pattern("Worms", "ruwix2",
            "U' F2 L2 U D2 F2 B2 U F2 L2 D",
            "U' B2 R2 D2 U' L2 R2 U' B2 R2 D", "AAAAAABj2FgA"),
        Pattern("Glider", "ruwix2",
            "D2 R2 F2 R2 U2 B2 D2 F2 L2 U2 R2 U2",
            "D2 R2 F2 R2 U2 B2 D2 F2 L2 U2 R2 U2", "A00h8NL2rdAA"),
        Pattern("Quote", "ruwix2",
            "U2 F2 D2 B2 R2 U2 B2 R2 U2 R2",
            "B2 U2 B2 L2 D2 F2 R2 U2 R2 U2", "A1j7i0e4CkgA"),
        Pattern("Matching pictures", "ruwix2",
            "R' D2 R L D2 L'",
            "L' F2 R L F2 R'", "A5_xzpeIzIgs"),
        Pattern("Loose strap", "ruwix2",
            "F2 U2 B2 U2 F2 U2",
            "F2 U2 B2 U2 F2 U2", "A1j7i0yRfsgA"),
        Pattern("Doubler", "ruwix2",
            "R L U2 R L' D2 R2 F2 U2 F2 U2 L2 F2 U2 L2",
            "L2 F2 R2 F2 D U B2 R2 F2 R2 D U", "AC7dOGj7wDgA"),
        Pattern("3T", "ruwix2",
            "B U2 L2 F2 R2 F D2 F2 R2 F' R2 U2",
            "B2 L2 D L2 B2 D2 F2 U F2 R2 D2 L2 D'", "A0RhCWKUmzgA"),
        Pattern("4 T", "ruwix2",
            "F2 D2 F' L2 D2 U2 R2 B' U2 F2",
            "B2 L2 R2 F2 D' L2 B2 F2 R2 U'", "A0zOGOUIGAAA"),
        Pattern("6 T", "ruwix2",
            "F2 R2 U2 F' B D2 L2 F B",
            "D2 B2 L2 D U' R2 F2 D' U'", "A2Ha7-b_cTgA"),
        Pattern("ZZ-Line", "ruwix2",
            "R L U2 R L' U2 F2 R2 U2 F2 D2 B2 L2 U2 L2",
            "F2 L2 B2 R2 D' U' L2 B2 R2 F2 D U", "AC7dOLzPIDgA"),
        Pattern("Checker zigzag", "ruwix2",
            "R2 L2 F2 B2 U F2 B2 U2 F2 B2 U",
            "B2 F2 L2 R2 U' B2 F2 U2 B2 F2 U'", "AAAAADEIzegA"),
        Pattern("Exchanged duck feet", "ruwix2",
            "U F R2 F' D' R U B2 U2 F' R2 F D B2 R B'",
            "R' L2 F D' F2 D F' R' R2 U' B2 R2 U' B2 U2 L2 D F2 D2", "A6IZpkduNDoI"),
        Pattern("Stripe dot solved", "ruwix2",
            "D U B2 F2 D' U'",
            "D U B2 F2 D' U'", "A1j7i5P9uDgA"),
        Pattern("Picnic", "ruwix2",
            "D2 R2 L2 F2 B2",
            "D2 B2 F2 L2 R2", "A0zOGO3WUIgA"),
        Pattern("Percent sign %", "ruwix2",
            "R L U2 R L' U2 F2 L2 U2 F2 U2 F2 R2 U2 R2",
            "F2 L2 B2 L2 D U L2 F2 R2 F2 D U", "AC7dOGyeLXgA"),
        Pattern("Mirror", "ruwix2",
            "U D F2 B2 U' D' R2 L2 B2",
            "L2 R2 B2 D U B2 F2 D' U'", "A1l1f4L7lfgA")
    }

    /// Patterns 81 to 96; see `all`.
    def part6(): Vector[Pattern] = Vector#{
        Pattern("Plus minus check", "ruwix2",
            "U D R2 L2 U D R2 L2",
            "L2 R2 D' U' L2 R2 D' U'", "A1j7iyMhzUAA"),
        Pattern("Hi again", "ruwix2",
            "U2 D2 L2 U2 D2 R2 F2 B2 L2 F2 B2 R2 U2 D2 F2 U2 D2 B2",
            "B2 F2 D' U' B2 L2 R2 F2 D' U'", "AAAAAActG0AA"),
        Pattern("4 plus 2 dots", "ruwix2",
            "F U2 D2 R L U' D F B R U2 R2 U2 F2 L2 U2 F2 L2 B2",
            "B F R' L' D' R2 L2 B2 F2 D B2 R2 D2 R2 B F U2", "A7WRghtBSyVX"),
        Pattern("Rockets", "ruwix2",
            "U R2 F2 R2 U' D F2 R2 F2 D",
            "B2 F2 L2 R2 U2 B2 F2 L2 R2", "A0zOGHCeJ8gA"),
        Pattern("Slash", "ruwix2",
            "R L F B R L F B R L F B",
            "D' L2 B2 D2 F2 R2 D2 L2 D' U R2 U'", "AC7dOJKEaIAA"),
        Pattern("The pillars", "ruwix2",
            "L2 R2 B2 F2",
            "B2 F2 L2 R2", "A1j7i5du0zgA"),
        Pattern("Twisted duck feet", "ruwix2",
            "F R' B R U F' L' F' U2 L' U' D2 B D' F B' U2",
            "B' U2 L U B' R' F' D' F' D' R' D2 B L2 B' R2 F U2 B2 F", "A2Hg-5JaU0Hg"),
        Pattern("Ron's cube in a cube", "ruwix2",
            "F D' F' R D F' R' D R D L' F L D R' F D'",
            "B2 L2 U2 L2 U' L2 B2 D2 F2 U F2 R2 U2 R2 U'", "A02FBz1nSbAA"),
        Pattern("Crossing snake", "ruwix2",
            "R L U2 R L' U2 F2 R2 D2 B2 D2 B2 L2 D2 R2",
            "F2 L2 F2 L2 D' U' L2 B2 R2 F2 D' U'", "AC7dOJKEaLgA"),
        Pattern("Cage", "ruwix2",
            "L U F2 R L' U2 B' U D B2 L F B' R' L F' R",
            "B2 D U L2 F2 D B2 U F2 D2 R2 B L B2 U2 F' D' R U2 B", "AJpYII7GuMLQ"),
        Pattern("4 crosses (second list)", "ruwix2",
            "F2 B2 R F2 B2 R F2 B2 R F2 B2 R F2 B2 R F2 B2 R",
            "L' F2 B2 U2 D2 R' U2 D2 F2 B2", "AK-bRtpiQAAA"),
        Pattern("Pyraminx", "ruwix2",
            "D L' U R' B' R B U2 D B D' B' L U D'",
            "B2 D L F2 R2 U L B' L U' R U2 R U2 L' D2 R L B2 U2", "AAAAAACjmflC"),
        Pattern("Edge triangle", "ruwix2",
            "U B2 U' F' U' D L' D2 L U D' F D' L2 B2 D'",
            "B' D' L D2 L' D B' L2 D' F2 L2 D' L2 F2 D' B2 R2 U' R2", "AAAAAAAZsxS1"),
        Pattern("Twisted rings", "ruwix2",
            "F D F' D2 L' B' U L D R U L' F' U L U2",
            "D' L U' R' U2 R' L' U' L' F' U' R2 B2 U' R2 D R2 L2 U2 B2", "A2HhlNhrAz4Y"),
        Pattern("Exchanged rings", "ruwix2",
            "B' U' B' L' D B U D2 B U L D' L' U' L2 D",
            "F2 D R2 B2 L2 B2 U L2 U' F2 U R2 B L' D L2 D' L B", "A7WRga4Pleni"),
        Pattern("Twisted chicken feet", "ruwix2",
            "F L' D F' U' B U F U' F R' F2 L U' R' D2",
            "B' L' B R2 B' R' D U' F B L F2 R' D2 L U2 L' D2 L D2", "A2Hg_EgUt8_4")
    }

    /// Patterns 97 to 110; see `all`.
    def part7(): Vector[Pattern] = Vector#{
        Pattern("Exchanged chicken feet", "ruwix2",
            "F L' D' B' L F U F' D' F L2 B' R' U L2 D' F",
            "R F' D2 B2 U' L B D F' R' U F R2 L D2 R B2 L' F2", "A6IZpweFZLKo"),
        Pattern("Twin Peaks", "ruwix2",
            "U L2 B2 R2 U R2 D' U L F' U L' D B' U L B' L R' U'",
            "B U2 R2 B' D2 R2 B R2 B L2 B' U' L B' L' R F2 B' L R' F", "AAAA2Nx4-elC"),
        Pattern("Corner pyramid", "ruwix2",
            "U' D B R' F R B' L' F' B L F R' B' R F' U' D",
            "D' L U F R' B' L' B2 L D L2 U2 R2 D B2 L2 D' R2 U' R2 L2", "AAAB1GXArG3z"),
        Pattern("Exchanged peaks", "ruwix2",
            "F U2 L F L' B L U B' R' L' U R' D' F' B R2",
            "B' U' R U2 R' U B' R2 U2 F2 U' F2 U' B2 D2 F2 L2 D' F2", "A55Td-AnRDAF"),
        Pattern("Megatron", "ruwix2",
            "U L D R' F D2 R2 F2 R' F D2 B L2 U2 D' R2 U R2 B2 L2",
            "L' F2 U D L' F B' R' D F' U' F2 R2 F2 R2 F2 D B2 U2 D' R2", "A2HhVJt6ac9d"),
        Pattern("Six-two-one", "ruwix2",
            "U B2 D2 L B' L' U' L' B D2 B2",
            "L' U2 R2 F' U F L F U' R2 U2", "ABxB2qFUAOig"),
        Pattern("Yin Yang", "ruwix2",
            "R L B F R L U' D' F' B' U D",
            "B F' R L B2 U' D' B U2 D2 B F R2 L2 B'", "A1kAVI0SXF1X"),
        Pattern("Henry's snake", "ruwix2",
            "R2 F2 U' D' B2 L2 F2 L2 U D R2 F2",
            "F2 R2 D' U' L2 F2 L2 B2 D U F2 R2", "AC7dOJDJWjgA"),
        Pattern("Snake eyes", "ruwix2",
            "R2 U2 R2 U2 R2 U2",
            "R2 U2 R2 U2 R2 U2", "AAAAAAAAMNAA"),
        Pattern("Glitch", "ruwix2",
            "F' L' B' R' U' R B L F U",
            "F' L' B' R' U' R B L F U", "AAAAAA3dZLAA"),
        Pattern("Weirdo", "ruwix2",
            "R' F' U F2 U' F R' F2 D2 F2 D2 F2 D F2 R2 U2",
            "B' L' D L2 D' L B' R2 D2 L2 D2 R2 U L2 B2 U2", "A-Hk308HXIw8"),
        Pattern("Twisted corners", "ruwix2",
            "F U D R2 F2 U' B U B U R2 B' U L2 U B2 U2 F2 L2 U'",
            "U2 R2 D2 B2 D L2 D F2 D L2 U' F D B F' D' L2 F' D L2 B", "AAAFE_Mx4AAA"),
        Pattern("Quick maths 1+1", "ruwix2",
            "R L F2 U2 R' L' F2 U2 R2 F2 U R2 L2 F2 B2 D'",
            "F2 D2 L2 B2 U' B2 F2 L2 R2 D L2 B2 U2 R2", "A7WRgbGTTXgA"),
        Pattern("Scrambled 2x2s", "ruwix2",
            "U2 B' R U' L F B2 U F' U F2 L2 U D B2 L2 B2 L2",
            "F2 L2 U2 L2 U' B2 R2 D B2 U' B R' U B' U' L U R2", "A7WP0IsHIzW3")
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
