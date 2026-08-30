///
/// Choosing among the algorithms published for one case.
///
/// Most cases have several, and the source says plainly that a longer algorithm
/// can be quicker for a given person. Which is best therefore depends on whose
/// hands are on the cube, what they have learned and how they grip it, and none
/// of that is a fact this library can hold. What it can do is offer stated rules
/// and say which one it applied.
///
/// **The metric is fewest parsed layer turns**, and it is called that rather
/// than "fastest" or even "HTM". Whole-cube rotations are deliberately excluded
/// from the count -- they move no piece relative to any other -- so the number
/// is not the half-turn metric, and it is not a claim about how long anybody
/// takes to execute the sequence.
///
mod CubeSolve.Method.Profile {

    use CubeSolve.Method.Profile.Profile.{SourceFirst, Shortest, NoRotations}
    use CubeSolve.Method.Profile.Status.{Chosen, FellBack}
    use CubeSolve.Model.Notation
    use CubeSolve.Model.Notation.Op.{Layer, Inner, Frame}

    ///
    /// A rule for picking an algorithm.
    ///
    pub enum Profile with Eq, ToString {
        /// The first the source lists, in the order it lists them.
        case SourceFirst
        /// Fewest parsed layer turns; ties go to the earlier in source order.
        case Shortest
        /// The first with no whole-cube rotation in it, so it chains without
        /// regripping. Not every case has one.
        case NoRotations
    }

    ///
    /// Whether the profile got what it asked for.
    ///
    pub enum Status with Eq, ToString {
        /// The rule applied and picked this.
        case Chosen
        /// The rule had nothing to pick, so the first recorded one was used.
        case FellBack
    }

    ///
    /// What a profile picked, and whether it got what it asked for.
    ///
    pub type alias Choice = {
        algorithm = String,
        layerTurns = Int32,
        status = Status,
        note = String
    }

    ///
    /// The profile a name asks for, if it names one.
    ///
    pub def ofName(s: String): Option[Profile] = match String.toLowerCase(s) {
        case "default"      => Some(SourceFirst)
        case "shortest"     => Some(Shortest)
        case "no-rotations" => Some(NoRotations)
        case _              => None
    }

    ///
    /// What a profile is called.
    ///
    pub def nameOf(p: Profile): String = match p {
        case SourceFirst => "default"
        case Shortest    => "shortest"
        case NoRotations => "no-rotations"
    }

    ///
    /// Every profile there is, for a caller listing them.
    ///
    pub def all(): Vector[Profile] = Vector#{SourceFirst, Shortest, NoRotations}

    ///
    /// Apply `p` to `variants`, which are in source order and never empty.
    ///
    /// A fallback is reported rather than hidden. A caller who asked for
    /// rotation-free moves and silently got something else would have no way to
    /// tell, and would reasonably believe every case in a session was covered.
    ///
    pub def pick(p: Profile, variants: Vector[String]): Choice =
        let first = Vector.get(0, variants);
        match p {
            case SourceFirst => picked(first, "the first the source lists")
            case Shortest    => picked(shortestOf(variants),
                "fewest parsed layer turns, rotations not counted")
            case NoRotations => match rotationFree(variants) {
                case Some(a) => picked(a, "the first recorded variant with no rotation")
                case None    => {
                    algorithm = first,
                    layerTurns = layerTurns(first),
                    status = FellBack,
                    note = "no rotation-free variant is recorded for this case, so "
                        + "the first the source lists was used"
                }
            }
        }

    ///
    /// A choice the rule made, as opposed to one it fell back to.
    ///
    def picked(algorithm: String, note: String): Choice =
        { algorithm = algorithm, layerTurns = layerTurns(algorithm),
          status = Chosen, note = note }

    ///
    /// The variant with fewest layer turns, earliest winning a tie.
    ///
    def shortestOf(variants: Vector[String]): String =
        variants |> Vector.foldLeft((best, v) ->
            if (layerTurns(v) < layerTurns(best)) v else best, Vector.get(0, variants))

    ///
    /// The first variant containing no whole-cube rotation.
    ///
    def rotationFree(variants: Vector[String]): Option[String] =
        variants |> Vector.findLeft(v -> not turnsTheCube(v))

    ///
    /// Whether `alg` rotates the whole cube at any point.
    ///
    /// Read from the parsed sequence rather than by looking for `x`, `y` or `z`
    /// in the text: a wide turn is a rotation too, and `r U R'` would pass a
    /// search for those letters while regripping just as much.
    ///
    pub def turnsTheCube(alg: String): Bool =
        Notation.parse(3, alg)
            |> Result.map(ops -> ops |> List.exists(op -> match op {
                case Frame(_) => true
                case Inner(_, _) => false
                case Layer(_) => false
            }))
            |> Result.getWithDefault(true)

    ///
    /// How many layer turns `alg` makes.
    ///
    /// Rotations are not counted: they move no piece relative to any other. An
    /// algorithm that fails to parse counts as very long, so it can never win a
    /// comparison -- though nothing unparseable is recorded.
    ///
    pub def layerTurns(alg: String): Int32 =
        Notation.parse(3, alg)
            |> Result.map(ops -> List.length(Notation.layersOnly(ops)))
            |> Result.getWithDefault(9999)

}
