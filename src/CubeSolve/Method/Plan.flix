///
/// A solution written as labelled steps.
///
/// The form every method here answers in, and the one people write by hand:
///
/// ```
/// Scramble: R U R' U' F2 L D B'
///
/// y // Inspection
/// D' L' // Cross
/// U R' F' R2 F2 // First pair
/// // OLL skip
/// R U R' U' R' F R2 U' R' U' R U R' F' // PLL: T-PLL
/// ```
///
/// **`//` is what this writes; `//` and `#` are both accepted when reading**,
/// because `#` is what people type and `//` is what reads well next to move
/// notation.
///
/// **A rotation is a move, not a note.** `y` on the first line above is a
/// `Frame` operation and stays one: it changes how every later move name is
/// resolved, so demoting it to metadata would quietly change what the rest of
/// the plan does. That is the mistake this project has made twice -- in
/// `Cube.reframeSolution` and again in the last layer's finishing turn -- and
/// the reason the flattened `ops` are what a replay uses.
///
/// **`Scramble:` is context, not a step.** It says where the cube started; it is
/// shown above the plan and never joins the moves, because concatenating it
/// would return a "solution" that scrambles first.
///
/// `CubeSolve.Model.Notation` stays strict and flat and knows nothing about any
/// of this. It parses algorithms; this parses documents.
///
mod CubeSolve.Method.Plan {

    use CubeSolve.Model.Notation

    ///
    /// One line: what it does, and what it is for.
    ///
    /// `label` is empty when a line carries only moves, and `ops` is empty when
    /// it carries only a label -- a note about a step that needed no moves, such
    /// as a skip.
    ///
    pub type alias Step = {
        label = String,
        sequence = String,
        ops = List[Notation.Op]
    }

    ///
    /// A whole plan: where the cube started, and the steps that finish it.
    ///
    pub type alias Plan = {
        scramble = Option[String],
        steps = List[Step]
    }

    ///
    /// A plan of steps, with no scramble recorded.
    ///
    pub def of(steps: List[Step]): Plan = { scramble = None, steps = steps }

    ///
    /// `p` with `scramble` recorded as the context it started from.
    ///
    pub def startingFrom(p: Plan, scramble: String): Plan =
        { scramble = Some(scramble), steps = p#steps }

    ///
    /// One step, from moves and a label.
    ///
    pub def step(n: Int32, label: String, sequence: String): Result[String, Step] =
        if (String.isEmpty(String.trim(sequence)))
            Ok({ label = label, sequence = "", ops = Nil })
        else
            Notation.parse(n, sequence)
                |> Result.map(ops ->
                    { label = label, sequence = String.trim(sequence), ops = ops })

    ///
    /// Every operation the plan performs, in order.
    ///
    /// This is what a replay uses. The scramble is deliberately not in it.
    ///
    pub def ops(p: Plan): List[Notation.Op] =
        p#steps |> List.flatMap(s -> s#ops)

    ///
    /// The plan's moves run together, without labels.
    ///
    pub def sequenceOf(p: Plan): String =
        p#steps
            |> List.map(s -> s#sequence)
            |> List.filter(s -> not String.isEmpty(s))
            |> List.join(" ")

    ///
    /// How many layer turns the plan spends, rotations not counted.
    ///
    pub def layerTurns(p: Plan): Int32 =
        List.length(Notation.layersOnly(ops(p)))

    ///
    /// The plan as text, in the form this module reads back.
    ///
    pub def render(p: Plan): String =
        let lines = p#steps |> List.map(renderStep);
        match p#scramble {
            case None    => List.join(String.lineSeparator(), lines)
            case Some(s) =>
                List.join(String.lineSeparator(),
                    List.append("Scramble: ${s}" :: "" :: Nil, lines))
        }

    ///
    /// One step as a line.
    ///
    def renderStep(s: Step): String =
        if (String.isEmpty(s#label))
            s#sequence
        else if (String.isEmpty(s#sequence))
            "// ${s#label}"
        else
            "${s#sequence} // ${s#label}"

    ///
    /// The plan `text` describes for an `n x n x n`, or why it describes none.
    ///
    pub def parse(n: Int32, text: String): Result[String, Plan] =
        let lines = String.splitOn(substr = String.lineSeparator(), text);
        lines
            |> List.foldLeft((acc, line) -> Result.flatMap(sofar -> take(n, sofar, line), acc),
                Ok(of(Nil)))
            |> Result.map(done -> { scramble = done#scramble,
                steps = List.reverse(done#steps) })

    ///
    /// One line folded into the plan so far.
    ///
    /// Steps accumulate reversed and are turned back at the end, so that a long
    /// plan does not walk its own list once per line.
    ///
    def take(n: Int32, sofar: Plan, line: String): Result[String, Plan] =
        let (moves, label) = split(line);
        if (String.isEmpty(moves) and String.isEmpty(label))
            Ok(sofar)
        else
            match scrambleOf(moves, label) {
                case Some(s) => Ok({ scramble = Some(s), steps = sofar#steps })
                case None    =>
                    step(n, label, moves)
                        |> Result.map(st -> { scramble = sofar#scramble,
                            steps = st :: sofar#steps })
            }

    ///
    /// The scramble a line records, if it records one.
    ///
    /// Recognised on the moves rather than the label, because `Scramble:` names
    /// what the moves are for and is not a comment about them.
    ///
    def scrambleOf(moves: String, label: String): Option[String] =
        let _ = label;
        if (String.startsWith(prefix = "Scramble:", moves))
            Some(String.trim(String.dropLeft(String.length("Scramble:"), moves)))
        else
            None

    ///
    /// A line split into its moves and its label.
    ///
    /// `//` and `#` both end the moves. Neither appears in move notation, so
    /// there is nothing to escape and no ambiguity to resolve.
    ///
    def split(line: String): (String, String) =
        let atMarker = marker -> {
            let parts = String.splitOn(substr = marker, line);
            match parts {
                case before :: rest =>
                    Some((String.trim(before), String.trim(List.join(marker, rest))))
                case Nil => None
            }
        };
        if (String.contains(substr = "//", line))
            atMarker("//") |> Option.getWithDefault((String.trim(line), ""))
        else if (String.contains(substr = "#", line))
            atMarker("#") |> Option.getWithDefault((String.trim(line), ""))
        else
            (String.trim(line), "")

}
