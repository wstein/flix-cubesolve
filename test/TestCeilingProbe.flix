mod TestCeilingProbe {
    use CubeSolve.Model.Holding
    use CubeSolve.Model.Sized
    use CubeSolve.Solve.Standard

    @Test
    def howFarDoesTwoPhaseGo(): Unit \ Assert + IO =
        match Sys.Env.handle(_ -> Sys.Env.getVar("CUBESOLVE_ABLATION"))(()) {
            case Some("1") => probe()
            case _         => ()
        }

    def probe(): Unit \ Assert + IO =
        match (Standard.buildTables(),
               Holding.ofToken(3, "A_VAs734dSkb") |> Result.flatMap(Sized.standardOf)) {
            case (Ok(t), Ok(c)) =>
                println("");
                println("  depth  handovers   HTM   probes");
                let plans = (13, 25000) :: (13, 100000) :: (14, 25000)
                    :: (14, 100000) :: (15, 25000) :: Nil;
                plans |> List.forEach(match (d, h) -> {
                    let b = Standard.budget({
                        minViews = 6, probeMax = 400000, maxDepth = 25,
                        handovers = h, phase1Depth = d
                    });
                    let out = Standard.solveWithOutcome(t, b, c);
                    let htm = match out#finalHtm {
                        case Some(n) => "${n}"
                        case None    => "none"
                    };
                    println("  ${String.padRight(7, ' ', "${d}")}"
                        + "${String.padRight(12, ' ', "${h}")}"
                        + "${String.padRight(6, ' ', htm)}"
                        + "${out#probesSpent}")
                })
            case _ => Assert.assertTrueWithMsg(false, "setup")
        }
}
