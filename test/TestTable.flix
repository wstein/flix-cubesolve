mod TestTable {

    use CubeSolve.Table

    /// A table of `count` entries whose value at `i` is `i mod modulus`.
    def rising(bits: Int32, count: Int32, modulus: Int32): Table.TableView \ Assert =
        let values = Vector.init(i -> Int32.modulo(i, modulus), count);
        match Table.ofValues(bits, values) {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected a table");
                unreachable!()
        }

    // ---------- round trip at every width ----------

    /// Every entry written comes back, at every width. This is the property the
    /// packing exists to preserve and the one a shifted mask breaks silently.
    @Test
    def everyEntryRoundTripsAtEveryWidth(): Unit \ Assert =
        List.forEach(match (bits, modulus) -> {
            let count = 1000;
            let t = rising(bits, count, modulus);
            Vector.range(0, count) |> Vector.forEach(i ->
                Assert.assertEqWithMsg(
                    expected = Int32.modulo(i, modulus),
                    Table.get(i, t),
                    "entry ${i} at ${bits} bits"
                ))
        }, (8, 100) :: (4, 16) :: (2, 4) :: Nil)

    /// Move tables hold coordinates, not distances: a 2x2x2 permutation index
    /// reaches 5039 and a 3x3x3 edge permutation index reaches 40319. Those need
    /// whole-byte entries, and 40319 does not fit a *signed* 16-bit value, so
    /// the full unsigned range has to work.
    @Test
    def wideEntriesHoldWholeCoordinates(): Unit \ Assert =
        let wide = Vector#{0, 1, 5039, 32767, 32768, 40319, 65535};
        match Table.ofValues(16, wide) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a table")
            case Ok(t)  =>
                Assert.assertEq(expected = 14, Table.byteLength(t));
                Vector.range(0, Vector.length(wide)) |> Vector.forEach(i ->
                    Assert.assertEq(expected = Vector.get(i, wide), Table.get(i, t)))
        }

    @Test
    def thirtyTwoBitEntriesHoldAnyNonNegativeInt32(): Unit \ Assert =
        let wide = Vector#{0, 1, 3674159, 2147483647};
        match Table.ofValues(32, wide) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a table")
            case Ok(t)  =>
                Assert.assertEq(expected = 16, Table.byteLength(t));
                Vector.range(0, Vector.length(wide)) |> Vector.forEach(i ->
                    Assert.assertEq(expected = Vector.get(i, wide), Table.get(i, t)))
        }

    @Test
    def aValueTooWideForSixteenBitsIsRefused(): Unit \ Assert =
        Assert.assertErr(Table.ofValues(16, Vector#{65536}));
        Assert.assertErr(Table.ofValues(16, Vector#{-1}))

    /// Entries that share a byte must not bleed into each other. A table of
    /// alternating extremes is where an off-by-one shift shows up.
    @Test
    def neighbouringEntriesDoNotBleed(): Unit \ Assert =
        List.forEach(match (bits, high) -> {
            let values = Vector.init(i -> if (Int32.modulo(i, 2) == 0) 0 else high, 64);
            match Table.ofValues(bits, values) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a table")
                case Ok(t)  =>
                    Vector.range(0, 64) |> Vector.forEach(i ->
                        Assert.assertEq(
                            expected = if (Int32.modulo(i, 2) == 0) 0 else high,
                            Table.get(i, t)
                        ))
            }
        }, (8, 127) :: (4, 15) :: (2, 3) :: Nil)

    // ---------- size ----------

    /// The point of packing: four entries to the byte at two bits, two at four.
    @Test
    def packingActuallyShrinksThePayload(): Unit \ Assert =
        Assert.assertEq(expected = 1000, Table.byteLength(rising(8, 1000, 100)));
        Assert.assertEq(expected = 500, Table.byteLength(rising(4, 1000, 16)));
        Assert.assertEq(expected = 250, Table.byteLength(rising(2, 1000, 4)))

    /// A partly filled last byte is still a whole byte.
    @Test
    def aPartialFinalByteIsRoundedUp(): Unit \ Assert =
        Assert.assertEq(expected = 1, Table.byteLength(rising(4, 1, 2)));
        Assert.assertEq(expected = 1, Table.byteLength(rising(2, 3, 2)));
        Assert.assertEq(expected = 2, Table.byteLength(rising(2, 5, 2)))

    @Test
    def aTableReportsItsShape(): Unit \ Assert =
        let t = rising(4, 300, 16);
        Assert.assertEq(expected = 300, Table.entries(t));
        Assert.assertEq(expected = 4, Table.bitsPerEntry(t))

    // ---------- refusals ----------

    /// A value too wide for the width would be silently truncated, so it is
    /// refused instead. Truncation is how a pruning table starts lying.
    @Test
    def aValueTooWideForItsWidthIsRefused(): Unit \ Assert =
        Assert.assertErr(Table.ofValues(2, Vector#{0, 1, 4}));
        Assert.assertErr(Table.ofValues(4, Vector#{0, 16}));
        Assert.assertErr(Table.ofValues(8, Vector#{256}));
        Assert.assertErr(Table.ofValues(4, Vector#{-1}))

    /// A byte holds 0 to 255 even though Flix's byte type is signed and has no
    /// unsigned counterpart. The sign is an artefact of the storage and never
    /// reaches a caller: values above 127 are stored negative and masked back.
    @Test
    def aByteWideEntryHoldsTheWholeUnsignedRange(): Unit \ Assert =
        let values = Vector#{0, 1, 127, 128, 200, 255};
        match Table.ofValues(8, values) {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a table")
            case Ok(t)  =>
                Vector.range(0, Vector.length(values)) |> Vector.forEach(i ->
                    Assert.assertEq(expected = Vector.get(i, values), Table.get(i, t)))
        }

    @Test
    def anUnsupportedWidthIsRefused(): Unit \ Assert =
        Assert.assertErr(Table.ofValues(3, Vector#{0, 1}));
        Assert.assertErr(Table.ofValues(12, Vector#{0, 1}));
        Assert.assertErr(Table.ofValues(64, Vector#{0, 1}));
        Assert.assertErr(Table.ofValues(0, Vector#{0}))

    /// Reading past the end is a programming error, and the table says so
    /// rather than returning a plausible byte from somewhere else.
    @Test
    def readingOutOfRangeIsRefused(): Unit \ Assert =
        let t = rising(4, 10, 16);
        Assert.assertErr(Table.tryGet(10, t));
        Assert.assertErr(Table.tryGet(-1, t));
        Assert.assertOk(Table.tryGet(9, t))

    // ---------- the flat index ----------

    /// Search reads tables as `table[coord * nMoves + move]`, and that product
    /// is where a large table overflows Int32 without any sign of it.
    @Test
    def theFlatIndexComputesTheProduct(): Unit \ Assert =
        Assert.assertEq(expected = Ok(0), Table.flatIndex(0, 18, 0));
        Assert.assertEq(expected = Ok(17), Table.flatIndex(0, 18, 17));
        Assert.assertEq(expected = Ok(18), Table.flatIndex(1, 18, 0));
        Assert.assertEq(expected = Ok(3674159 * 9 + 8), Table.flatIndex(3674159, 9, 8))

    /// JVM arrays are int-indexed, so 2^31 - 1 elements is a hard cap. A
    /// product that passes it is caught in Int64 before it is narrowed.
    @Test
    def theFlatIndexRefusesAProductThatWouldOverflow(): Unit \ Assert =
        Assert.assertErr(Table.flatIndex(2000000000, 2, 0));
        Assert.assertErr(Table.flatIndex(1073741824, 2, 1));
        Assert.assertOk(Table.flatIndex(238609294, 9, 0))

    @Test
    def theFlatIndexRefusesNegativeParts(): Unit \ Assert =
        Assert.assertErr(Table.flatIndex(-1, 9, 0));
        Assert.assertErr(Table.flatIndex(0, 9, -1));
        Assert.assertErr(Table.flatIndex(0, -9, 0))

    // ---------- the region path ----------

    /// Large tables are built by mutation inside a region and frozen at the
    /// end. The two construction paths must agree entry for entry.
    @Test
    def theRegionBuiltTableMatchesTheDirectOne(): Unit \ Assert =
        let count = 500;
        let expected = rising(4, count, 16);
        let built = region rc {
            let payload = Table.emptyPayload(rc, 4, count);
            Vector.range(0, count) |> Vector.forEach(i ->
                Table.putEntry(payload, 4, i, Int32.modulo(i, 16)));
            Table.ofPayload(4, count, payload)
        };
        match built {
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "expected a table")
            case Ok(t)  =>
                Assert.assertEq(expected = Table.byteLength(expected), Table.byteLength(t));
                Vector.range(0, count) |> Vector.forEach(i ->
                    Assert.assertEq(expected = Table.get(i, expected), Table.get(i, t)))
        }

}
