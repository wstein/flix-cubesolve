///
/// Serialising a table, so that it need not be rebuilt.
///
/// Building the tables is the engine's one expensive step -- the 3x3x3's phase
/// tables are several breadth-first sweeps over millions of states. They are
/// pure and deterministic, so they can be written once and read back, and this
/// is the format they are written in.
///
/// **The header is not decoration.** A cube table stores ordinals and no
/// geometry: relabelling slots by any bijection preserves every invariant and
/// changes only the encoding. A table whose convention is not recorded pins
/// nothing, and one whose convention disagrees with the reader's is not stale
/// -- it is a table of a different puzzle, and it would be read without
/// complaint. So the convention is carried, and checked.
///
/// **The checksum is for corruption, not for tampering.** It is FNV-1a, which
/// catches a truncated write, a flipped bit and a file something else has been
/// writing to. It is not cryptographic and is not a security control; a
/// provenance digest in the sense of Stage 13 would need a real hash, and in
/// Flix that means Java interop and an `IO` effect on what is otherwise pure
/// code. That trade is deliberate and is recorded here rather than assumed.
///
/// Everything is little-endian, stated rather than inherited: a table written
/// on one machine and read on another must agree, and "whatever the platform
/// does" is not an agreement.
///
mod CubeSolve.Table.Codec {

    use CubeSolve.Table
    use CubeSolve.Table.TableView
    use CubeSolve.Table.Codec.Header.Header

    ///
    /// What a table file says about itself.
    ///
    /// `table` names which table it is, `convention` which slot and move
    /// numbering it was built under, and `generator` which build wrote it.
    /// The first two are checked; the third is provenance.
    ///
    pub enum Header with Eq, ToString {
        case Header(String, String, String)
    }

    ///
    /// A header.
    ///
    pub def header(fields: { table = String, convention = String, generator = String }): Header =
        Header(fields#table, fields#convention, fields#generator)

    ///
    /// Which table this is.
    ///
    pub def tableOf(h: Header): String = let Header(t, _, _) = h; t

    ///
    /// The slot and move numbering it was built under.
    ///
    pub def conventionOf(h: Header): String = let Header(_, c, _) = h; c

    ///
    /// Which build wrote it.
    ///
    pub def generatorOf(h: Header): String = let Header(_, _, g) = h; g

    ///
    /// The format version this build reads and writes.
    ///
    /// Bump it whenever the layout below changes in a way that would make an
    /// older file misread rather than merely stale.
    ///
    pub def schema(): Int32 = 1

    ///
    /// The eight bytes every table file starts with.
    ///
    def magic(): Vector[Int32] = Vector#{67, 85, 66, 69, 83, 76, 86, 84}

    // ---------- encoding ----------

    ///
    /// `t` and its header, as bytes.
    ///
    pub def encode(h: Header, t: TableView): Result[String, Vector[Int8]] =
        forM (
            table <- ascii("the table name", tableOf(h));
            convention <- ascii("the convention", conventionOf(h));
            generator <- ascii("the generator", generatorOf(h))
        ) yield assemble(t, table, convention, generator)

    ///
    /// Lay the parts out and seal them with a checksum.
    ///
    def assemble(
        t: TableView,
        table: Vector[Int32],
        convention: Vector[Int32],
        generator: Vector[Int32]
    ): Vector[Int8] =
        let body = Vector.flatten(Vector#{
            magic(),
            int32Bytes(schema()),
            text(table),
            text(convention),
            text(generator),
            int32Bytes(Table.entries(t)),
            int32Bytes(Table.bitsPerEntry(t)),
            int32Bytes(Table.byteLength(t)),
            payloadBytes(t)
        });
        Vector.append(body, int64Bytes(checksum(body))) |> Vector.map(toByte)

    ///
    /// A string as a length and then its characters.
    ///
    def text(s: Vector[Int32]): Vector[Int32] =
        Vector.append(int32Bytes(Vector.length(s)), s)

    ///
    /// `s` as bytes, or why it cannot be written.
    ///
    /// Identifiers are ASCII. That is a real restriction and it is checked
    /// rather than assumed, because a name that encoded differently on two
    /// machines would defeat the point of recording it.
    ///
    def ascii(what: String, s: String): Result[String, Vector[Int32]] =
        let codes = String.toList(s) |> List.map(Char.toBmpCodePoint) |> List.toVector;
        if (Vector.forAll(c -> c >= 32 and c < 127, codes))
            Ok(codes)
        else
            Err("${what} must be printable ASCII, but '${s}' is not: a name that "
                + "encoded differently on two machines would defeat the point of "
                + "recording it")

    ///
    /// The table's payload, byte by byte.
    ///
    def payloadBytes(t: TableView): Vector[Int32] =
        Vector.init(i -> rawByte(i, t), Table.byteLength(t))

    ///
    /// Byte `i` of `t`'s payload, as `0` to `255`.
    ///
    def rawByte(i: Int32, t: TableView): Int32 =
        let perByte = 8 / Int32.max(1, Int32.min(8, Table.bitsPerEntry(t)));
        if (Table.bitsPerEntry(t) < 8)
            Vector.range(0, perByte) |> Vector.foldLeft((acc, k) -> {
                let at = i * perByte + k;
                let v = if (at < Table.entries(t)) Table.get(at, t) else 0;
                Int32.bitwiseOr(acc, Int32.leftShift(v, k * Table.bitsPerEntry(t)))
            }, 0)
        else
            let width = Table.bitsPerEntry(t) / 8;
            let v = Table.get(i / width, t);
            Int32.bitwiseAnd(Int32.rightShift(v, Int32.modulo(i, width) * 8), 255)

    ///
    /// An `Int32` as four bytes, least significant first.
    ///
    def int32Bytes(v: Int32): Vector[Int32] =
        Vector.init(b -> Int32.bitwiseAnd(Int32.rightShift(v, b * 8), 255), 4)

    ///
    /// An `Int64` as eight bytes, least significant first.
    ///
    def int64Bytes(v: Int64): Vector[Int32] =
        Vector.init(b -> {
            let shifted = Int64.rightShift(v, b * 8);
            Int64.tryToInt32(Int64.bitwiseAnd(shifted, 255i64)) |> Option.getWithDefault(0)
        }, 8)

    ///
    /// A byte value as an `Int8`, wrapping above 127.
    ///
    def toByte(v: Int32): Int8 =
        let low = Int32.bitwiseAnd(v, 255);
        Int32.tryToInt8(if (low > 127) low - 256 else low) |> Option.getWithDefault(0i8)

    ///
    /// FNV-1a over `bytes`.
    ///
    def checksum(bytes: Vector[Int32]): Int64 =
        let prime = 1099511628211i64;
        let step = (hash, b) ->
            Int64.bitwiseXor(hash, Int32.toInt64(Int32.bitwiseAnd(b, 255))) * prime;
        Vector.foldLeft(step, -3750763034362895579i64, bytes)

    // ---------- decoding ----------

    ///
    /// The table and header `bytes` hold, or why they hold none.
    ///
    pub def decode(bytes: Vector[Int8]): Result[String, (Header, TableView)] =
        let raw = Vector.map(b -> Int32.bitwiseAnd(Int8.toInt32(b), 255), bytes);
        checkFrame(raw) |> Result.flatMap(_ -> readParts(raw))

    ///
    /// The table `bytes` hold, if its header is the one expected.
    ///
    /// The generator is not compared: a table built by an older build of the
    /// same code is still that table.
    ///
    pub def expect(wanted: Header, bytes: Vector[Int8]): Result[String, TableView] =
        decode(bytes) |> Result.flatMap(match (found, t) ->
            if (tableOf(found) != tableOf(wanted))
                Err("this file holds the table '${tableOf(found)}', but "
                    + "'${tableOf(wanted)}' was wanted")
            else if (conventionOf(found) != conventionOf(wanted))
                Err("this file was built under the convention "
                    + "'${conventionOf(found)}', but this build reads "
                    + "'${conventionOf(wanted)}': the two number the cube "
                    + "differently, so the table describes a different puzzle")
            else
                Ok(t))

    ///
    /// The magic, the schema and the checksum: what must hold before anything
    /// is read out of the file.
    ///
    def checkFrame(raw: Vector[Int32]): Result[String, Unit] =
        if (Vector.length(raw) < 8 + 4 + 8)
            Err("this is not a cubesolve table file: it is only "
                + "${Vector.length(raw)} bytes, shorter than a header")
        else if (Vector.take(8, raw) != magic())
            Err("this is not a cubesolve table file: it does not start the way "
                + "one does")
        else
            checkSchema(raw) |> Result.flatMap(_ -> checkSeal(raw))

    ///
    /// The schema version must be one this build understands.
    ///
    def checkSchema(raw: Vector[Int32]): Result[String, Unit] =
        let found = readInt32(8, raw);
        if (found == schema())
            Ok(())
        else
            Err("this file is schema version ${found} and this build reads "
                + "version ${schema()}: rebuild the table rather than reading it")

    ///
    /// The checksum must match everything before it.
    ///
    def checkSeal(raw: Vector[Int32]): Result[String, Unit] =
        let cut = Vector.length(raw) - 8;
        let body = Vector.take(cut, raw);
        let recorded = readInt64(cut, raw);
        if (checksum(body) == recorded)
            Ok(())
        else
            Err("this table file is corrupt: its checksum does not match its "
                + "contents, so it was truncated, damaged, or is still being "
                + "written")

    ///
    /// Read the header and the payload, the frame having already been checked.
    ///
    def readParts(raw: Vector[Int32]): Result[String, (Header, TableView)] =
        forM (
            afterTable <- readText(12, raw);
            afterConvention <- readText(fst(afterTable), raw);
            afterGenerator <- readText(fst(afterConvention), raw);
            result <- readTable(fst(afterGenerator), raw,
                header({
                    table = snd(afterTable),
                    convention = snd(afterConvention),
                    generator = snd(afterGenerator)
                }))
        ) yield result

    ///
    /// A length-prefixed string at `at`, and where it ends.
    ///
    def readText(at: Int32, raw: Vector[Int32]): Result[String, (Int32, String)] =
        if (at + 4 > Vector.length(raw))
            Err("this table file ends inside its header")
        else
            let len = readInt32(at, raw);
            if (len < 0 or at + 4 + len > Vector.length(raw))
                Err("this table file claims a ${len}-character name it does not hold")
            else
                let chars = Vector.range(0, len)
                    |> Vector.map(i -> characterOf(Vector.get(at + 4 + i, raw)));
                Ok((at + 4 + len, Vector.foldLeft((acc, c) -> acc + c, "", chars)))

    ///
    /// The table itself, and the check that nothing follows it.
    ///
    def readTable(at: Int32, raw: Vector[Int32], h: Header): Result[String, (Header, TableView)] =
        if (at + 12 > Vector.length(raw) - 8)
            Err("this table file ends before its payload")
        else
            let entries = readInt32(at, raw);
            let bits = readInt32(at + 4, raw);
            let length = readInt32(at + 8, raw);
            let start = at + 12;
            if (entries < 0 or length < 0 or length != Table.payloadBytes(bits, entries))
                Err("this table file describes ${entries} entries of ${bits} bits "
                    + "in ${length} bytes, which do not fit together")
            else if (start + length != Vector.length(raw) - 8)
                Err("this table file has ${Vector.length(raw) - 8 - start - length} "
                    + "bytes of trailing data: something else has been writing to it")
            else
                rebuild(bits, entries, start, length, raw) |> Result.map(t -> (h, t))

    ///
    /// A table from the payload bytes.
    ///
    def rebuild(
        bits: Int32,
        entries: Int32,
        start: Int32,
        length: Int32,
        raw: Vector[Int32]
    ): Result[String, TableView] =
        region rc {
            let payload = Table.emptyPayload(rc, bits, entries);
            if (Array.length(payload) != length)
                Err("this table file's payload is ${length} bytes where "
                    + "${entries} entries of ${bits} bits need "
                    + "${Array.length(payload)}")
            else {
                Vector.range(0, length) |> Vector.forEach(i ->
                    Array.put(toByte(Vector.get(start + i, raw)), i, payload));
                Table.ofPayload(bits, entries, payload)
            }
        }

    ///
    /// Every printable ASCII character, in code order from space.
    ///
    /// The standard library converts a character to its code point but not back,
    /// and identifiers here are ASCII by construction, so decoding indexes this
    /// rather than reaching for Java interop and an `IO` effect on a pure codec.
    ///
    def printable(): String =
        " !\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
            + "abcdefghijklmnopqrstuvwxyz{|}~"

    ///
    /// The character with ASCII code `code`.
    ///
    def characterOf(code: Int32): String =
        if (code >= 32 and code < 127)
            "${String.charAt(code - 32, printable())}"
        else
            "?"

    ///
    /// The `Int32` at `at`, least significant byte first.
    ///
    def readInt32(at: Int32, raw: Vector[Int32]): Int32 =
        Vector.range(0, 4) |> Vector.foldLeft((acc, b) ->
            Int32.bitwiseOr(acc, Int32.leftShift(Vector.get(at + b, raw), b * 8)), 0)

    ///
    /// The `Int64` at `at`, least significant byte first.
    ///
    def readInt64(at: Int32, raw: Vector[Int32]): Int64 =
        Vector.range(0, 8) |> Vector.foldLeft((acc, b) -> {
            let byte = Int32.toInt64(Vector.get(at + b, raw));
            Int64.bitwiseOr(acc, Int64.leftShift(byte, b * 8))
        }, 0i64)

    ///
    /// `bytes` with a different schema version written into it, resealed.
    ///
    /// Only a test needs this: it is how "a file from a future version" is
    /// produced without keeping a second copy of the writer.
    ///
    pub def withSchemaForTesting(version: Int32, bytes: Vector[Int8]): Vector[Int8] =
        let raw = Vector.map(b -> Int32.bitwiseAnd(Int8.toInt32(b), 255), bytes);
        let cut = Vector.length(raw) - 8;
        let patched = Vector.init(i ->
            if (i >= 8 and i < 12) Vector.get(i - 8, int32Bytes(version))
            else Vector.get(i, raw), cut);
        Vector.append(patched, int64Bytes(checksum(patched))) |> Vector.map(toByte)

}
