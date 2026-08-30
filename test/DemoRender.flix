///
/// Demo runner to print colourful cube nets to the screen.
///
mod DemoRender {

    use CubeSolve.Model.Cube
    use CubeSolve.Render
    use CubeSolve.Render.Qr.EcLevel

    pub def main(): Unit \ IO =
        let alg = "2-4Fw' 2-4Rw2 2F2 2-4Rw2 2-4Dw2 2-3Fw2 2-4Dw S2 2-4Dw 2-3Fw L 2B' 2R2 2B L' 2B' Rw2 S' 2L2 S R2 S' 2L2 S";
        match Cube.solved(5) |> Result.flatMap(c -> Cube.applyNotation(alg, c)) {
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
                };
                println("\n==> Standalone 3D Cube Icon Export (build/cube_icon.png):");
                match Render.iconWritePng("build/cube_icon.png", c) {
                    case Ok(()) =>
                        println("Saved standalone 3D isometric cube icon to build/cube_icon.png")
                    case Err(e) =>
                        println("Error exporting cube icon: ${e}")
                };
                match Render.iconWritePngWithOptions("build/cube_icon_dark.png", c, 512, false) {
                    case Ok(()) =>
                        println("Saved standalone 3D cube icon (dark bg) to build/cube_icon_dark.png")
                    case Err(e) =>
                        println("Error exporting dark cube icon: ${e}")
                }
            case Err(e) => println("Error applying notation: ${e}")
        }

}
