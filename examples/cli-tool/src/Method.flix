///
/// The commands that use a human method rather than a search.
///
/// Kept apart from `Engine`, which solves by looking, because these are
/// different products: a method answer recognises one particular partial state
/// and plays back an algorithm somebody memorised for it. It is longer than a
/// searched answer and is not offered as a solution to an arbitrary cube.
///
mod Method {

    use CubeSolve.Method.Pll
    use CubeSolve.Model.Cube

    ///
    /// `pll <scramble>` -- which PLL case this is, and how to finish it.
    ///
    /// Opt-in. Nothing routes ordinary solving through here, and `solve` is
    /// unchanged.
    ///
    pub def pll(c: Cube.Cube): Result[String, String] =
        Pll.recognize(c) |> Result.map(describe)

    ///
    /// A recognised case, written out.
    ///
    /// The setup and finishing turns are shown separately from the algorithm as
    /// well as inside the sequence, because they are what a person has to work
    /// out at the cube and the algorithm is the part they already know.
    ///
    def describe(found: Pll.Solution): String =
        List.join(String.lineSeparator(),
            "case      ${found#caseName}"
                :: "setup     ${turn(found#setup)}"
                :: "algorithm ${found#algorithm}"
                :: "finish    ${turn(found#finish)}"
                :: "sequence  ${found#sequence}"
                :: "optimal   ${found#optimalHtm} HTM published for this case; the "
                    + "algorithm above is speed-oriented, not shortest"
                :: "source    ${found#source}"
                :: Nil)

    ///
    /// A quarter-turn count as the turn a person makes, or nothing to do.
    ///
    def turn(k: Int32): String =
        let written = Pll.aufOf(k);
        if (String.isEmpty(written)) "none" else written

}
