///
/// CFOP: cross, first two layers, orient the last layer, permute it.
///
/// The same four steps a speedcuber works in, and the same last two the
/// beginner method here ends with. What differs is the middle: the beginner
/// places the bottom corners and then the middle edges, two searches with a
/// named state between them, while this solves both layers as one.
///
/// **This is not textbook F2L, and the difference is worth stating.** A person
/// solving CFOP inserts the four corner-edge pairs one at a time, recognising
/// each pair and choosing an insertion for it; the pairs are the whole skill of
/// the step. `CubeSolve.Solve.TwoLayers` instead searches the first two layers
/// as a single goal, which finds shorter sequences than pair-by-pair insertion
/// and teaches nothing about pairs. So the step is called `F2L` because that is
/// the state it reaches, and it is not a demonstration of how to do F2L.
///
/// The last layer is the full 57 OLL cases and 21 PLL cases, which is what CFOP
/// means -- unlike the beginner method, where using the full sets is a
/// simplification worth flagging.
///
/// **Nothing here is optimal.** Four steps each short for its own goal do not
/// make a short solution; `CubeSolve.Solve.Standard` answers a whole cube in
/// about the moves this spends before the last layer.
///
mod CubeSolve.Method.Cfop {

    use CubeSolve.Method.Beginner
    use CubeSolve.Method.Plan
    use CubeSolve.Method.Profile
    use CubeSolve.Method.Steps
    use CubeSolve.Model.Cube
    use CubeSolve.Solve.Cross
    use CubeSolve.Table.Cache
    use CubeSolve.Solve.FirstLayer
    use CubeSolve.Solve.TwoLayers

    ///
    /// Everything the method needs to answer with.
    ///
    /// The two-layer tables and nothing else: the cross projection this needs
    /// first is one of the four they already carry. Building takes about eighty
    /// seconds, so a caller solving more than one cube should build once.
    ///
    /// These are the same tables `CubeSolve.Method.Beginner` builds. A program
    /// offering both methods should build one set and hand it to each.
    ///
    pub def build(): Result[String, TwoLayers.Tables] =
        TwoLayers.build()

    ///
    /// The same tables, read from the cache where they are there.
    ///
    /// **Prefer this to `build`.** A program that solves one cube per process
    /// and calls `build` rebuilds 3.8 million states every time it runs.
    ///
    pub def cachedTables(): Result[String, TwoLayers.Tables] \ Cache.Store =
        TwoLayers.cachedTables()

    ///
    /// Solve `c` as CFOP, in named steps.
    ///
    /// **Four stages: cross, F2L, OLL, PLL.** The first two are searched and
    /// the last two are recognised and played back. Either last-layer step may
    /// be a skip, reported as a step with no moves rather than left out.
    ///
    /// The cross is on `D`, as everywhere in this engine.
    ///
    pub def solution(
        t: TwoLayers.Tables,
        p: Profile.Profile,
        c: Cube.Cube,
        maxNodes: Int64
    ): Result[String, Plan.Plan] =
        forM (
            crossStep <- Steps.stage("Cross",
                Cross.solution(crossTableOf(t), c, maxNodes));
            afterCross <- Cube.applyNotation(crossStep#sequence, c);
            f2lStep <- Steps.stage("F2L", TwoLayers.solution(t, afterCross, maxNodes));
            afterF2l <- Cube.applyNotation(f2lStep#sequence, afterCross);
            _ <- reachedTwoLayers(afterF2l);
            lastSteps <- Steps.lastLayer(p, afterF2l);
            plan <- Steps.plan(List.append(crossStep :: f2lStep :: Nil, lastSteps))
        ) yield plan

    ///
    /// That the search really reached the first two layers.
    ///
    /// Read from `CubeSolve.Method.Beginner`'s ladder -- the decoded model --
    /// rather than from the search's own coordinate, so a step that satisfied
    /// its encoders and not the cube is caught here. The ladder is shared
    /// because the state is: CFOP's F2L and the beginner's third step finish in
    /// the same place by different routes, and one predicate saying so is what
    /// stops the two methods disagreeing about it.
    ///
    def reachedTwoLayers(c: Cube.Cube): Result[String, Unit] =
        if (Beginner.isComplete(Beginner.Stage.TwoLayers, c))
            Ok(())
        else
            Err("the cross and F2L steps ran but the cube is only at "
                + "${Beginner.reached(c)}: this is a fault in the method, not "
                + "in the cube")

    def crossTableOf(t: TwoLayers.Tables): CubeSolve.Table.TableView =
        let FirstLayer.Tables.Tables(cross, _) = TwoLayers.firstLayerTables(t);
        cross
}
