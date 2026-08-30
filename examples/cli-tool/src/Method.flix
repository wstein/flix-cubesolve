///
/// The commands that use a human method rather than a search.
///
/// Kept apart from `Engine`, which solves by looking, because these are
/// different products: a method answer recognises one particular partial state
/// and plays back an algorithm somebody memorised for it. It is longer than a
/// searched answer and is not offered as a solution to an arbitrary cube.
///
mod Method {

    use CubeSolve.Method.Oll
    use CubeSolve.Method.Pll
    use CubeSolve.Method.Profile
    use CubeSolve.Method.Profile.Status.{Chosen, FellBack}
    use CubeSolve.Model.Cube

    ///
    /// `pll <scramble>` -- which PLL case this is, and how to finish it.
    ///
    /// Opt-in. Nothing routes ordinary solving through here, and `solve` is
    /// unchanged.
    ///
    pub def pll(p: Profile.Profile, c: Cube.Cube): Result[String, String] =
        Pll.recognizeWith(p, c) |> Result.map(found -> describePll(p, found))

    ///
    /// `pll` case recognition as structured JSON.
    ///
    pub def pllJson(p: Profile.Profile, c: Cube.Cube): Result[String, String] =
        Pll.recognizeWith(p, c) |> Result.map(found ->
            JsonOut.method(
                "pll",
                found#caseName,
                setupTurn(found#setup),
                found#algorithm,
                "${p}",
                found#source
            ))

    ///
    /// `oll <scramble>` -- which OLL case this is, and how to orient it.
    ///
    pub def oll(p: Profile.Profile, c: Cube.Cube): Result[String, String] =
        Oll.recognizeWith(p, c) |> Result.map(found -> describeOll(p, found))

    ///
    /// `oll` case recognition as structured JSON.
    ///
    pub def ollJson(p: Profile.Profile, c: Cube.Cube): Result[String, String] =
        Oll.recognizeWith(p, c) |> Result.map(found ->
            JsonOut.method(
                "oll",
                found#caseName,
                setupTurn(found#setup),
                found#algorithm,
                "${p}",
                found#source
            ))

    ///
    /// A recognised case, written out.
    ///
    /// The setup and finishing turns are shown separately from the algorithm as
    /// well as inside the sequence, because they are what a person has to work
    /// out at the cube and the algorithm is the part they already know.
    ///
    def describePll(p: Profile.Profile, found: Pll.Solution): String =
        let head = "case      ${found#caseName}"
            :: "setup     ${setupTurn(found#setup)}"
            :: "algorithm ${found#algorithm}"
            :: "finish    ${closing(found#finish)}"
            :: "sequence  ${found#sequence}"
            :: "optimal   ${found#optimalHtm} HTM published for this case"
            :: Nil;
        let tail = List.append(profileLines(p, found#choice),
            "source    ${found#source}" :: Nil);
        List.join(String.lineSeparator(), List.append(head, tail))

    ///
    /// An oriented last layer, written out.
    ///
    def describeOll(p: Profile.Profile, found: Oll.Solution): String =
        let head = "case      ${found#caseName}"
            :: "setup     ${setupTurn(found#setup)}"
            :: "algorithm ${found#algorithm}"
            :: "sequence  ${found#sequence}"
            :: Nil;
        let tail = List.append(profileLines(p, found#choice),
            "source    ${found#source}" :: Nil);
        List.join(String.lineSeparator(), List.append(head, tail))

    ///
    /// Which profile was asked for, and what it did.
    ///
    /// A fallback is printed, not swallowed. Somebody who asked for
    /// rotation-free moves needs to know which cases could not give them any.
    ///
    def profileLines(p: Profile.Profile, choice: Profile.Choice): List[String] =
        let picked = match choice#status {
            case Chosen   => choice#note
            case FellBack => "default variant (${choice#note})"
        };
        "profile   ${Profile.nameOf(p)}"
            :: "selected  ${picked}, ${choice#layerTurns} layer turns"
            :: Nil

    ///
    /// The closing turn, or that there is none.
    ///
    /// Written rather than counted: an algorithm that leaves the cube rotated
    /// finishes on whatever face the original top layer now shows on, so this
    /// is a move rather than a number of `U` turns.
    ///
    def closing(written: String): String =
        if (String.isEmpty(written)) "none" else written

    ///
    /// A quarter-turn count as the turn a person makes, or nothing to do.
    ///
    def setupTurn(k: Int32): String =
        let written = Pll.aufOf(k);
        if (String.isEmpty(written)) "none" else written

}
