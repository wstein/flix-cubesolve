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

    ///
    /// A step method's answer: the ordered steps, and the whole sequence.
    ///
    /// The steps are the point of a method answer, so they are an array of
    /// objects rather than one string a caller would have to parse back. The
    /// flattened `sequence` is there too, because that is what gets replayed.
    ///
    pub def plan(
        size: Int32,
        token: String,
        method: String,
        sequence: String,
        layerTurns: Int32,
        steps: List[(String, String)]
    ): String =
        let stepObjs = steps |> List.map(match (label, moves) ->
            JObject(Map#{"step" => str(label), "moves" => str(moves)}));
        let obj = JObject(Map#{
            "size" => num(size),
            "state" => str(token),
            "method" => str(method),
            "steps" => JArray(List.toVector(stepObjs)),
            "sequence" => str(sequence),
            "layerTurns" => num(layerTurns)
        });
        "${obj}"

    /// Number or null for optional integers
    pub def numberOrNull(opt: Option[Int32]): Json = match opt {
        case Some(n) => num(n)
        case None    => JNull
    }

    /// Solve response JSON with method and pattern provenance
    pub def solution(
        size: Int32,
        token: String,
        sol: String,
        moves: List[String],
        method: String,
        metric: String,
        patternOpt: Option[(String, String)]
    ): String =
        solutionWithStats(size, token, sol, moves, method, metric, patternOpt, None)

    /// Solve response JSON with method, pattern provenance, and optional search outcome stats
    pub def solutionWithStats(
        size: Int32,
        token: String,
        sol: String,
        moves: List[String],
        method: String,
        metric: String,
        patternOpt: Option[(String, String)],
        statsOpt: Option[CubeSolve.Solve.Standard.Outcome]
    ): String =
        let patObj = match patternOpt {
            case Some((name, url)) => JObject(Map#{
                "found" => bool(true),
                "name" => str(name),
                "url" => str(url)
            })
            case None => JObject(Map#{
                "found" => bool(false)
            })
        };
        let baseMap = Map#{
            "command" => str("solve"),
            "size" => num(size),
            "token" => str(token),
            "solution" => str(sol),
            "length" => num(List.length(moves)),
            "metric" => str(metric),
            "method" => str(method),
            "pattern" => patObj,
            "moves" => strArray(moves)
        };
        let finalMap = match statsOpt {
            case Some(out) =>
                let termStr = match out#termination {
                    case CubeSolve.Solve.Standard.Termination.SolvedImmediately => "solved-immediately"
                    case CubeSolve.Solve.Standard.Termination.Settled => "settled"
                    case CubeSolve.Solve.Standard.Termination.ProbeCap => "probe-cap"
                    case CubeSolve.Solve.Standard.Termination.ViewsExhausted => "views-exhausted"
                };
                let statsObj = JObject(Map#{
                    "probesSpent" => num(out#probesSpent),
                    "viewTarget" => num(out#viewTarget),
                    "probeCap" => num(out#probeCap),
                    "viewsTried" => num(out#viewsTried),
                    "viewsAvailable" => num(out#viewsAvailable),
                    "firstHtm" => numberOrNull(out#firstHtm),
                    "finalHtm" => numberOrNull(out#finalHtm),
                    "improvements" => num(out#improvements),
                    "termination" => str(termStr)
                });
                Map.insert("stats", statsObj, baseMap)
            case None => baseMap
        };
        let obj = JObject(finalMap);
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
