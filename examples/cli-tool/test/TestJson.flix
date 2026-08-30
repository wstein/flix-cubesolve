mod TestJson {

    use CubeSolve.Model.Cube

    def made(n: Int32, notation: String): Cube.Cube =
        match Cube.solved(n) {
            case Ok(sol) =>
                Cube.applyNotation(notation, sol) |> Result.getWithDefault(sol)
            case Err(_)  => unreachable!()
        }

    /// Test error JSON format.
    @Test
    def errorFormatProducesValidJson(): Unit \ Assert = {
        let json = JsonOut.error("invalid token");
        Assert.assertTrue(String.contains(substr = "\"error\":true", json));
        Assert.assertTrue(String.contains(substr = "\"message\":\"invalid token\"", json))
    }

    /// Test solve JSON format.
    @Test
    def solveFormatProducesExpectedFields(): Unit \ Assert = {
        let json = JsonOut.solution(3, "tok123", "R U R' U'", "R" :: "U" :: "R'" :: "U'" :: Nil);
        Assert.assertTrue(String.contains(substr = "\"command\":\"solve\"", json));
        Assert.assertTrue(String.contains(substr = "\"size\":3", json));
        Assert.assertTrue(String.contains(substr = "\"length\":4", json));
        Assert.assertTrue(String.contains(substr = "\"solution\":\"R U R' U'\"", json))
    }

    /// Test show JSON format.
    @Test
    def showFormatProducesNetAndFacelets(): Unit \ Assert = {
        let c = made(3, "");
        let json = Corpus.showJson(3, c) |> Result.getWithDefault("");
        Assert.assertTrue(String.contains(substr = "\"command\":\"show\"", json));
        Assert.assertTrue(String.contains(substr = "\"facelets\":[", json));
        Assert.assertTrue(String.contains(substr = "\"net\":", json))
    }

    /// Test identify JSON format for recognized pattern.
    @Test
    def identifyFormatProducesPatternDetails(): Unit \ Assert = {
        let c = made(3, "M2 E2 S2");
        let json = Corpus.identifyJson(3, c);
        Assert.assertTrue(String.contains(substr = "\"command\":\"identify\"", json));
        Assert.assertTrue(String.contains(substr = "\"found\":true", json));
        Assert.assertTrue(String.contains(substr = "\"name\":", json))
    }

    /// Test patterns listing JSON format.
    @Test
    def patternsFormatProducesJsonArray(): Unit \ Assert = {
        let json = Corpus.patternsJson(2);
        Assert.assertTrue(String.contains(substr = "\"command\":\"patterns\"", json));
        Assert.assertTrue(String.contains(substr = "\"count\":89", json));
        Assert.assertTrue(String.contains(substr = "\"patterns\":[", json));
        Assert.assertTrue(String.contains(substr = "\"token\":", json))
    }

    /// Test scramble JSON format.
    @Test
    def scrambleFormatProducesExpectedFields(): Unit \ Assert = {
        let json = JsonOut.scramble(3, "R U R'", "AAAAAAAAAAf_", 20, 15, "R" :: "U" :: "R'" :: Nil);
        Assert.assertTrue(String.contains(substr = "\"command\":\"scramble\"", json));
        Assert.assertTrue(String.contains(substr = "\"token\":\"AAAAAAAAAAf_\"", json));
        Assert.assertTrue(String.contains(substr = "\"atMostMoves\":20", json))
    }

    /// Test withJson extracts --json flag from argument list.
    @Test
    def withJsonExtractsFlagFromArguments(): Unit \ Assert = {
        let argsWith = "--size" :: "3" :: "--json" :: "R U R' U'" :: Nil;
        let _ = Args.withJson(argsWith, (isJson, rest) -> {
            Assert.assertTrue(isJson);
            Assert.assertEq(expected = "--size" :: "3" :: "R U R' U'" :: Nil, rest);
            Ok("")
        });
        let argsWithout = "--size" :: "3" :: "R U R' U'" :: Nil;
        let _ = Args.withJson(argsWithout, (isJson, rest) -> {
            Assert.assertFalse(isJson);
            Assert.assertEq(expected = argsWithout, rest);
            Ok("")
        });
        ()
    }

}
