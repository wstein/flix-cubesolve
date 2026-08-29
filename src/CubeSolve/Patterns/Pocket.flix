///
/// Every published 2x2x2 pattern this project knows about.
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
mod CubeSolve.Patterns.Pocket {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Holding
    use CubeSolve.Model.Move
    use CubeSolve.Model.Rotation
    use CubeSolve.Patterns.Pocket.Pattern.Pattern

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
    pub def source(p: Pattern): String = let Pattern(_, _, s, _, _) = p; s

    ///
    /// The algorithm as published.
    ///
    pub def notation(p: Pattern): String = let Pattern(_, _, _, a, _) = p; a

    ///
    /// The shortest sequence that makes it.
    ///
    pub def optimal(p: Pattern): String = let Pattern(_, _, _, _, h) = p; h

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
    /// The proven-shortest solution for the pattern as recorded.
    ///
    /// `optimal` is exact -- the 2x2x2's whole state space fits in a table -- so
    /// running it backwards is exact too. This is the field the 3x3x3 corpus
    /// cannot offer; there the equivalent is called `knownSolution` and is only
    /// that.
    ///
    pub def optimalSolution(p: Pattern): Result[String, List[Move.Move]] =
        Move.parse(optimal(p)) |> Result.map(Move.inverseOf)

    ///
    /// `optimalSolution` for a cube held as `witness` describes.
    ///
    /// Turning the cube back upright and then solving it, literally: the
    /// re-holding is undone first and the recorded solution follows. Those
    /// leading moves are a whole-cube turn, so they cost nothing in pieces moved
    /// but they are real moves and are counted -- **the result is no longer
    /// proven optimal unless the witness is the identity.** A caller who wants
    /// the shortest answer for a cube in an awkward orientation should solve it.
    ///
    pub def solutionFor(
        p: Pattern,
        witness: Rotation.Rotation
    ): Result[String, List[Move.Move]] =
        match wordFor(witness) {
            case None       => Err("that rotation is not one of the 24 re-holdings")
            case Some(back) =>
                forM (
                    undo <- Move.parse(back) |> Result.map(Move.inverseOf);
                    rest <- optimalSolution(p)
                ) yield List.append(undo, rest)
        }


    ///
    /// The moves that reach the re-holding `r` names.
    ///
    pub def wordFor(r: Rotation.Rotation): Option[String] = Holding.wordFor(r)

    ///
    /// This cube's pattern identity: the smallest token over the 24 re-holdings.
    ///
    /// `CubeSolve.Model.Holding` owns the relation, because it is a fact about
    /// cubes rather than about this collection. This is the name the corpus
    /// knows it by.
    ///
    pub def identify(c: Cube.Cube): Option[String] = Holding.identityOf(c)

    ///
    /// The published pattern `c` is, and how it is being held.
    ///
    /// As on the 3x3x3, no solver consults this.
    ///
    pub def recognize(c: Cube.Cube): Option[(Pattern, Rotation.Rotation)] =
        forM (
            id <- identify(c);
            found <- all() |> Vector.findLeft(p -> canonical(p) == id);
            held <- heldAs(found, c)
        ) yield (found, held)

    ///
    /// Which re-holding carries the recorded pattern onto `c`.
    ///
    def heldAs(p: Pattern, c: Cube.Cube): Option[Rotation.Rotation] =
        forM (
            upright <- Cube.solved(2)
                |> Result.flatMap(s -> Cube.applyNotation(optimal(p), s))
                |> Result.toOption;
            target <- Facelets.token(c) |> Result.toOption;
            e <- Holding.reorientations()
                |> Vector.findLeft(e -> Holding.tokenAfter(snd(e), upright) == Some(target))
        ) yield fst(e)






    ///
    /// Every pattern.
    ///
    ///
    /// Patterns 1 to 16; see `all`.
    def part1(): Vector[Pattern] = Vector#{
        Pattern("Four-face checkerboard", "AF3Sc", "speedsolving",
            "R2 F2 R2 U2",
            "R2 F2 R2 U2"),
        Pattern("Stripes on each face", "AAAVd", "speedsolving",
            "F2 R2 U2 F2",
            "U2 F2 R2 U2"),
        Pattern("Stripes on four faces", "A0rM1", "speedsolving",
            "F2 R2 F2",
            "R2 F2 R2"),
        Pattern("Cube in a cube", "AGkiu", "speedsolving",
            "F2 R2 U' F' U R' U2 R U' F'",
            "R2 F2 U' R' F U' R2 U F' R'"),
        Pattern("3 Parallel Stripes", "A7rtN", "randelshofer",
            "R2 U F2 U2 R2 U R2",
            "R2 U' R2 U2 F2 U' R2"),
        Pattern("4 Serial Stripes (Order 2)", "AAIiw", "randelshofer",
            "D2",
            "U2"),
        Pattern("4 Serial Stripes (Order 4)", "AAEzj", "randelshofer",
            "D",
            "U"),
        Pattern("4 Serial Stripes (Order 4) (2)", "AAJnG", "randelshofer",
            "U'",
            "U'"),
        Pattern("5 Stripes", "AE3of", "randelshofer",
            "R2 F' R2 F2 U2 F' R2",
            "R2 F' R2 F2 U2 F' R2"),
        Pattern("5 Stripes (2)", "A035d", "randelshofer",
            "F2 R' U2 R2 F2 R' F2 U'",
            "F2 R' U2 R2 F2 R' F2 U'"),
        Pattern("6 Stripes", "A02ac", "randelshofer",
            "B2 L2",
            "F2 R2"),
        Pattern("6 Stripes (2)", "A7260", "randelshofer",
            "L2 D B2 D2 L2 D",
            "R2 U' R2 U2 F2 U'"),
        Pattern("6 Orthogonal Stripes", "AAAdy", "randelshofer",
            "D2 L2 B2 D2",
            "U2 R2 F2 U2"),
        Pattern("6 Stripes (Antipode)", "A04nh", "randelshofer",
            "R2 U R F R' U R2 U' F U' F' U'",
            "U' R2 U' R2 U2 F2 U' F2 U'"),
        Pattern("6 Stripes (Antipode) (2)", "ADTXr", "randelshofer",
            "L2 D' L' B' L D' L2 D B' D B D",
            "U F2 U' R2 U2 F2 U' R2 U"),
        Pattern("4 Stripes parallel, 2 Chessboards", "A-x3X", "randelshofer",
            "U R2 U2 F2 U",
            "U' F2 U2 R2 U'")
    }

    /// Patterns 17 to 32; see `all`.
    def part2(): Vector[Pattern] = Vector#{
        Pattern("4 Stripes parallel, 2 Chessboards (2)", "A8mcH", "randelshofer",
            "U F2 U2 R2 U",
            "U' R2 U2 F2 U'"),
        Pattern("4 Orthogonal Stripes, 2 Chessboards", "AF9CA", "randelshofer",
            "L2 D2 B2",
            "R2 U2 F2"),
        Pattern("4 Orthogonal Stripes, 2 Chessboards (2)", "ARm8H", "randelshofer",
            "B2 D2 L2",
            "F2 U2 R2"),
        Pattern("5 Stripes, 1 Chessboard", "A2nEt", "randelshofer",
            "R' F2 R F' R2 F' R2 F' R'",
            "R' F2 R F' R2 F' R2 F' R'"),
        Pattern("5 Stripes, 1 Chessboard (2)", "A7NRa", "randelshofer",
            "R F R2 F R2 F R' F2 R",
            "R F R2 F R2 F R' F2 R"),
        Pattern("4 Orthogonal L's, 2 Chessboards", "APjl1", "randelshofer",
            "L U B' L' B L2 F U R F",
            "U' R2 U2 F2 U' F2 U2 R2 U'"),
        Pattern("4 Orthogonal L's, 2 Chessboards (2)", "ADwEo", "randelshofer",
            "L D F' L' F L2 B D R B",
            "U F2 U2 R2 U' F2 U2 R2 U'"),
        Pattern("4 Colorwheels", "A13ja", "randelshofer",
            "U F2 L2 F2",
            "R2 F2 R2 U'"),
        Pattern("2 Cubes in a Cube (Order 2)", "ADqVE", "randelshofer",
            "R F' R U R' D2 L' U' B' U B2",
            "F' U R' F2 U' R F U R2 U R'"),
        Pattern("1 Brick", "A8e9t", "randelshofer",
            "B L B L B L B L B L B L B L B",
            "F R' F2 U' F R U R2 U R' U'"),
        Pattern("4 Bricks", "A5bae", "randelshofer",
            "D2 L2 D2 L2 D",
            "R2 U'"),
        Pattern("4 Bricks (2)", "AF1OJ", "randelshofer",
            "D2 B2 D2 B2 D",
            "F2 U'"),
        Pattern("Corner Twist (+urf) (-ubr)", "AAAMP", "randelshofer",
            "U' R U' R U' R U R' U R' U R'",
            "R' U R' F U' R U F2 R2 U'"),
        Pattern("Corner Twist (-urf) (+ubr)", "AAAXN", "randelshofer",
            "R U' R U' R U' R' U R' U R' U",
            "F U' R F' U F R2 U2 F' U'"),
        Pattern("Corner Twist (-ufl) (+ulb)", "AAAI3", "randelshofer",
            "U R U' R U' R U R' U R' U R' U2",
            "R' F R' F U' F U F2 R2 U'"),
        Pattern("Corner Twist (+ufl) (-ulb)", "AAAGV", "randelshofer",
            "U2 R U' R U' R U' R' U R' U R' U'",
            "F R' U F' U F U2 R2 F' U'")
    }

    /// Patterns 33 to 48; see `all`.
    def part3(): Vector[Pattern] = Vector#{
        Pattern("Corner Twist (+urf) (+ubr) (+ulb)", "AAANF", "randelshofer",
            "R U R2 U' R2 U R U'",
            "R U R2 U' R2 U R U'"),
        Pattern("Corner Twist (-urf) (-ubr) (-ulb)", "AAAaK", "randelshofer",
            "U R' U' R2 U R2 U' R'",
            "R F2 R' F' U F' R' U2"),
        Pattern("Corner Twist (+urf) (-ubr) (-ufl) (+ulb)", "AAAVG", "randelshofer",
            "R2 U2 R' U2 R2 U'",
            "R2 U2 R' U2 R2 U'"),
        Pattern("Corner Twist (-urf) (+ubr) (+ufl) (-ulb)", "AAAdi", "randelshofer",
            "U R2 U2 R U2 R2",
            "F2 U2 F' U2 F2 U'"),
        Pattern("Corner Twist (+urf) (-ubr) (+ufl) (-ulb)", "AAASk", "randelshofer",
            "R' U R2 U' R2 U' R2 U R' U2",
            "R U2 R2 U' R2 U R2 U2 R' U2"),
        Pattern("Corner Twist (-urf) (+ubr) (-ufl) (+ulb)", "AAAgE", "randelshofer",
            "U2 R U' R2 U R2 U R2 U' R",
            "R F2 R2 F' U2 F R2 F2 R' U2"),
        Pattern("Corner Twist (+urf) (+ubr) (-ufl) (-ulb)", "AAAV8", "randelshofer",
            "R' U' R U' R U2 R U' R U' R'",
            "F R2 F2 R' U2 R F2 R2 F' U2"),
        Pattern("Corner Twist (-urf) (-ubr) (+ufl) (+ulb)", "AAAcs", "randelshofer",
            "R U R' U R' U2 R' U R' U R",
            "F U2 F2 U' F2 U F2 U2 F' U2"),
        Pattern("Corner Twist (+urf) (+ubr) (+ufl) (+ulb) (+dfr) (+drb)", "AAARB", "randelshofer",
            "R' U' R' U' R' U' R' U' R' U'",
            "R2 U' R' U' R2 U' R' U'"),
        Pattern("Corner Twist (-urf) (-ubr) (-ufl) (-ulb) (-dfr) (-drb)", "AAAiC", "randelshofer",
            "U R U R U R U R U R",
            "R U R U2 R U R U2"),
        Pattern("Corner Swap (ufl,dfr) (ulb,drb)", "A0qvD", "randelshofer",
            "U2 R2 U2",
            "U2 R2 U2"),
        Pattern("Antipode in FTM and QTM", "A1edV", "randelshofer",
            "D R D2 F' D F D R' F' R D R' F",
            "F2 U R' F R U2 F' U R U2 R'"),
        Pattern("Antipode in FTM and QTM (2)", "A0zkg", "randelshofer",
            "B2 U B2 U' B L' B D' B D B2",
            "F R2 U' F' U2 F U R2 U F U'"),
        Pattern("Antipode in FTM and QTM (3)", "A2K8b", "randelshofer",
            "B2 R F' D R2 B' R D B' L B2",
            "U F U' R2 F2 U' R' U F2 R' U'"),
        Pattern("Antipode in FTM and QTM (4)", "A-YQa", "randelshofer",
            "L2 U B2 L' U' L B' L B' U2 B",
            "F' U' R2 F R U2 R F U2 R' U'"),
        Pattern("2 Cubes in a Cube (Order 2) (2)", "AGkXT", "randelshofer",
            "U R F' U2 F R' U F R2 U2",
            "U2 R2 F' U' R F' U2 F R' U'")
    }

    /// Patterns 49 to 64; see `all`.
    def part4(): Vector[Pattern] = Vector#{
        Pattern("2 Cubes in a Cube (Order 2) (3)", "AGkuG", "randelshofer",
            "U L U' F2 U F' U R F2 D2",
            "U2 F2 R' U' R F' R2 F R' U'"),
        Pattern("2 Cubes in a Cube (Order 3)", "AAAWz", "randelshofer",
            "U F' R U F2 R2 U' F' R F'",
            "R U2 R' F2 R U' R2 U F2 U'"),
        Pattern("2 Cubes in a Cube (Order 3) (2)", "AAALb", "randelshofer",
            "F R' F U R2 F2 D' B' U R'",
            "F R2 F' U2 F U' R2 U F2 U'"),
        Pattern("2 Corner Triangles", "ADTPW", "randelshofer",
            "F R U R' F U2 F' R U' R' F",
            "R F2 R' U2 R2 F2 R' F2 R' U2"),
        Pattern("2 Corner Triangles (2)", "A05FT", "randelshofer",
            "F' R U R' F U2 F' R U' R' F'",
            "F2 U R2 U' F2 U2 R2 U' R2 U'"),
        Pattern("2 Corner Triangles (3)", "A048-", "randelshofer",
            "B' L' D' L B' D2 B L' D L B'",
            "R2 U F2 U' R2 U2 F2 U' R2 U'"),
        Pattern("2 Corner Triangles (4)", "ADS55", "randelshofer",
            "B L' D' L B' D2 B L' D L B",
            "F U2 F' U2 F2 R2 F' R2 F' U2"),
        Pattern("2 Corner Triangles (5)", "ADS7N", "randelshofer",
            "U R' F2 R F U' R2 U F' U'",
            "F' U F' R' U2 R' U' F2 R' U'"),
        Pattern("2 Corner Triangles (6)", "A0453", "randelshofer",
            "U R F2 U R F2 R U F' R",
            "F2 R' U' F2 R F U F' R U'"),
        Pattern("Two-One-One", "AH7Im", "randelshofer",
            "U F R' F R U R' U2 F2",
            "R U F' U F R F' R2 U2"),
        Pattern("Two-One-One (2)", "AH6vL", "randelshofer",
            "D L B' L B D B' D2 L2",
            "F R F' U R F R' F2 U2"),
        Pattern("3 Orthogonal Bricks (Order 2)", "AG717", "randelshofer",
            "U' R2 F2 R' F2 U2 R2 U",
            "U' R2 F2 R U2 R2 F2 U'"),
        Pattern("3 Orthogonal Bricks (Order 2) (2)", "AI8Uq", "randelshofer",
            "U F2 R2 F R2 U2 F2 U'",
            "U F2 R2 F R2 U2 F2 U'"),
        Pattern("3 Orthogonal Bricks (Order 3)", "A1JMB", "randelshofer",
            "U' F2 U F' R2 F",
            "U' F2 U F' R2 F"),
        Pattern("3 Orthogonal Bricks (Order 3) (2)", "A3IZJ", "randelshofer",
            "B L2 B' D B2 D'",
            "F U2 F' U R2 U'"),
        Pattern("3 Orthogonal Bricks (Order 6)", "AG8Mu", "randelshofer",
            "F R' F U R2 U F2 U' R",
            "R2 F' U' R F' R' U F2 U'")
    }

    /// Patterns 65 to 80; see `all`.
    def part5(): Vector[Pattern] = Vector#{
        Pattern("3 Orthogonal Bricks (Order 6) (2)", "AI793", "randelshofer",
            "R' F R' U' F2 U' R2 U F'",
            "F' U F' R' U2 R' F2 R U'"),
        Pattern("6 Carneval Masks", "AH7F-", "randelshofer",
            "U2 F2 R F' R' U' F R' F'",
            "R2 U2 F U' F' R' U F' U'"),
        Pattern("6 Carneval Masks (2)", "AH6xz", "randelshofer",
            "U2 R2 F R' F' U' F U' R'",
            "F2 U2 R U' R' F' R F' U'"),
        Pattern("2 Corner Triangles (7)", "ADTSA", "randelshofer",
            "F' U F' R' U R U' F' R F'",
            "U' R2 F2 R' U2 F' R2 F2 U'"),
        Pattern("2 Corner Triangles (8)", "A043M", "randelshofer",
            "F R' F U R' U' R F U' F",
            "U2 R2 U F' U2 R' U R2 U2"),
        Pattern("2 Color Framed Cubes (Order 2)", "AH7Cz", "randelshofer",
            "U F U R F U F",
            "U R' F2 U' F2 R' U'"),
        Pattern("2 Color Framed Cubes (Order 6)", "AH63Y", "randelshofer",
            "U F' R U F' R U' R2 U F'",
            "R U' F R U' F R' F2 R U'"),
        Pattern("2 Color Framed Cubes (Order 6) (2)", "AH7OL", "randelshofer",
            "F U' R2 U R' F U' R' F U'",
            "F R' F U R' U R' F2 R U'"),
        Pattern("2 Color Framed Cubes (Order 2) (2)", "ADAsy", "randelshofer",
            "U F R U F U R",
            "U R' U2 F' U2 R' U'"),
        Pattern("Corner Triangle (Antipode), Two-One-One", "ADTTU", "randelshofer",
            "B' D B' D' L B' D L' D' B2 D' B2",
            "R' U R2 F2 R' U' F2 U2 R U'"),
        Pattern("Corner Triangle (Back, Antipode), Two-One-One", "ADTWX", "randelshofer",
            "R' U R' U' F R' U F' U' R2 U' R2",
            "F' R F2 U2 F' U' F2 U2 R U'"),
        Pattern("Corner Triangle (Antipode), Two-One-One (2)", "A04y9", "randelshofer",
            "B2 D B2 D L D' B L' D B D' B",
            "F' R2 F2 U F' U' F U2 R2 U'"),
        Pattern("Corner Triangle (Back, Antipode), Two-One-One (2)", "A04rw", "randelshofer",
            "R2 U R2 U F U' R F' U R U' R",
            "R' U2 R2 F R' U' F U2 R2 U'"),
        Pattern("2 Mambas", "A2Asu", "randelshofer",
            "U' F2 U",
            "U' F2 U"),
        Pattern("2 Mambas (2)", "AC1AR", "randelshofer",
            "D B2 D'",
            "U R2 U'"),
        Pattern("3 Corner Twists", "AAAEX", "randelshofer",
            "F' U2 F' U F' U' F U' F2 U'",
            "F' U2 F' U F' U' F U' F2 U'")
    }

    /// Patterns 81 to 89; see `all`.
    def part6(): Vector[Pattern] = Vector#{
        Pattern("3 Corner Twists (2)", "AAAIu", "randelshofer",
            "U F2 U F' U F U' F U2 F",
            "R' U2 R' U2 R U' R U R' U'"),
        Pattern("4 Corner Twists", "AAAIH", "randelshofer",
            "F U' R' U R U' R' U R F'",
            "U R U2 F' U2 F2 U' F2 R' U'"),
        Pattern("4 Corner Twists (2)", "AAAIm", "randelshofer",
            "U F2 L F2 R2 B R2 U'",
            "U F2 R' U2 R2 U' F2 R'"),
        Pattern("6 Corner Twists, 2 Color Framed Cubes", "AAAKC", "randelshofer",
            "U F' U R' U R' U R' F U'",
            "F' R F2 U2 F' U' F U2 R2 U'"),
        Pattern("6 Corner Twists, 2 Color Framed Cubes (2)", "AAALW", "randelshofer",
            "F R' F R' U' F R F' U' F",
            "F R' F U2 F R' U R' F2 U'"),
        Pattern("6 Corner Twists, 2 Color Framed Cubes (3)", "AAAFr", "randelshofer",
            "F' U F R' F' U R F' R F'",
            "U2 R F' R' U R U' R F2 U'"),
        Pattern("Corner Swap (urf,ubr)", "A4h4P", "randelshofer",
            "B U' B L2 F' D F L2 B2 U",
            "R2 F2 R' U' R F2 R' U R' U'"),
        Pattern("Corner Swap (ufl,ubr)", "A04A9", "randelshofer",
            "R' U R U B2 U R' U' R U' B2",
            "F U' R U F' R2 F' U' R' U R2"),
        Pattern("Self-Solving Algorithms (A B)", "A0w8S", "randelshofer",
            "D2 F2 D2 R'",
            "R U2 F2 U2")
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
