mod PrintKewbzIdentity {

    use CubeSolve.Model.Holding
    use CubeSolve.Patterns.Kewbz

    pub def main(): Unit \ IO =
        Kewbz.all()
        |> Vector.filter(p -> Kewbz.size(p) == 3)
        |> Vector.forEach(p -> {
            let res = Kewbz.cube(p) |> Result.toOption |> Option.flatMap(Holding.identityOf);
            match res {
                case Some(token) => println("${Kewbz.name(p)}: ${token}")
                case None        => println("${Kewbz.name(p)}: ERROR")
            }
        })

}
