///
/// Demo runner to print colourful cube nets to the screen.
///
mod DemoRender {

    use CubeSolve.Model.Cube
    use CubeSolve.Render

    pub def main(): Unit \ IO =
        match Cube.solved(3) |> Result.flatMap(c -> Cube.applyNotation("U R F", c)) {
            case Ok(c) => match Render.colouredNet(c) {
                case Ok(net) => println(net)
                case Err(e)  => println("Error rendering: ${e}")
            }
            case Err(e) => println("Error applying notation: ${e}")
        }

}
