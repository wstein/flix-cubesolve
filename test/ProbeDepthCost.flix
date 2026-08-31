///
/// What a deeper phase one costs, and what it buys.
///
/// `A_VAs734dSkb` has a seventeen-move solution. Every shipped budget answers
/// nineteen, and the reason is the phase-one depth rather than the handover
/// limit: the endings leading to a seventeen do not exist at depth twelve, so
/// enumerating more of them cannot find one. Depth fifteen with a hundred
/// thousand handovers does find it.
///
/// What is not known is the cheapest setting that does. This measures the grid.
///
/// **A binary rather than a test**, for the reason `QualifyCacheRace` is one:
/// it is a measurement that takes minutes, and running it inside the suite
/// makes every attempt pay for the suite first and occupies the machine for
/// as long as the grid takes. `--entrypoint` reaches a definition under `test/`,
/// so this stays out of `src/` and the library still ships no `main`.
///
/// ```sh
/// ./flixw build-fatjar --entrypoint ProbeDepthCost.probe
/// java -jar artifact/cubesolve.jar
/// ```
///
mod ProbeDepthCost {

    use CubeSolve.Model.Holding
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard

    ///
    /// The cube being measured, and the answer known to exist for it.
    ///
    def token(): String = "A_VAs734dSkb"

    def target(): Int32 = 17

    ///
    /// Depth against handovers, cheapest first.
    ///
    /// Depth twelve is included as the anchor: without it the other rows are
    /// only comparable to each other, and the question is what deeper buys over
    /// what ships today.
    ///
    def grid(): List[(Int32, Int32)] =
        (12, 25000) :: (13, 25000) :: (13, 100000)
            :: (14, 25000) :: (14, 100000) :: (15, 25000) :: (15, 100000) :: Nil

    ///
    /// Run the grid, one line per cell.
    ///
    pub def probe(): Unit \ IO =
        match (Standard.buildTables(),
               Holding.ofToken(3, token()) |> Result.flatMap(Sized.standardOf)) {
            case (Ok(t), Ok(c)) =>
                println("cube ${token()}, a ${target()}-move solution is known");
                println("");
                println("  depth  handovers   HTM   probes   seconds   reaches ${target()}");
                grid() |> List.forEach(match (d, h) -> measure(t, c, d, h))
            case (Err(e), _) => println("tables: ${e}")
            case (_, Err(e)) => println("cube: ${e}")
        }

    ///
    /// One cell: what it answered, what it spent, how long it took.
    ///
    def measure(
        t: Standard.Tables,
        c: Sized.Standard,
        depth: Int32,
        handovers: Int32
    ): Unit \ IO =
        let b = Standard.budget({
            minViews = 6, probeMax = 400000, maxDepth = 25,
            handovers = handovers, phase1Depth = depth
        });
        let started = Time.Clock.runWithIO(_ -> Time.Clock.now());
        let out = Standard.solveWithOutcome(t, b, c);
        let ended = Time.Clock.runWithIO(_ -> Time.Clock.now());
        let secs = Int64.toFloat64(ended - started) / 1000.0;
        let htm = match out#finalHtm {
            case Some(n) => "${n}"
            case None    => "none"
        };
        let hit = match out#finalHtm {
            case Some(n) => if (n <= target()) "yes" else "no"
            case None    => "no"
        };
        println("  ${String.padRight(7, ' ', "${depth}")}"
            + "${String.padRight(12, ' ', "${handovers}")}"
            + "${String.padRight(6, ' ', htm)}"
            + "${String.padRight(9, ' ', "${out#probesSpent}")}"
            + "${String.padRight(10, ' ', "${secs}")}"
            + "${hit}")
}
