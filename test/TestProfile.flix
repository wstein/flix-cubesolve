///
/// Choosing among the algorithms published for a case.
///
/// A profile is a stated rule, so what is tested is that the rule was applied,
/// that the result still works, and that a rule which could not be applied says
/// so instead of quietly doing something else.
///
mod TestProfile {

    use CubeSolve.Method.LastLayer
    use CubeSolve.Method.Oll
    use CubeSolve.Method.Pll
    use CubeSolve.Method.Profile
    use CubeSolve.Method.Profile.Profile.{SourceFirst, Shortest, NoRotations}
    use CubeSolve.Method.Profile.Status.{Chosen, FellBack}
    use CubeSolve.Model.Cube

    def made(alg: String): Cube.Cube \ Assert =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c)  => c
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "'${alg}'"); unreachable!()
        }

    ///
    /// Every profile's choice for every PLL case still solves it, from every
    /// angle.
    ///
    /// The choice changes which algorithm comes back and therefore which `U`
    /// turns go with it, so each has to be replayed rather than assumed to
    /// inherit the default's.
    ///
    @Test
    def everyProfilesChoiceStillSolvesEveryPllCase(): Unit \ Assert =
        Profile.all() |> Vector.forEach(p ->
            Pll.all() |> Vector.forEach(one ->
                Vector.range(0, 4) |> Vector.forEach(auf -> {
                    let c = made("${Pll.aufOf(auf)} (${Pll.algorithm(one)})'");
                    match Pll.recognizeWith(p, c) {
                        case Err(e) => Assert.assertEqWithMsg(expected = "", e,
                            "${Profile.nameOf(p)} on '${Pll.name(one)}'")
                        case Ok(found) =>
                            Assert.assertEqWithMsg(expected = Pll.name(one), found#caseName,
                                "${Profile.nameOf(p)} recognised a different case");
                            match Cube.applyNotation(found#sequence, c) {
                                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "replay")
                                case Ok(after) =>
                                    Assert.assertTrueWithMsg(Cube.isSolved(after),
                                        "${Profile.nameOf(p)} on '${Pll.name(one)}' "
                                            + "turned ${auf}: '${found#sequence}' "
                                            + "does not solve it")
                            }
                    }
                })))

    ///
    /// The same for OLL, checking the layers below survive as well.
    ///
    @Test
    def everyProfilesChoiceStillOrientsEveryOllCase(): Unit \ Assert =
        Profile.all() |> Vector.forEach(p ->
            Oll.all() |> Vector.forEach(one -> {
                let c = made("(${Oll.algorithm(one)})'");
                match Oll.recognizeWith(p, c) {
                    case Err(e) => Assert.assertEqWithMsg(expected = "", e,
                        "${Profile.nameOf(p)} on '${Oll.name(one)}'")
                    case Ok(found) =>
                        match Cube.applyNotation(found#sequence, c) {
                            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "replay")
                            case Ok(after) =>
                                Assert.assertTrueWithMsg(LastLayer.topIsOriented(after),
                                    "${Profile.nameOf(p)} on '${Oll.name(one)}' did not orient");
                                Assert.assertEqWithMsg(expected = None,
                                    LastLayer.faultBelowTheTop(after),
                                    "${Profile.nameOf(p)} on '${Oll.name(one)}' "
                                        + "disturbed the layers below")
                        }
                }
            }))

    ///
    /// Each rule picks what it says it picks.
    ///
    @Test
    def eachRulePicksWhatItSays(): Unit \ Assert =
        Pll.all() |> Vector.forEach(one -> {
            let vs = Pll.variants(one);
            Assert.assertEqWithMsg(expected = Vector.get(0, vs),
                Profile.pick(SourceFirst, vs)#algorithm,
                "'${Pll.name(one)}': default is the source's first");
            let short = Profile.pick(Shortest, vs);
            vs |> Vector.forEach(v ->
                Assert.assertTrueWithMsg(Profile.layerTurns(v) >= short#layerTurns,
                    "'${Pll.name(one)}': a variant is shorter than the one shortest "
                        + "picked"));
            let free = Profile.pick(NoRotations, vs);
            match free#status {
                case Chosen   =>
                    Assert.assertFalseWithMsg(Profile.turnsTheCube(free#algorithm),
                        "'${Pll.name(one)}': no-rotations picked one that rotates")
                case FellBack =>
                    Assert.assertTrueWithMsg(
                        vs |> Vector.forAll(Profile.turnsTheCube),
                        "'${Pll.name(one)}': no-rotations fell back although a "
                            + "rotation-free variant is recorded");
                    Assert.assertTrueWithMsg(
                        String.contains(substr = "no rotation-free", free#note),
                        "the fallback should say why: ${free#note}")
            }
        })

    ///
    /// Picking is deterministic: the same case and profile always give the same
    /// algorithm.
    ///
    @Test
    def pickingIsDeterministic(): Unit \ Assert =
        Profile.all() |> Vector.forEach(p ->
            Pll.all() |> Vector.forEach(one -> {
                let vs = Pll.variants(one);
                Assert.assertEqWithMsg(
                    expected = Profile.pick(p, vs)#algorithm, Profile.pick(p, vs)#algorithm,
                    "'${Pll.name(one)}' under ${Profile.nameOf(p)}")
            }))

    ///
    /// A rotation-free success and a documented fallback, both named.
    ///
    /// Fixed cases rather than "whichever happens to be first", so that a change
    /// to the collection that removed either behaviour would be noticed.
    ///
    @Test
    def bothOutcomesOfNoRotationsAreExercised(): Unit \ Assert =
        // T-PLL's first algorithm has no rotation in it at all.
        let tperm = Pll.all() |> Vector.findLeft(one -> Pll.name(one) == "T-PLL");
        match tperm {
            case None      => Assert.assertTrueWithMsg(false, "T-PLL should be recorded")
            case Some(one) =>
                let free = Profile.pick(NoRotations, Pll.variants(one));
                Assert.assertEqWithMsg(expected = Chosen, free#status,
                    "T-PLL has a rotation-free algorithm");
                Assert.assertFalse(Profile.turnsTheCube(free#algorithm))
        };
        // Somewhere in the two collections there is a case with no rotation-free
        // variant at all; whichever it is, the fallback has to be reported.
        let fellBack = Oll.all()
            |> Vector.map(one -> Profile.pick(NoRotations, Oll.variants(one)))
            |> Vector.findLeft(ch -> ch#status == FellBack);
        match fellBack {
            case None     => ()
            case Some(ch) =>
                Assert.assertTrueWithMsg(String.contains(substr = "no rotation-free", ch#note),
                    "a fallback must say so: ${ch#note}")
        }

    ///
    /// Profile names round-trip, and an unknown one is refused.
    ///
    @Test
    def profileNamesRoundTrip(): Unit \ Assert =
        Profile.all() |> Vector.forEach(p ->
            Assert.assertEqWithMsg(expected = Some(p), Profile.ofName(Profile.nameOf(p)),
                "${Profile.nameOf(p)} should round-trip"));
        Assert.assertEq(expected = None, Profile.ofName("fastest"))

}
