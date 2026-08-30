///
/// JSON serialization for CLI tool output using standard library Util.Json.
///
mod JsonOut {

    use Util.Json.Json
    use Util.Json.Json.{JString, JObject, JArray, JNull, JBool, JNumber}

    /// JSON integer number
    pub def num(n: Int32): Json = JNumber(Int32.toBigDecimal(n))

    /// JSON string
    pub def str(s: String): Json = JString(s)

    /// JSON boolean
    pub def bool(b: Bool): Json = JBool(b)

    /// JSON string array
    pub def strArray(xs: List[String]): Json =
        JArray(xs |> List.map(JString) |> List.toVector)

    /// Error response JSON
    pub def error(msg: String): String =
        let obj = JObject(Map#{
            "error" => bool(true),
            "message" => str(msg)
        });
        "${obj}"

    /// Solve response JSON
    pub def solution(size: Int32, token: String, sol: String, moves: List[String]): String =
        let obj = JObject(Map#{
            "command" => str("solve"),
            "size" => num(size),
            "token" => str(token),
            "solution" => str(sol),
            "length" => num(List.length(moves)),
            "moves" => strArray(moves)
        });
        "${obj}"

    /// Show response JSON
    pub def show(size: Int32, token: String, net: String, facelets: Vector[Int32]): String =
        let fsJson = JArray(Vector.map(f -> num(f), facelets));
        let obj = JObject(Map#{
            "command" => str("show"),
            "size" => num(size),
            "token" => str(token),
            "net" => str(net),
            "facelets" => fsJson
        });
        "${obj}"

    /// Identify response JSON when a pattern is found
    pub def identifyFound(
        size: Int32,
        token: String,
        name: String,
        notat: String,
        url: String,
        held: String,
        sol: String
    ): String =
        let obj = JObject(Map#{
            "command" => str("identify"),
            "size" => num(size),
            "token" => str(token),
            "found" => bool(true),
            "name" => str(name),
            "notation" => str(notat),
            "url" => str(url),
            "held" => str(held),
            "solution" => str(sol)
        });
        "${obj}"

    /// Identify response JSON when no pattern is found
    pub def identifyNotFound(size: Int32, token: String): String =
        let obj = JObject(Map#{
            "command" => str("identify"),
            "size" => num(size),
            "token" => str(token),
            "found" => bool(false),
            "message" => str("no published pattern")
        });
        "${obj}"

    /// Scramble response JSON
    pub def scramble(
        size: Int32,
        text: String,
        token: String,
        atMost: Int32,
        atLeast: Int32,
        moves: List[String]
    ): String =
        let obj = JObject(Map#{
            "command" => str("scramble"),
            "size" => num(size),
            "token" => str(token),
            "scramble" => str(text),
            "atMostMoves" => num(atMost),
            "atLeastMoves" => num(atLeast),
            "moves" => strArray(moves)
        });
        "${obj}"

    /// Method (OLL/PLL) response JSON
    pub def method(
        cmd: String,
        caseName: String,
        auf: String,
        algo: String,
        prof: String,
        url: String
    ): String =
        let obj = JObject(Map#{
            "command" => str(cmd),
            "case" => str(caseName),
            "auf" => str(auf),
            "algorithm" => str(algo),
            "profile" => str(prof),
            "url" => str(url)
        });
        "${obj}"

    /// Patterns listing response JSON
    pub def patterns(size: Int32, items: List[(String, String, String)]): String = {
        let patternObjs = items |> List.map(item -> {
            let (name, tok, notat) = item;
            JObject(Map#{
                "name" => str(name),
                "token" => str(tok),
                "notation" => str(notat)
            })
        }) |> List.toVector;
        let obj = JObject(Map#{
            "command" => str("patterns"),
            "size" => num(size),
            "count" => num(List.length(items)),
            "patterns" => JArray(patternObjs)
        });
        "${obj}"
    }

}
