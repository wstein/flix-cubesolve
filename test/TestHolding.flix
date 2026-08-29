///
/// Identity up to how a cube is held.
///
/// The distinction this module exists for is easy to state and easy to get
/// wrong: `Eq` on a cube is exact state equality, and `sameUpToHolding` is
/// equality of *pattern*. Every test here is about the second while leaving the
/// first alone -- the group laws and round trips elsewhere depend on `==`
/// meaning identical.
///
mod TestHolding {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Facelets
    use CubeSolve.Model.Holding
    use CubeSolve.Model.Rotation

    def made(size: Int32, alg: String): Cube.Cube \ Assert =
        match Cube.solved(size) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    def identity(what: String, c: Cube.Cube): String \ Assert =
        match Holding.identityOf(c) {
            case Some(t) => t
            case None    =>
                Assert.assertTrueWithMsg(false, "${what}: no identity");
                ""
        }

    ///
    /// Every one of the 24 holdings gives the same identity, at both sizes that
    /// have one -- and each size under its own relation.
    ///
    /// The 3x3x3 is re-held by conjugation and the 2x2x2 by moves, because a
    /// centreless cube turned in the hand really does move pieces between slots.
    /// Feeding each size the other's relation is the mistake this guards.
    ///
    @Test
    def everyHoldingOfAPatternHasOneIdentity(): Unit \ Assert =
        let standard = made(3, "R U R' U' F2 L D B'");
        let wanted3 = identity("3x3x3", standard);
        Rotation.all() |> Vector.forEach(r ->
            match Cube.conjugate(r, standard) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "conjugating")
                case Ok(held) =>
                    Assert.assertEqWithMsg(expected = wanted3, identity("3x3x3 as ${r}", held),
                        "a 3x3x3 held as ${r} is the same pattern")
            });

        let pocket = made(2, "R U' F2 R U");
        let wanted2 = identity("2x2x2", pocket);
        Holding.reorientations() |> Vector.forEach(match (r, word) ->
            match Cube.applyNotation(word, pocket) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${word}'")
                case Ok(held) =>
                    Assert.assertEqWithMsg(expected = wanted2, identity("2x2x2 as ${r}", held),
                        "a 2x2x2 held as ${r} is the same pattern")
            })

    ///
    /// `sameUpToHolding` is reflexive and symmetric, and says exactly what
    /// comparing two identities says.
    ///
    /// Also that it is *not* `Eq`: a re-held cube is a different state and the
    /// same pattern, and both of those must stay true at once.
    ///
    @Test
    def sameUpToHoldingIsAnEquivalenceAndAgreesWithIdentity(): Unit \ Assert =
        let cubes = Vector#{
            made(3, "R U R' U'"), made(3, "M2 S2 E2"), made(3, ""), made(3, "F2 B2")
        };
        cubes |> Vector.forEach(a -> {
            Assert.assertTrueWithMsg(Holding.sameUpToHolding(a, a), "reflexive");
            cubes |> Vector.forEach(b -> {
                Assert.assertEqWithMsg(
                    expected = Holding.sameUpToHolding(a, b), Holding.sameUpToHolding(b, a),
                    "symmetric");
                Assert.assertEqWithMsg(
                    expected = Holding.identityOf(a) == Holding.identityOf(b),
                    Holding.sameUpToHolding(a, b),
                    "agrees with identity equality")
            })
        });
        // The point of the whole module: same pattern, different state.
        let upright = made(3, "R U R' U'");
        match Cube.conjugate(Rotation.y(), upright) {
            case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "conjugating")
            case Ok(held) =>
                Assert.assertTrueWithMsg(Holding.sameUpToHolding(upright, held),
                    "a re-held cube is the same pattern");
                Assert.assertNeqWithMsg(unexpected = Cube.orbits(upright), Cube.orbits(held),
                    "and is not the same state -- Eq must stay exact")
        }

    ///
    /// `ofToken` inverts the encoding, and a canonical token is its own
    /// identity.
    ///
    @Test
    def ofTokenRoundTripsAndCanonicalTokensAreFixedPoints(): Unit \ Assert =
        Vector#{(3, "R U R' U' F2 L D B'"), (2, "R U' F2 R U")} |> Vector.forEach(
            match (n, alg) -> {
                let c = made(n, alg);
                let raw = Facelets.token(c) |> Result.getWithDefault("?");
                match Holding.ofToken(n, raw) {
                    case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "decoding ${raw}")
                    case Ok(back) =>
                        Assert.assertEqWithMsg(expected = Cube.orbits(c), Cube.orbits(back),
                            "a token decodes to the state it encoded")
                };
                // and the canonical token decodes to some holding of the same pattern
                let canon = identity("${n}x${n}x${n}", c);
                match Holding.ofToken(n, canon) {
                    case Err(e)   => Assert.assertEqWithMsg(expected = "", e, "decoding ${canon}")
                    case Ok(back) =>
                        Assert.assertEqWithMsg(expected = canon, identity("canonical", back),
                            "a canonical token is its own identity");
                        Assert.assertTrueWithMsg(Holding.sameUpToHolding(c, back),
                            "and describes the same pattern")
                }
            })

    ///
    /// A cube with centre orbits has no identity here, and does not compare
    /// equal to anything up to holding -- including itself.
    ///
    /// Returning `None` is the honest answer: centres are a multiset of colours,
    /// so nothing can say where another state sent each centre slot. Answering
    /// "no" to a question that cannot be answered is safe; answering "yes" is
    /// not, and a reflexive `true` here would be exactly that.
    ///
    @Test
    def sizesWithCentreOrbitsHaveNoHoldingIdentity(): Unit \ Assert =
        Vector#{4, 5} |> Vector.forEach(n -> {
            let c = made(n, "R U");
            Assert.assertEqWithMsg(expected = None, Holding.identityOf(c),
                "a ${n}x${n}x${n} has no holding identity yet");
            Assert.assertFalseWithMsg(Holding.sameUpToHolding(c, c),
                "and cannot be compared up to holding, even with itself")
        });
        // It is still a perfectly good cube, and still exactly equal to itself.
        let big = made(4, "R U");
        Assert.assertEq(expected = Cube.orbits(big), Cube.orbits(made(4, "R U")))

    ///
    /// The corpora delegate rather than keeping their own copy.
    ///
    /// Both had grown one, and two implementations of a rule this subtle is how
    /// they drift. If either stops agreeing with the model, this fails.
    ///
    @Test
    def bothCorporaDelegateToTheModel(): Unit \ Assert =
        CubeSolve.Patterns.Standard.all() |> Vector.forEach(p -> {
            let c = made(3, CubeSolve.Patterns.Standard.faceTurns(p));
            Assert.assertEqWithMsg(
                expected = Holding.identityOf(c), CubeSolve.Patterns.Standard.identify(c),
                "'${CubeSolve.Patterns.Standard.name(p)}' disagrees with the model");
            Assert.assertEqWithMsg(
                expected = Some(CubeSolve.Patterns.Standard.canonical(p)), Holding.identityOf(c),
                "'${CubeSolve.Patterns.Standard.name(p)}' recorded identity changed")
        });
        CubeSolve.Patterns.Pocket.all() |> Vector.forEach(p -> {
            let c = made(2, CubeSolve.Patterns.Pocket.optimal(p));
            Assert.assertEqWithMsg(
                expected = Holding.identityOf(c), CubeSolve.Patterns.Pocket.identify(c),
                "'${CubeSolve.Patterns.Pocket.name(p)}' disagrees with the model");
            Assert.assertEqWithMsg(
                expected = Some(CubeSolve.Patterns.Pocket.canonical(p)), Holding.identityOf(c),
                "'${CubeSolve.Patterns.Pocket.name(p)}' recorded identity changed")
        })

}
