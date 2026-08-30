///
/// Demo runner to print colourful cube nets to the screen.
///
mod DemoRender {

    use CubeSolve.Model.Cube
    use CubeSolve.Render
    use CubeSolve.Render.Qr.EcLevel

    pub def main(): Unit \ IO =
        let alg = "B' M2 U2 M2 B F2 R U' R U R2 U R2 F' U F' "
            + "Uw Lw Uw' Fw2 Dw Rw' Uw Fw Dw2 Rw2";
        match Cube.solved(4) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
            case Ok(c) =>
                println("==> Face letters (U R F D L B):");
                match Render.colouredNet(c) {
                    case Ok(net) => println(net)
                    case Err(e)  => println("Error rendering: ${e}")
                };
                println("\n==> Color letters (W R G Y O B):");
                match Render.colouredColorNet(c) {
                    case Ok(net) => println(net)
                    case Err(e)  => println("Error rendering: ${e}")
                };
                println("\n==> QR Code (Orbit64 token):");
                match Render.qrWithToken(c, EcLevel.H) {
                    case Ok(qr) => println(qr)
                    case Err(e) => println("Error generating QR: ${e}")
                };
                println("\n==> QR Code with URL (https://cubesolve.org/#...):");
                match Render.qrWithUrl(c, "https://cubesolve.org/#", EcLevel.H) {
                    case Ok(qr) => println(qr)
                    case Err(e) => println("Error generating URL QR: ${e}")
                };
                println("\n==> PNG Export (build/cube_qr_logo.png):");
                match Render.qrWritePng("build/cube_qr_logo.png", c, true) {
                    case Ok(()) =>
                        println("Saved PNG with colorful cube logo to build/cube_qr_logo.png")
                    case Err(e) =>
                        println("Error exporting PNG: ${e}")
                };
                let urlPath = "build/cube_qr_url.png";
                match Render.qrWritePngWithUrl(urlPath, c, "https://cubesolve.org/#", true) {
                    case Ok(()) =>
                        println("Saved URL PNG with colorful cube logo to build/cube_qr_url.png")
                    case Err(e) =>
                        println("Error exporting URL PNG: ${e}")
                }
            case Err(e) => println("Error applying notation: ${e}")
        }

}
