/// The display command delegates to the portable library renderer.
mod TestCorpus {

    use CubeSolve.Model.Cube
    use CubeSolve.Render

    /// `show` is plain library output, not ANSI terminal artwork.
    @Test
    def showUsesThePortableFaceLetterNet(): Unit \ Assert = {
        let shown = Cube.solved(3)
            |> Result.flatMap(Corpus.show);
        let expected = Cube.solved(3)
            |> Result.flatMap(Render.net);
        Assert.assertEq(expected = expected, shown)
    }

}
