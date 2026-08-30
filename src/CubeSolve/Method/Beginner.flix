///
/// The layer-by-layer method, as a ladder of states.
///
/// The stages are the ones every beginner guide teaches, in the order they are
/// always taught. **They are specified here from decoded model state rather than
/// transcribed from any guide**: each is a statement about which pieces sit in
/// which slots and which way round, and a cube either satisfies it or does not.
///
/// The layer-by-layer structure was consulted from published teaching material,
/// <https://cubesolve.com/>, as pedagogy. Nothing is copied from it: that site
/// reserves all rights, so no move sequence of its appears here, and the
/// predicates below were written from the cube rather than from the page.
///
/// **The ladder is monotone.** Each stage includes the one before it, so a cube
/// that has reached a stage has reached every earlier one. That is what lets
/// progress be reported as a single answer and what a method's steps are checked
/// against: a step that claims to finish a stage must leave the cube at that
/// stage or further, and never earlier.
///
mod CubeSolve.Method.Beginner {

    use CubeSolve.Method.Beginner.Stage.{Nothing, Cross, FirstLayer, TwoLayers,
        TopCross, TopEdgesPlaced, TopCornersPlaced, Solved}
    use CubeSolve.Method.LastLayer
    use CubeSolve.Model.Cube
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// How far up the ladder a cube has got.
    ///
    /// The cross is on `D`, as everywhere else here, so "first layer" is the
    /// bottom one and "top" is the last layer.
    ///
    pub enum Stage with Eq, Order, ToString {
        /// Not even the cross.
        case Nothing
        /// The four `D` edges home and the right way up.
        case Cross
        /// Those, and the four `D` corners.
        case FirstLayer
        /// Those, and the four middle edges: everything below the top.
        case TwoLayers
        /// Those, and every top edge showing the top colour.
        case TopCross
        /// Those, and every top edge in its own slot.
        case TopEdgesPlaced
        /// Those, and every top corner in its own slot, however turned.
        case TopCornersPlaced
        /// Every piece home and the right way round.
        case Solved
    }

    ///
    /// The stages in order, which is the order they are worked through.
    ///
    pub def ladder(): List[Stage] =
        Cross :: FirstLayer :: TwoLayers :: TopCross :: TopEdgesPlaced
            :: TopCornersPlaced :: Solved :: Nil

    ///
    /// The furthest stage `c` satisfies.
    ///
    /// Read upward and stops at the first stage the cube fails, which is sound
    /// because the ladder is monotone -- a test asserts that rather than leaving
    /// it as a claim.
    ///
    pub def reached(c: Cube.Cube): Stage =
        ladder() |> List.foldLeft((best, s) -> if (isComplete(s, c)) s else best, Nothing)

    ///
    /// Whether `c` has finished stage `s`.
    ///
    pub def isComplete(s: Stage, c: Cube.Cube): Bool =
        if (Cube.size(c) != 3)
            false
        else
            match Cube.orbits(c) {
                case CornerCoord(cp, co) :: MidgeCoord(ep, eo) :: Nil =>
                    holds(s, { corners = (cp, co), edges = (ep, eo) }, c)
                case _ => false
            }

    ///
    /// The four vectors a 3x3x3's orbits decode to, carried together.
    ///
    /// One argument rather than four, so that a stage test reads as a question
    /// about a cube instead of a list of coordinates.
    ///
    type alias Orbits = {
        corners = (Vector[Int32], Vector[Int32]),
        edges = (Vector[Int32], Vector[Int32])
    }

    def holds(s: Stage, o: Orbits, c: Cube.Cube): Bool = match s {
        case Nothing =>
            true
        case Cross =>
            crossDone(o)
        case FirstLayer =>
            crossDone(o) and cornersDown(o)
        case TwoLayers =>
            belowTheTopDone(c)
        case TopCross =>
            holds(TwoLayers, o, c) and LastLayer.topIsOriented(c)
        case TopEdgesPlaced =>
            holds(TopCross, o, c) and topEdgesHome(o)
        case TopCornersPlaced =>
            holds(TopEdgesPlaced, o, c) and topCornersHome(o)
        case Solved =>
            Cube.isSolved(c)
    }

    ///
    /// Everything below the top layer, in place.
    ///
    def belowTheTopDone(c: Cube.Cube): Bool =
        Option.isEmpty(LastLayer.faultBelowTheTop(c))

    ///
    /// The four bottom edges, home and the right way up.
    ///
    def crossDone(o: Orbits): Bool =
        let (ep, eo) = o#edges;
        settled(4, 8, ep, eo)

    ///
    /// The four bottom corners, home and the right way round.
    ///
    def cornersDown(o: Orbits): Bool =
        let (cp, co) = o#corners;
        settled(4, 8, cp, co)

    ///
    /// Every top edge above its own centres.
    ///
    def topEdgesHome(o: Orbits): Bool =
        let (ep, _) = o#edges;
        home(0, 4, ep)

    ///
    /// Every top corner in its own place, however turned.
    ///
    def topCornersHome(o: Orbits): Bool =
        let (cp, _) = o#corners;
        home(0, 4, cp)

    ///
    /// Whether every slot in the range holds its own piece the right way round.
    ///
    def settled(
        start: Int32,
        stop: Int32,
        perm: Vector[Int32],
        ori: Vector[Int32]
    ): Bool =
        Vector.range(start, stop) |> Vector.forAll(i ->
            Vector.get(i, perm) == i and Vector.get(i, ori) == 0)

    ///
    /// Whether every slot in the range holds its own piece, however turned.
    ///
    def home(start: Int32, stop: Int32, perm: Vector[Int32]): Bool =
        Vector.range(start, stop) |> Vector.forAll(i -> Vector.get(i, perm) == i)

    ///
    /// What is left to do at each stage, in words.
    ///
    /// Written here rather than taken from a guide, and used as the label a plan
    /// carries for that step.
    ///
    pub def describe(s: Stage): String = match s {
        case Nothing          => "nothing yet"
        case Cross            => "Cross: the four bottom edges, matching their centres"
        case FirstLayer       => "First layer: the four bottom corners"
        case TwoLayers        => "Middle edges: the four edges between the centres"
        case TopCross         => "Top cross: every top edge showing the top colour"
        case TopEdgesPlaced   => "Top edges: each top edge above its own centres"
        case TopCornersPlaced => "Top corners: each top corner in its own place"
        case Solved           => "Turn the last corners upright"
    }

}
