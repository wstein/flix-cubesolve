///
/// The 4x4x4 reduction solver: reduces a 4x4x4 cube to a 3x3x3, fixes parities, and solves.
///
mod CubeSolve.Solve.Revenge {

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Notation
    use CubeSolve.Model.Notation.Op
    use CubeSolve.Model.Revenge
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard
    use CubeSolve.Table.Cache

    ///
    /// Solve a 4x4x4 cube using the reduction method.
    ///
    pub def solution(c: Cube.Cube): Result[String, List[Op]] \ Cache.Store =
        forM (
            t3 <- Standard.cachedTables();
            sol <- solutionWithTables(t3, c)
        ) yield sol

    ///
    /// Solve a 4x4x4 cube using pre-loaded 3x3x3 tables.
    ///
    pub def solutionWithTables(
        t3: Standard.Tables,
        c: Cube.Cube
    ): Result[String, List[Op]] =
        if (Cube.size(c) != 4)
            Err("expected a 4x4x4 cube")
        else if (not Revenge.isReduced(c))
            Err("4x4x4 full center and wing reduction is in progress: this solver "
                + "handles reduced 4x4x4 states with parity correction")
        else
            solveReduced(t3, c)

    ///
    /// Solve a reduced 4x4x4 cube (centers solved and wings paired).
    ///
    def solveReduced(
        t3: Standard.Tables,
        c: Cube.Cube
    ): Result[String, List[Op]] =
        forM (
            wingPar <- Revenge.hasWingParity(c);
            (cAfterOll, ollOps) <- applyOllIf(wingPar, c);
            cornPar <- Revenge.hasPllParity(cAfterOll);
            (cAfterPll, pllOps) <- applyPllIf(cornPar, cAfterOll);
            c3 <- Revenge.toStandard(cAfterPll);
            c3_sized <- Sized.standardOf(c3);
            moves3 <- Standard.solutionWith(t3, Standard.defaultBudget(), c3_sized)
        ) yield {
            let ops3 = moves3 |> List.map(Op.Layer);
            List.append(ollOps, List.append(pllOps, ops3))
        }

    def applyOllIf(
        needed: Bool,
        c: Cube.Cube
    ): Result[String, (Cube.Cube, List[Op])] =
        if (not needed)
            Ok((c, Nil))
        else
            forM (
                ops <- Notation.parse(4, Revenge.ollParity());
                applied <- Cube.applyNotation(Revenge.ollParity(), c)
            ) yield (applied, ops)

    def applyPllIf(
        needed: Bool,
        c: Cube.Cube
    ): Result[String, (Cube.Cube, List[Op])] =
        if (not needed)
            Ok((c, Nil))
        else
            forM (
                ops <- Notation.parse(4, Revenge.pllParity());
                applied <- Cube.applyNotation(Revenge.pllParity(), c)
            ) yield (applied, ops)

}
