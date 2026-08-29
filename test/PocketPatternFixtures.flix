///
/// Every published 2x2x2 pattern this project knows about, as a fixture.
///
/// **Provenance.** Retrieved 2026-08-29:
///
/// - `speedsolving` -- the 2x2x2 section of
///   <https://www.speedsolving.com/wiki/index.php/List_of_pretty_patterns>
/// - `randelshofer` -- <https://www.randelshofer.ch/rubik/patterns_pocket.html>,
///   Walter Randelshofer's Pocket Cube collection, one page per pattern
///
/// 113 algorithms were collected, 23 dropped as renames and one dropped for
/// being the solved cube rather than a pattern, leaving **89 patterns**. Where a
/// pattern appears in both collections the speedsolving name is kept.
///
/// **The equivalence is different here, and the difference is not cosmetic.** A
/// 2x2x2 has no centres, so nothing pins the frame: turning the cube in the hand
/// moves pieces between slots while the colours stay with the pieces. That is
/// what a *move* does and is not what conjugation does, so two recordings of one
/// pattern are related by one-sided multiplication, not by conjugation. On this
/// puzzle a whole-cube rotation really is a pair of moves -- `x` is `R L'`, `y`
/// is `U D'`, `z` is `F B'` -- and the key is the smallest token over the 24
/// products of those. Using the 3x3x3's conjugation here would have called
/// distinct orientations distinct patterns, and would have left four patterns
/// with no coordinate at all.
///
/// Dropped as renames:
///
/// - `4 Chessboards` is `Four-face checkerboard`
/// - `4 Chessboards` is `Four-face checkerboard`
/// - `6 Orthogonal Stripes` is `Stripes on each face`
/// - `4 Parallel Stripes` is `Stripes on four faces`
/// - `4 Parallel Stripes` is `Stripes on four faces`
/// - `8 Corner Inversions, 4 Parallel Stripes` is `Stripes on four faces`
/// - `2 Cubes in a Cube (Order 2)` is `Cube in a cube`
/// - `2 Cubes in a Cube (Order 2)` is `Cube in a cube`
/// - `4 Serial Stripes (Order 2)` is `4 Serial Stripes (Order 2)`
/// - `U2-Twist With 3 Generators` is `4 Serial Stripes (Order 2)`
/// - `U-Twist With 3 Generators` is `4 Serial Stripes (Order 4)`
/// - `U-Twist With 2 Generators` is `4 Serial Stripes (Order 4)`
/// - `4 Stripes parallel, 2 Chessboards` is `4 Stripes parallel, 2 Chessboards`
/// - `4 Stripes parallel, 2 Chessboards` is `4 Stripes parallel, 2 Chessboards`
/// - `4 Colorwheels` is `4 Colorwheels`
/// - `2 Cubes in a Cube (Order 2)` is `2 Cubes in a Cube (Order 2)`
/// - `1 Brick` is `1 Brick`
/// - `2 Cubes in a Cube (Order 2)` is `2 Cubes in a Cube (Order 2)`
/// - `2 Cubes in a Cube (Order 2)` is `2 Cubes in a Cube (Order 2)`
/// - `2 Corner Triangles` is `2 Corner Triangles`
/// - `2 Corner Triangles` is `2 Corner Triangles`
/// - `2 Mambas` is `2 Mambas`
/// - `2 Mambas` is `2 Mambas`
///
/// **`optimal` is the shortest possible sequence.** Not merely a short one: the
/// 2x2x2's whole state space fits in a table, so these come from an exact
/// solver. Their lengths run from 1 to 11, and 11 is the puzzle's diameter --
/// seven of these patterns are as far from solved as a 2x2x2 can be.
///
/// The published algorithms are already face turns, so unlike the 3x3x3 there
/// is nothing to translate; what this column adds is optimality.
///
/// Generated. Regenerate rather than editing by hand.
///
mod PocketPatternFixtures {

    use PocketPatternFixtures.Pattern.Pattern

    ///
    /// A pattern: its name, where it came from, the published algorithm, the
    /// shortest sequence that makes it, and its identity as a state.
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
    /// The shortest sequence that makes it.
    ///
    pub def optimal(p: Pattern): String = let Pattern(_, _, _, h, _) = p; h

    ///
    /// The pattern's identity: the smallest token over all 24 orientations.
    ///
    pub def canonical(p: Pattern): String = let Pattern(_, _, _, _, c) = p; c

    ///
    /// The URL a source id refers to.
    ///
    pub def url(id: String): String = match id {
        case "speedsolving" => "https://www.speedsolving.com/wiki/index.php/List_of_pretty_patterns"
        case "randelshofer" => "https://www.randelshofer.ch/rubik/patterns_pocket.html"
        case _ => "unknown"
    }

    ///
    /// Every pattern.
    ///
    ///
    /// Patterns 1 to 16; see `all`.
    def part1(): Vector[Pattern] = Vector#{
        Pattern("Four-face checkerboard", "speedsolving",
            "R2 F2 R2 U2",
            "R2 F2 R2 U2", "AF3Sc"),
        Pattern("Stripes on each face", "speedsolving",
            "F2 R2 U2 F2",
            "U2 F2 R2 U2", "AAAVd"),
        Pattern("Stripes on four faces", "speedsolving",
            "F2 R2 F2",
            "R2 F2 R2", "A0rM1"),
        Pattern("Cube in a cube", "speedsolving",
            "F2 R2 U' F' U R' U2 R U' F'",
            "R2 F2 U' R' F U' R2 U F' R'", "AGkiu"),
        Pattern("3 Parallel Stripes", "randelshofer",
            "R2 U F2 U2 R2 U R2",
            "R2 U' R2 U2 F2 U' R2", "A7rtN"),
        Pattern("4 Serial Stripes (Order 2)", "randelshofer",
            "D2",
            "U2", "AAIiw"),
        Pattern("4 Serial Stripes (Order 4)", "randelshofer",
            "D",
            "U", "AAEzj"),
        Pattern("4 Serial Stripes (Order 4) (2)", "randelshofer",
            "U'",
            "U'", "AAJnG"),
        Pattern("5 Stripes", "randelshofer",
            "R2 F' R2 F2 U2 F' R2",
            "R2 F' R2 F2 U2 F' R2", "AE3of"),
        Pattern("5 Stripes (2)", "randelshofer",
            "F2 R' U2 R2 F2 R' F2 U'",
            "F2 R' U2 R2 F2 R' F2 U'", "A035d"),
        Pattern("6 Stripes", "randelshofer",
            "B2 L2",
            "F2 R2", "A02ac"),
        Pattern("6 Stripes (2)", "randelshofer",
            "L2 D B2 D2 L2 D",
            "R2 U' R2 U2 F2 U'", "A7260"),
        Pattern("6 Orthogonal Stripes", "randelshofer",
            "D2 L2 B2 D2",
            "U2 R2 F2 U2", "AAAdy"),
        Pattern("6 Stripes (Antipode)", "randelshofer",
            "R2 U R F R' U R2 U' F U' F' U'",
            "U' R2 U' R2 U2 F2 U' F2 U'", "A04nh"),
        Pattern("6 Stripes (Antipode) (2)", "randelshofer",
            "L2 D' L' B' L D' L2 D B' D B D",
            "U F2 U' R2 U2 F2 U' R2 U", "ADTXr"),
        Pattern("4 Stripes parallel, 2 Chessboards", "randelshofer",
            "U R2 U2 F2 U",
            "U' F2 U2 R2 U'", "A-x3X")
    }

    /// Patterns 17 to 32; see `all`.
    def part2(): Vector[Pattern] = Vector#{
        Pattern("4 Stripes parallel, 2 Chessboards (2)", "randelshofer",
            "U F2 U2 R2 U",
            "U' R2 U2 F2 U'", "A8mcH"),
        Pattern("4 Orthogonal Stripes, 2 Chessboards", "randelshofer",
            "L2 D2 B2",
            "R2 U2 F2", "AF9CA"),
        Pattern("4 Orthogonal Stripes, 2 Chessboards (2)", "randelshofer",
            "B2 D2 L2",
            "F2 U2 R2", "ARm8H"),
        Pattern("5 Stripes, 1 Chessboard", "randelshofer",
            "R' F2 R F' R2 F' R2 F' R'",
            "R' F2 R F' R2 F' R2 F' R'", "A2nEt"),
        Pattern("5 Stripes, 1 Chessboard (2)", "randelshofer",
            "R F R2 F R2 F R' F2 R",
            "R F R2 F R2 F R' F2 R", "A7NRa"),
        Pattern("4 Orthogonal L's, 2 Chessboards", "randelshofer",
            "L U B' L' B L2 F U R F",
            "U' R2 U2 F2 U' F2 U2 R2 U'", "APjl1"),
        Pattern("4 Orthogonal L's, 2 Chessboards (2)", "randelshofer",
            "L D F' L' F L2 B D R B",
            "U F2 U2 R2 U' F2 U2 R2 U'", "ADwEo"),
        Pattern("4 Colorwheels", "randelshofer",
            "U F2 L2 F2",
            "R2 F2 R2 U'", "A13ja"),
        Pattern("2 Cubes in a Cube (Order 2)", "randelshofer",
            "R F' R U R' D2 L' U' B' U B2",
            "F' U R' F2 U' R F U R2 U R'", "ADqVE"),
        Pattern("1 Brick", "randelshofer",
            "B L B L B L B L B L B L B L B",
            "F R' F2 U' F R U R2 U R' U'", "A8e9t"),
        Pattern("4 Bricks", "randelshofer",
            "D2 L2 D2 L2 D",
            "R2 U'", "A5bae"),
        Pattern("4 Bricks (2)", "randelshofer",
            "D2 B2 D2 B2 D",
            "F2 U'", "AF1OJ"),
        Pattern("Corner Twist (+urf) (-ubr)", "randelshofer",
            "U' R U' R U' R U R' U R' U R'",
            "R' U R' F U' R U F2 R2 U'", "AAAMP"),
        Pattern("Corner Twist (-urf) (+ubr)", "randelshofer",
            "R U' R U' R U' R' U R' U R' U",
            "F U' R F' U F R2 U2 F' U'", "AAAXN"),
        Pattern("Corner Twist (-ufl) (+ulb)", "randelshofer",
            "U R U' R U' R U R' U R' U R' U2",
            "R' F R' F U' F U F2 R2 U'", "AAAI3"),
        Pattern("Corner Twist (+ufl) (-ulb)", "randelshofer",
            "U2 R U' R U' R U' R' U R' U R' U'",
            "F R' U F' U F U2 R2 F' U'", "AAAGV")
    }

    /// Patterns 33 to 48; see `all`.
    def part3(): Vector[Pattern] = Vector#{
        Pattern("Corner Twist (+urf) (+ubr) (+ulb)", "randelshofer",
            "R U R2 U' R2 U R U'",
            "R U R2 U' R2 U R U'", "AAANF"),
        Pattern("Corner Twist (-urf) (-ubr) (-ulb)", "randelshofer",
            "U R' U' R2 U R2 U' R'",
            "R F2 R' F' U F' R' U2", "AAAaK"),
        Pattern("Corner Twist (+urf) (-ubr) (-ufl) (+ulb)", "randelshofer",
            "R2 U2 R' U2 R2 U'",
            "R2 U2 R' U2 R2 U'", "AAAVG"),
        Pattern("Corner Twist (-urf) (+ubr) (+ufl) (-ulb)", "randelshofer",
            "U R2 U2 R U2 R2",
            "F2 U2 F' U2 F2 U'", "AAAdi"),
        Pattern("Corner Twist (+urf) (-ubr) (+ufl) (-ulb)", "randelshofer",
            "R' U R2 U' R2 U' R2 U R' U2",
            "R U2 R2 U' R2 U R2 U2 R' U2", "AAASk"),
        Pattern("Corner Twist (-urf) (+ubr) (-ufl) (+ulb)", "randelshofer",
            "U2 R U' R2 U R2 U R2 U' R",
            "R F2 R2 F' U2 F R2 F2 R' U2", "AAAgE"),
        Pattern("Corner Twist (+urf) (+ubr) (-ufl) (-ulb)", "randelshofer",
            "R' U' R U' R U2 R U' R U' R'",
            "F R2 F2 R' U2 R F2 R2 F' U2", "AAAV8"),
        Pattern("Corner Twist (-urf) (-ubr) (+ufl) (+ulb)", "randelshofer",
            "R U R' U R' U2 R' U R' U R",
            "F U2 F2 U' F2 U F2 U2 F' U2", "AAAcs"),
        Pattern("Corner Twist (+urf) (+ubr) (+ufl) (+ulb) (+dfr) (+drb)", "randelshofer",
            "R' U' R' U' R' U' R' U' R' U'",
            "R2 U' R' U' R2 U' R' U'", "AAARB"),
        Pattern("Corner Twist (-urf) (-ubr) (-ufl) (-ulb) (-dfr) (-drb)", "randelshofer",
            "U R U R U R U R U R",
            "R U R U2 R U R U2", "AAAiC"),
        Pattern("Corner Swap (ufl,dfr) (ulb,drb)", "randelshofer",
            "U2 R2 U2",
            "U2 R2 U2", "A0qvD"),
        Pattern("Antipode in FTM and QTM", "randelshofer",
            "D R D2 F' D F D R' F' R D R' F",
            "F2 U R' F R U2 F' U R U2 R'", "A1edV"),
        Pattern("Antipode in FTM and QTM (2)", "randelshofer",
            "B2 U B2 U' B L' B D' B D B2",
            "F R2 U' F' U2 F U R2 U F U'", "A0zkg"),
        Pattern("Antipode in FTM and QTM (3)", "randelshofer",
            "B2 R F' D R2 B' R D B' L B2",
            "U F U' R2 F2 U' R' U F2 R' U'", "A2K8b"),
        Pattern("Antipode in FTM and QTM (4)", "randelshofer",
            "L2 U B2 L' U' L B' L B' U2 B",
            "F' U' R2 F R U2 R F U2 R' U'", "A-YQa"),
        Pattern("2 Cubes in a Cube (Order 2) (2)", "randelshofer",
            "U R F' U2 F R' U F R2 U2",
            "U2 R2 F' U' R F' U2 F R' U'", "AGkXT")
    }

    /// Patterns 49 to 64; see `all`.
    def part4(): Vector[Pattern] = Vector#{
        Pattern("2 Cubes in a Cube (Order 2) (3)", "randelshofer",
            "U L U' F2 U F' U R F2 D2",
            "U2 F2 R' U' R F' R2 F R' U'", "AGkuG"),
        Pattern("2 Cubes in a Cube (Order 3)", "randelshofer",
            "U F' R U F2 R2 U' F' R F'",
            "R U2 R' F2 R U' R2 U F2 U'", "AAAWz"),
        Pattern("2 Cubes in a Cube (Order 3) (2)", "randelshofer",
            "F R' F U R2 F2 D' B' U R'",
            "F R2 F' U2 F U' R2 U F2 U'", "AAALb"),
        Pattern("2 Corner Triangles", "randelshofer",
            "F R U R' F U2 F' R U' R' F",
            "R F2 R' U2 R2 F2 R' F2 R' U2", "ADTPW"),
        Pattern("2 Corner Triangles (2)", "randelshofer",
            "F' R U R' F U2 F' R U' R' F'",
            "F2 U R2 U' F2 U2 R2 U' R2 U'", "A05FT"),
        Pattern("2 Corner Triangles (3)", "randelshofer",
            "B' L' D' L B' D2 B L' D L B'",
            "R2 U F2 U' R2 U2 F2 U' R2 U'", "A048-"),
        Pattern("2 Corner Triangles (4)", "randelshofer",
            "B L' D' L B' D2 B L' D L B",
            "F U2 F' U2 F2 R2 F' R2 F' U2", "ADS55"),
        Pattern("2 Corner Triangles (5)", "randelshofer",
            "U R' F2 R F U' R2 U F' U'",
            "F' U F' R' U2 R' U' F2 R' U'", "ADS7N"),
        Pattern("2 Corner Triangles (6)", "randelshofer",
            "U R F2 U R F2 R U F' R",
            "F2 R' U' F2 R F U F' R U'", "A0453"),
        Pattern("Two-One-One", "randelshofer",
            "U F R' F R U R' U2 F2",
            "R U F' U F R F' R2 U2", "AH7Im"),
        Pattern("Two-One-One (2)", "randelshofer",
            "D L B' L B D B' D2 L2",
            "F R F' U R F R' F2 U2", "AH6vL"),
        Pattern("3 Orthogonal Bricks (Order 2)", "randelshofer",
            "U' R2 F2 R' F2 U2 R2 U",
            "U' R2 F2 R U2 R2 F2 U'", "AG717"),
        Pattern("3 Orthogonal Bricks (Order 2) (2)", "randelshofer",
            "U F2 R2 F R2 U2 F2 U'",
            "U F2 R2 F R2 U2 F2 U'", "AI8Uq"),
        Pattern("3 Orthogonal Bricks (Order 3)", "randelshofer",
            "U' F2 U F' R2 F",
            "U' F2 U F' R2 F", "A1JMB"),
        Pattern("3 Orthogonal Bricks (Order 3) (2)", "randelshofer",
            "B L2 B' D B2 D'",
            "F U2 F' U R2 U'", "A3IZJ"),
        Pattern("3 Orthogonal Bricks (Order 6)", "randelshofer",
            "F R' F U R2 U F2 U' R",
            "R2 F' U' R F' R' U F2 U'", "AG8Mu")
    }

    /// Patterns 65 to 80; see `all`.
    def part5(): Vector[Pattern] = Vector#{
        Pattern("3 Orthogonal Bricks (Order 6) (2)", "randelshofer",
            "R' F R' U' F2 U' R2 U F'",
            "F' U F' R' U2 R' F2 R U'", "AI793"),
        Pattern("6 Carneval Masks", "randelshofer",
            "U2 F2 R F' R' U' F R' F'",
            "R2 U2 F U' F' R' U F' U'", "AH7F-"),
        Pattern("6 Carneval Masks (2)", "randelshofer",
            "U2 R2 F R' F' U' F U' R'",
            "F2 U2 R U' R' F' R F' U'", "AH6xz"),
        Pattern("2 Corner Triangles (7)", "randelshofer",
            "F' U F' R' U R U' F' R F'",
            "U' R2 F2 R' U2 F' R2 F2 U'", "ADTSA"),
        Pattern("2 Corner Triangles (8)", "randelshofer",
            "F R' F U R' U' R F U' F",
            "U2 R2 U F' U2 R' U R2 U2", "A043M"),
        Pattern("2 Color Framed Cubes (Order 2)", "randelshofer",
            "U F U R F U F",
            "U R' F2 U' F2 R' U'", "AH7Cz"),
        Pattern("2 Color Framed Cubes (Order 6)", "randelshofer",
            "U F' R U F' R U' R2 U F'",
            "R U' F R U' F R' F2 R U'", "AH63Y"),
        Pattern("2 Color Framed Cubes (Order 6) (2)", "randelshofer",
            "F U' R2 U R' F U' R' F U'",
            "F R' F U R' U R' F2 R U'", "AH7OL"),
        Pattern("2 Color Framed Cubes (Order 2) (2)", "randelshofer",
            "U F R U F U R",
            "U R' U2 F' U2 R' U'", "ADAsy"),
        Pattern("Corner Triangle (Antipode), Two-One-One", "randelshofer",
            "B' D B' D' L B' D L' D' B2 D' B2",
            "R' U R2 F2 R' U' F2 U2 R U'", "ADTTU"),
        Pattern("Corner Triangle (Back, Antipode), Two-One-One", "randelshofer",
            "R' U R' U' F R' U F' U' R2 U' R2",
            "F' R F2 U2 F' U' F2 U2 R U'", "ADTWX"),
        Pattern("Corner Triangle (Antipode), Two-One-One (2)", "randelshofer",
            "B2 D B2 D L D' B L' D B D' B",
            "F' R2 F2 U F' U' F U2 R2 U'", "A04y9"),
        Pattern("Corner Triangle (Back, Antipode), Two-One-One (2)", "randelshofer",
            "R2 U R2 U F U' R F' U R U' R",
            "R' U2 R2 F R' U' F U2 R2 U'", "A04rw"),
        Pattern("2 Mambas", "randelshofer",
            "U' F2 U",
            "U' F2 U", "A2Asu"),
        Pattern("2 Mambas (2)", "randelshofer",
            "D B2 D'",
            "U R2 U'", "AC1AR"),
        Pattern("3 Corner Twists", "randelshofer",
            "F' U2 F' U F' U' F U' F2 U'",
            "F' U2 F' U F' U' F U' F2 U'", "AAAEX")
    }

    /// Patterns 81 to 89; see `all`.
    def part6(): Vector[Pattern] = Vector#{
        Pattern("3 Corner Twists (2)", "randelshofer",
            "U F2 U F' U F U' F U2 F",
            "R' U2 R' U2 R U' R U R' U'", "AAAIu"),
        Pattern("4 Corner Twists", "randelshofer",
            "F U' R' U R U' R' U R F'",
            "U R U2 F' U2 F2 U' F2 R' U'", "AAAIH"),
        Pattern("4 Corner Twists (2)", "randelshofer",
            "U F2 L F2 R2 B R2 U'",
            "U F2 R' U2 R2 U' F2 R'", "AAAIm"),
        Pattern("6 Corner Twists, 2 Color Framed Cubes", "randelshofer",
            "U F' U R' U R' U R' F U'",
            "F' R F2 U2 F' U' F U2 R2 U'", "AAAKC"),
        Pattern("6 Corner Twists, 2 Color Framed Cubes (2)", "randelshofer",
            "F R' F R' U' F R F' U' F",
            "F R' F U2 F R' U R' F2 U'", "AAALW"),
        Pattern("6 Corner Twists, 2 Color Framed Cubes (3)", "randelshofer",
            "F' U F R' F' U R F' R F'",
            "U2 R F' R' U R U' R F2 U'", "AAAFr"),
        Pattern("Corner Swap (urf,ubr)", "randelshofer",
            "B U' B L2 F' D F L2 B2 U",
            "R2 F2 R' U' R F2 R' U R' U'", "A4h4P"),
        Pattern("Corner Swap (ufl,ubr)", "randelshofer",
            "R' U R U B2 U R' U' R U' B2",
            "F U' R U F' R2 F' U' R' U R2", "A04A9"),
        Pattern("Self-Solving Algorithms (A B)", "randelshofer",
            "D2 F2 D2 R'",
            "R U2 F2 U2", "A0w8S")
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
            part6()
        })

}
