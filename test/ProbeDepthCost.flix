///
/// What a deeper phase one costs, and what it buys.
///
/// `A_VAs734dSkb` has a seventeen-move solution. Every shipped budget answers
/// nineteen, and the reason is the phase-one depth rather than the handover
/// limit: the endings leading to a seventeen do not exist at depth twelve, so
/// enumerating more of them cannot find one. Depth fifteen with a hundred
/// thousand handovers does find it.
///
/// What it costs is measured here:
///
/// ```text
///   depth  handovers   HTM   probes   seconds   reaches 17
///   12     25000       19    304      13.2      no
///   13     25000       19    348      45.4      no
///   14     25000       19    350      78.7      no
///   15     25000       19    350      110.5     no
///   14     100000      17    397      253.9     yes
///   15     100000      17    397      370.7     yes
/// ```
///
/// **Both knobs are needed and neither is enough.** Depth up to fifteen at
/// twenty-five thousand handovers never reaches seventeen; a hundred thousand
/// handovers at depth twelve never reaches it either. It takes depth fourteen
/// *and* a hundred thousand, which is the same shape of interaction the views
/// and handovers showed.
///
/// **The cheapest cell that reaches it costs 254 seconds**, against three for
/// the shipped `max`. Depth fifteen buys nothing over fourteen: the same
/// answer, the same 397 probes, and 117 seconds more.
///
/// The probe count barely moves across the whole grid -- 304 to 397 -- while the
/// time goes up twentyfold. The cost is phase-one enumeration, not phase-two
/// probing, which is why a probe cap was never the thing holding it back.
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
        (12, 25000) :: (13, 25000) :: (14, 25000) :: (15, 25000)
            :: (14, 100000) :: (15, 100000) :: Nil

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
