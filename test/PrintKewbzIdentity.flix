mod PrintKewbzIdentity {

    use CubeSolve.Model.Move
    use CubeSolve.Model.Sized
    use CubeSolve.Patterns.Kewbz
    use CubeSolve.Solve.Standard

    pub def main(): Unit \ IO = match Standard.buildTables() {
        case Err(why) => println(why)
        case Ok(tables) =>
            Kewbz.all()
            |> Vector.filter(p ->
                Kewbz.size(p) == 3 and (Kewbz.name(p) == "4H" or Kewbz.name(p) == "4I"))
            |> Vector.forEach(p -> printGenerator(tables, p))
    }

    def printGenerator(tables: Standard.Tables, p: Kewbz.Pattern): Unit \ IO =
        match Kewbz.cube(p)
            |> Result.flatMap(Sized.standardOf)
            |> Result.flatMap(Standard.solutionWith(tables, Standard.thoroughBudget())) {
            case Ok(solution) =>
                println("${Kewbz.name(p)}: ${Move.showAll(Move.inverseOf(solution))}")
            case Err(why) => println("${Kewbz.name(p)}: ERROR ${why}")
        }

}
