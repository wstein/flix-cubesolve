///
/// Demo runner to print colourful cube nets to the screen.
///
mod DemoRender {

    use CubeSolve.Model.Cube
    use CubeSolve.Render
    use CubeSolve.Render.Qr.EcLevel

    pub def main(): Unit \ IO =
        match Cube.solved(4) |> Result.flatMap(c -> Cube.applyNotation("U R F", c)) {
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
                println("\n==> PNG Export (build/cube_qr_logo.png):");
                match Render.qrWritePng("build/cube_qr_logo.png", c, true) {
                    case Ok(()) =>
                        println("Saved PNG with colorful cube logo to build/cube_qr_logo.png")
                    case Err(e) =>
                        println("Error exporting PNG: ${e}")
                }
            case Err(e) => println("Error applying notation: ${e}")
        }

}
