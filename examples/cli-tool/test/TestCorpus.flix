mod TestCorpus {

    use CubeSolve.Model.Cube
    use CubeSolve.Render

    /// `show` includes the rendered net and the Orbit64 token.
    @Test
    def showUsesThePortableFaceLetterNetAndToken(): Unit \ Assert = {
        let shown = Cube.solved(3)
            |> Result.flatMap(Corpus.show)
            |> Result.getWithDefault("");
        let expectedNet = Cube.solved(3)
            |> Result.flatMap(Render.net)
            |> Result.getWithDefault("");
        Assert.assertTrue(String.contains(substr = expectedNet, shown));
        Assert.assertTrue(String.contains(substr = "orbit64: ", shown))
    }

    /// `listing` includes name, canonical orbit64 token, and notation.
    @Test
    def listingIncludesCanonicalToken(): Unit \ Assert = {
        let l2 = Corpus.listing(2);
        Assert.assertTrue(String.length(l2) > 0);
        let l3 = Corpus.listing(3);
        Assert.assertTrue(String.length(l3) > 0);
        Assert.assertTrue(String.contains(substr = "\t", l3))
    }

}
