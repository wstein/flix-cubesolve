///
/// What a person looking at the cube can see, read from decoded model state.
///
/// The beginner method is a sequence of observations: which corner is next,
/// whether an edge goes in on the left or the right, whether a middle slot has
/// to be emptied first, what shape the last layer's top face makes. Every one
/// of those is a question about where pieces are and how they sit, and this is
/// the one place that answers them.
///
/// **One decoder, and this is it.** The stage predicates, the rules that pick
/// the next action, and the tests all ask here rather than reading permutation
/// vectors of their own. Two readings of the same convention would be free to
/// drift, and a method that disagreed with its own tests about which slot `DFR`
/// is would be very hard to see.
///
/// Slots are the conventions in `docs/conventions.md` and nothing here restates
/// them: corners `0..3` are the top layer and `4..7` the bottom, edges `0..3`
/// the top, `4..7` the bottom, `8..11` the middle.
///
mod CubeSolve.Method.Facts {

    use CubeSolve.Model.Cube
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// A piece, where it sits and how it is turned there.
    ///
    /// `piece` is the slot the piece belongs in, so `piece == slot` means it is
    /// home. `turn` is the twist for a corner and the flip for an edge.
    ///
    pub type alias Placed = { piece = Int32, slot = Int32, turn = Int32 }

    ///
    /// The last layer's top face, as the four shapes a beginner is taught.
    ///
    /// The names are the ones every guide uses, and they are exhaustive: with
    /// the corners ignored, an oriented-edge count is 0, 2 or 4, and the two
    /// ways of having two are adjacent or opposite.
    ///
    pub enum TopShape with Eq, ToString {
        /// No top edge oriented.
        case Dot
        /// Two adjacent top edges oriented.
        case Corner
        /// Two opposite top edges oriented.
        case Line
        /// All four oriented.
        case Cross
    }

    ///
    /// Every edge, by the slot it is sitting in.
    ///
    pub def edges(c: Cube.Cube): Result[String, Vector[Placed]] =
        orbitsOf(c) |> Result.map(match (_, _, ep, eo) ->
            Vector.range(0, 12) |> Vector.map(s ->
                { piece = Vector.get(s, ep), slot = s, turn = Vector.get(s, eo) }))

    ///
    /// Every corner, by the slot it is sitting in.
    ///
    pub def corners(c: Cube.Cube): Result[String, Vector[Placed]] =
        orbitsOf(c) |> Result.map(match (cp, co, _, _) ->
            Vector.range(0, 8) |> Vector.map(s ->
                { piece = Vector.get(s, cp), slot = s, turn = Vector.get(s, co) }))

    ///
    /// The slot `piece` is sitting in, and how it is turned there.
    ///
    /// This is the question a person actually asks -- "where is the white-red
    /// edge?" -- and it is the inverse of the permutation, which is slot-indexed.
    ///
    pub def findEdge(c: Cube.Cube, piece: Int32): Result[String, Placed] =
        edges(c) |> Result.flatMap(located(piece, "edge"))

    ///
    /// The slot `piece` is sitting in, and how it is twisted there.
    ///
    pub def findCorner(c: Cube.Cube, piece: Int32): Result[String, Placed] =
        corners(c) |> Result.flatMap(located(piece, "corner"))

    ///
    /// Whether the piece belonging in `slot` is there and the right way round.
    ///
    pub def edgeHome(c: Cube.Cube, slot: Int32): Result[String, Bool] =
        edges(c) |> Result.map(es -> atHome(Vector.get(slot, es)))

    ///
    /// Whether the corner belonging in `slot` is there and untwisted.
    ///
    pub def cornerHome(c: Cube.Cube, slot: Int32): Result[String, Bool] =
        corners(c) |> Result.map(cs -> atHome(Vector.get(slot, cs)))

    ///
    /// The bottom edges: the cross.
    ///
    pub def crossSlots(): Vector[Int32] = Vector#{4, 5, 6, 7}

    ///
    /// The bottom corners: the rest of the first layer.
    ///
    pub def bottomCornerSlots(): Vector[Int32] = Vector#{4, 5, 6, 7}

    ///
    /// The middle edges: the second layer.
    ///
    pub def middleSlots(): Vector[Int32] = Vector#{8, 9, 10, 11}

    ///
    /// The top edges.
    ///
    pub def topEdgeSlots(): Vector[Int32] = Vector#{0, 1, 2, 3}

    ///
    /// The top corners.
    ///
    pub def topCornerSlots(): Vector[Int32] = Vector#{0, 1, 2, 3}

    ///
    /// The shape the top face shows, ignoring the corners.
    ///
    /// The four shapes a beginner is taught, and they are exhaustive: edge
    /// flips sum to zero, so the number of oriented top edges is 0, 2 or 4, and
    /// two can be adjacent or opposite.
    ///
    pub def topShape(c: Cube.Cube): Result[String, TopShape] =
        edges(c) |> Result.map(es -> {
            let up = topEdgeSlots() |> Vector.filter(s -> Vector.get(s, es)#turn == 0);
            match Vector.length(up) {
                case 0 => TopShape.Dot
                case 4 => TopShape.Cross
                case _ =>
                    // UR and UL are opposite, as are UF and UB.
                    let a = Vector.get(0, up);
                    let b = Vector.get(1, up);
                    if (Int32.abs(a - b) == 2) TopShape.Line else TopShape.Corner
            }
        })

    ///
    /// Whether every slot in `slots` holds its own piece the right way round.
    ///
    pub def allHome(c: Cube.Cube, slots: Vector[Int32], corner: Bool): Result[String, Bool] =
        (if (corner) corners(c) else edges(c))
            |> Result.map(ps -> slots |> Vector.forAll(s -> atHome(Vector.get(s, ps))))

    ///
    /// A piece is home when it is in its own slot and not turned.
    ///
    def atHome(p: Placed): Bool = p#piece == p#slot and p#turn == 0

    ///
    /// Where `piece` is, or why it could not be found.
    ///
    def located(piece: Int32, what: String): Vector[Placed] -> Result[String, Placed] =
        ps -> match Vector.findLeft(p -> p#piece == piece, ps) {
            case Some(p) => Ok(p)
            case None    =>
                Err("no ${what} numbered ${piece} is on this cube, which means "
                    + "the state is not a cube at all")
        }

    ///
    /// The four vectors, or why this cube has none.
    ///
    def orbitsOf(
        c: Cube.Cube
    ): Result[String, (Vector[Int32], Vector[Int32], Vector[Int32], Vector[Int32])] =
        if (Cube.size(c) != 3)
            Err("these are the facts of a 3x3x3, and this is a "
                + "${Cube.size(c)}x${Cube.size(c)}x${Cube.size(c)}")
        else
            match Cube.orbits(c) {
                case CornerCoord(cp, co) :: MidgeCoord(ep, eo) :: Nil => Ok((cp, co, ep, eo))
                case _ => Err("this cube does not have the orbits a 3x3x3 has")
            }
}
