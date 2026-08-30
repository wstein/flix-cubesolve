///
/// Demo runner to print colourful cube nets to the screen.
///
mod DemoRender {

    use CubeSolve.Model.Cube
    use CubeSolve.Render

    pub def main(): Unit \ IO =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation("U R F", c)) {
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
                }
            case Err(e) => println("Error applying notation: ${e}")
        }

}
