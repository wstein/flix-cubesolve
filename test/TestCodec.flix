mod TestCodec {

    use CubeSolve.Table
    use CubeSolve.Table.Codec

    def header(): Codec.Header =
        Codec.header({
            table = "pocket.distances",
            convention = "kociemba-htm@1",
            generator = "cubesolve 0.4.3"
        })

    def sample(bits: Int32, count: Int32): Table.TableView \ Assert =
        // Values must fit the width. Capping at `widest` rather than
        // `widest + 1` also avoids the overflow that 32-bit entries would
        // otherwise cause, since widest(32) is Int32's maximum.
        let modulus = Int32.max(1, Int32.min(count, Table.widest(bits)));
        match Table.ofValues(bits, Vector.init(i -> Int32.modulo(i, modulus), count)) {
            case Ok(t)  => t
            case Err(e) =>
                Assert.assertEqWithMsg(expected = "", e, "expected a table");
                unreachable!()
        }

    def encoded(bits: Int32, count: Int32): Vector[Int8] \ Assert =
        match Codec.encode(header(), sample(bits, count)) {
            case Ok(bytes) => bytes
            case Err(e)    =>
                Assert.assertEqWithMsg(expected = "", e, "expected bytes");
                unreachable!()
        }

    /// `bytes` with entry `at` changed, so the payload is corrupt but the
    /// length is not.
    def corrupt(at: Int32, bytes: Vector[Int8]): Vector[Int8] =
        Vector.init(i ->
            if (i == at) Vector.get(i, bytes) + 1i8 else Vector.get(i, bytes),
            Vector.length(bytes))

    // ---------- round trip ----------

    /// Every width survives a round trip, entry for entry, with its shape and
    /// its header intact.
    @Test
    def everyWidthRoundTripsThroughTheCodec(): Unit \ Assert =
        List.forEach(bits -> {
            let original = sample(bits, 300);
            match Codec.encode(header(), original) |> Result.flatMap(Codec.decode) {
                case Err(e) => Assert.assertEqWithMsg(expected = "", e, "${bits} bits")
                case Ok((h, back)) =>
                    Assert.assertEqWithMsg(
                        expected = header(), h, "the header at ${bits} bits");
                    Assert.assertEqWithMsg(
                        expected = Table.bitsPerEntry(original), Table.bitsPerEntry(back),
                        "the width at ${bits} bits");
                    Assert.assertEqWithMsg(
                        expected = Table.entries(original), Table.entries(back),
                        "the entry count at ${bits} bits");
                    Vector.range(0, Table.entries(original)) |> Vector.forEach(i ->
                        Assert.assertEqWithMsg(
                            expected = Table.get(i, original), Table.get(i, back),
                            "entry ${i} at ${bits} bits"))
            }
        }, 2 :: 4 :: 8 :: 16 :: 32 :: Nil)

    /// Encoding is deterministic, so a cache written twice from the same table
    /// is byte-identical and a digest over it means something.
    @Test
    def encodingIsByteIdentical(): Unit \ Assert =
        List.forEach(bits ->
            Assert.assertEqWithMsg(
                expected = encoded(bits, 257), encoded(bits, 257),
                "encoding at ${bits} bits should be deterministic"),
            2 :: 4 :: 8 :: 16 :: 32 :: Nil)

    @Test
    def anEmptyTableRoundTrips(): Unit \ Assert =
        match Codec.encode(header(), sample(8, 0)) |> Result.flatMap(Codec.decode) {
            case Err(e)        => Assert.assertEqWithMsg(expected = "", e, "empty table")
            case Ok((_, back)) => Assert.assertEq(expected = 0, Table.entries(back))
        }

    // ---------- the failure surface ----------

    /// Truncation is caught. A cache half-written by a process that died is the
    /// ordinary way this happens, and reading it as a short table would give
    /// wrong answers rather than an error.
    @Test
    def truncationIsDetected(): Unit \ Assert =
        let bytes = encoded(8, 200);
        List.forEach(keep ->
            Assert.assertTrueWithMsg(
                Result.isErr(Codec.decode(Vector.take(keep, bytes))),
                "a file truncated to ${keep} bytes should be refused"),
            0 :: 1 :: 8 :: 20 :: 100 :: (Vector.length(bytes) - 1) :: Nil)

    /// Corruption anywhere is caught by the checksum, including in the payload,
    /// where nothing else would notice.
    @Test
    def corruptionIsDetected(): Unit \ Assert =
        let bytes = encoded(8, 200);
        let last = Vector.length(bytes) - 1;
        List.forEach(at ->
            Assert.assertTrueWithMsg(
                Result.isErr(Codec.decode(corrupt(at, bytes))),
                "a byte changed at ${at} should be refused"),
            10 :: 40 :: 100 :: (last - 20) :: last :: Nil)

    /// Trailing bytes are refused rather than ignored. A file that grew is a
    /// file something else has been writing to.
    @Test
    def trailingBytesAreRefused(): Unit \ Assert =
        let bytes = encoded(4, 100);
        Assert.assertErr(Codec.decode(Vector.append(bytes, Vector#{0i8})));
        Assert.assertErr(Codec.decode(Vector.append(bytes, bytes)))

    /// Something that is not one of these files at all is refused by its magic,
    /// before anything is read from it.
    @Test
    def foreignDataIsRefusedByItsMagic(): Unit \ Assert =
        match Codec.decode(Vector.repeat(200, 7i8)) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "that is not a table file")
            case Err(e) => Assert.assertTrue(String.contains(substr = "not a", e))
        }

    /// A file from a future schema is refused by name rather than misread.
    @Test
    def anUnknownSchemaVersionIsRefusedByName(): Unit \ Assert =
        let bytes = encoded(8, 50);
        let bumped = Codec.withSchemaForTesting(Codec.schema() + 1, bytes);
        match Codec.decode(bumped) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "a future schema is unreadable")
            case Err(e) => Assert.assertTrue(String.contains(substr = "schema", e))
        }

    // ---------- what the header is for ----------

    /// A cache written under a different convention is refused, which is the
    /// whole reason the convention is in the header.
    ///
    /// Relabelling slots by any bijection preserves every invariant and changes
    /// only the encoding, so a table whose convention is not recorded pins
    /// nothing -- and one whose convention disagrees is not merely stale, it is
    /// a table of a different puzzle.
    @Test
    def aTableFromAnotherConventionIsRefused(): Unit \ Assert =
        let other = Codec.header({
            table = "pocket.distances",
            convention = "some-other-numbering@1",
            generator = "cubesolve 0.4.3"
        });
        let read = b -> Codec.expect(header(), b);
        match Codec.encode(other, sample(8, 50)) |> Result.flatMap(read) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "the convention differs")
            case Err(e) => Assert.assertTrue(String.contains(substr = "convention", e))
        }

    /// And a cache of a different table is refused too, so a mixed-up filename
    /// cannot feed one search another's tables.
    @Test
    def aCacheOfADifferentTableIsRefused(): Unit \ Assert =
        let other = Codec.header({
            table = "standard.flipTwist",
            convention = "kociemba-htm@1",
            generator = "cubesolve 0.4.3"
        });
        let read = b -> Codec.expect(header(), b);
        match Codec.encode(other, sample(8, 50)) |> Result.flatMap(read) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "the table differs")
            case Err(e) => Assert.assertTrue(String.contains(substr = "standard.flipTwist", e))
        }

    /// A cache written by another build is refused.
    ///
    /// What a table contains is decided by the code that built it, and the
    /// convention string does not capture that: change a pruning pairing, a
    /// move order, or fix a bug in a sweep, and the convention is untouched
    /// while every entry differs. Treating the generator as provenance only --
    /// which an earlier version of this codec did -- means such a table is
    /// served from cache without complaint.
    @Test
    def aCacheFromAnotherBuildIsRefused(): Unit \ Assert =
        let older = Codec.header({
            table = "pocket.distances",
            convention = "kociemba-htm@1",
            generator = "cubesolve 0.0.9"
        });
        let read = b -> Codec.expect(header(), b);
        match Codec.encode(older, sample(8, 50)) |> Result.flatMap(read) {
            case Ok(_)  => Assert.assertTrueWithMsg(false, "the build differs")
            case Err(e) =>
                Assert.assertTrue(String.contains(substr = "cubesolve 0.0.9", e));
                Assert.assertTrue(String.contains(substr = "code that built it", e))
        };
        // and the same build still round-trips
        Assert.assertOk(Codec.encode(header(), sample(8, 50)) |> Result.flatMap(read))

}
