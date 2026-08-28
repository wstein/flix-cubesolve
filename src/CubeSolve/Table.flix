///
/// Packed lookup tables, and the one handle everything reads them through.
///
/// A search does tens of millions of successor steps, each one a lookup of the
/// form `table[coord * nMoves + move]`. Two things follow, and this module
/// exists for both.
///
/// **Width is explicit.** An `Array[Int32]` holding byte-width data multiplies
/// memory by four. At the sizes the larger cubes need, the builder's storage,
/// the immutable copy and the serialisation buffer can be alive at once, and it
/// is *peak* heap that breaches a ceiling rather than retained size. So an
/// entry occupies two, four or eight bits and says which.
///
/// **The index is checked.** JVM arrays are `int`-indexed, so `2^31 - 1`
/// elements is a hard cap, and `coord * nMoves` is exactly the product that
/// passes it without any sign of having done so. `flatIndex` computes it in
/// `Int64` and refuses rather than narrowing a wrapped value.
///
/// What backs the handle is deliberately not visible here. See
/// `docs/adr/0001-table-backing.md`: fixing this interface first meant that
/// question chose a backing rather than deciding whether the architecture
/// worked.
///
mod CubeSolve.Table {

    use CubeSolve.Table.TableView.TableView

    ///
    /// A read-only table of small non-negative integers.
    ///
    /// Carries its own width and entry count so that a caller cannot read it
    /// under the wrong shape, and so that a serialised table can be checked
    /// against its header.
    ///
    pub enum TableView with Eq {
        case TableView(Int32, Int32, Vector[Int8])
    }

    ///
    /// How many bits each entry of `t` occupies: 2, 4, 8, 16 or 32.
    ///
    pub def bitsPerEntry(t: TableView): Int32 = let TableView(bits, _, _) = t; bits

    ///
    /// How many entries `t` holds.
    ///
    pub def entries(t: TableView): Int32 = let TableView(_, count, _) = t; count

    ///
    /// How many bytes `t`'s payload occupies.
    ///
    pub def byteLength(t: TableView): Int32 = let TableView(_, _, p) = t; Vector.length(p)

    ///
    /// Entry `i` of `t`.
    ///
    /// Unchecked, because this is the search's inner loop and a bounds test per
    /// lookup is not free. Use `tryGet` anywhere that is not a hot loop; an
    /// index out of range here reads a neighbouring entry rather than failing,
    /// which is precisely why `flatIndex` exists to compute the index safely.
    ///
    pub def get(i: Int32, t: TableView): Int32 =
        let TableView(bits, _, payload) = t;
        if (bits < 8) getPacked(i, bits, payload) else getWide(i, bits / 8, payload)

    ///
    /// An entry narrower than a byte, several to the byte.
    ///
    def getPacked(i: Int32, bits: Int32, payload: Vector[Int8]): Int32 =
        let perByte = 8 / bits;
        let byte = byteAt(i / perByte, payload);
        let shift = Int32.modulo(i, perByte) * bits;
        Int32.bitwiseAnd(Int32.rightShift(byte, shift), mask(bits))

    ///
    /// An entry of one or more whole bytes, least significant first.
    ///
    /// Little-endian by choice rather than by accident, and recorded as such in
    /// every serialised header: a table written on one machine and read on
    /// another must agree, and "whatever the platform does" is not an agreement.
    ///
    def getWide(i: Int32, width: Int32, payload: Vector[Int8]): Int32 =
        let at = i * width;
        Vector.range(0, width)
            |> Vector.foldLeft((acc, b) ->
                Int32.bitwiseOr(acc, Int32.leftShift(byteAt(at + b, payload), b * 8)), 0)

    ///
    /// Byte `at` of `payload`, as `0` to `255`.
    ///
    /// Flix's byte type is signed and has no unsigned counterpart, so a byte
    /// with its top bit set arrives negative. Masking is what keeps that an
    /// artefact of the storage rather than something a caller has to know.
    ///
    def byteAt(at: Int32, payload: Vector[Int8]): Int32 =
        Int32.bitwiseAnd(Int8.toInt32(Vector.get(at, payload)), 255)

    ///
    /// Entry `i` of `t`, or why there is no such entry.
    ///
    pub def tryGet(i: Int32, t: TableView): Result[String, Int32] =
        if (i < 0 or i >= entries(t))
            Err("entry ${i} is outside a table of ${entries(t)} entries")
        else
            Ok(get(i, t))

    ///
    /// The low `bits` bits set.
    ///
    /// At 32 bits that is every bit, and `1 << 32` does not give it, so the
    /// widest case is written out rather than computed.
    ///
    def mask(bits: Int32): Int32 =
        if (bits >= 32) Int32.maxValue() else Int32.leftShift(1, bits) - 1

    ///
    /// How many bytes `count` entries of `bits` bits occupy, rounded up.
    ///
    pub def payloadBytes(bits: Int32, count: Int32): Int32 =
        if (bits < 8)
            let perByte = 8 / bits;
            (count + perByte - 1) / perByte
        else
            count * (bits / 8)

    ///
    /// A table holding `values`, at `bits` bits each.
    ///
    /// Convenient, and it costs a transient `Vector[Int32]` four times the size
    /// of the result -- which is fine for a fixture or a test and is exactly
    /// what the large tables must not do. Those build into a payload directly;
    /// see `emptyPayload`.
    ///
    pub def ofValues(bits: Int32, values: Vector[Int32]): Result[String, TableView] =
        checkWidth(bits) |> Result.flatMap(_ ->
            match Vector.findLeft(v -> not fits(bits, v), values) {
                case Some(bad) => Err(outOfRange(bits, bad))
                case None      => Ok(packValues(bits, values))
            })

    ///
    /// Whether `v` can be stored in `bits` bits.
    ///
    def fits(bits: Int32, v: Int32): Bool = v >= 0 and v <= mask(bits)

    ///
    /// Why a value cannot be stored at this width.
    ///
    def outOfRange(bits: Int32, v: Int32): String =
        "the value ${v} does not fit in ${bits} bits, which hold 0 to ${mask(bits)}: "
            + "storing it would truncate it silently"

    ///
    /// Whether `bits` is a width an entry can have.
    ///
    def checkWidth(bits: Int32): Result[String, Unit] =
        if (bits == 2 or bits == 4 or bits == 8 or bits == 16 or bits == 32)
            Ok(())
        else
            Err("${bits} bits per entry is not supported: an entry occupies 2, 4, "
                + "8, 16 or 32 bits, so that entries and bytes divide each other")

    ///
    /// `values` packed, having already been checked.
    ///
    def packValues(bits: Int32, values: Vector[Int32]): TableView = region rc {
        let count = Vector.length(values);
        let payload = emptyPayload(rc, bits, count);
        Vector.range(0, count) |> Vector.forEach(i ->
            putEntry(payload, bits, i, Vector.get(i, values)));
        TableView(bits, count, Array.toVector(payload))
    }

    // ---------- building a large table by mutation ----------

    ///
    /// A zeroed payload for `count` entries of `bits` bits, inside `rc`.
    ///
    /// The large tables are built by breadth-first search, which writes entries
    /// as it discovers them and cannot be expressed as a function of the index.
    /// So they allocate this, fill it, and freeze it with `ofPayload`. The
    /// region is what stops the mutable array outliving the construction.
    ///
    pub def emptyPayload(rc: Region[r], bits: Int32, count: Int32): Array[Int8, r] \ r =
        Array.repeat(rc, payloadBytes(bits, count), 0i8)

    ///
    /// A payload for `count` entries, every one holding `value`.
    ///
    /// A breadth-first search needs a marker for "not reached yet" that is not
    /// a legal distance, and zero is the distance of the solved state. So the
    /// table starts full of the width's largest value and the search overwrites
    /// it.
    ///
    pub def filledPayload(
        rc: Region[r],
        bits: Int32,
        count: Int32,
        value: Int32
    ): Array[Int8, r] \ r =
        if (bits < 8)
            // Every entry in a byte holds the same value, so the byte is the
            // same for all of them and the whole array is one repeat. Writing
            // entry by entry here costs millions of read-modify-writes to
            // produce a constant.
            Array.repeat(rc, payloadBytes(bits, count), narrow(repeatedByte(bits, value)))
        else {
            let payload = emptyPayload(rc, bits, count);
            Vector.range(0, count) |> Vector.forEach(i -> putEntry(payload, bits, i, value));
            payload
        }

    ///
    /// The byte whose every `bits`-wide field holds `value`.
    ///
    def repeatedByte(bits: Int32, value: Int32): Int32 =
        let place = (acc, k) -> Int32.bitwiseOr(acc, Int32.leftShift(value, k * bits));
        Vector.range(0, 8 / bits) |> Vector.foldLeft(place, 0)

    ///
    /// The largest value `bits` bits can hold.
    ///
    /// Doubles as the "not reached yet" marker while a table is being built,
    /// which is sound exactly when the real values stop short of it -- as the
    /// 2x2x2's distances do, reaching 11 in a four-bit table.
    ///
    pub def widest(bits: Int32): Int32 = mask(bits)

    ///
    /// Entry `i` of a payload still under construction.
    ///
    /// The read half of `putEntry`, for a builder that has to look at what it
    /// has already written -- which a breadth-first search does at every edge.
    ///
    pub def getEntry(payload: Array[Int8, r], bits: Int32, i: Int32): Int32 \ r =
        if (bits < 8) getPackedFrom(payload, bits, i) else getWideFrom(payload, bits / 8, i)

    ///
    /// The packed case of `getEntry`.
    ///
    def getPackedFrom(payload: Array[Int8, r], bits: Int32, i: Int32): Int32 \ r =
        let perByte = 8 / bits;
        let byte = Int32.bitwiseAnd(Int8.toInt32(Array.get(i / perByte, payload)), 255);
        Int32.bitwiseAnd(Int32.rightShift(byte, Int32.modulo(i, perByte) * bits), mask(bits))

    ///
    /// The whole-byte case of `getEntry`.
    ///
    def getWideFrom(payload: Array[Int8, r], width: Int32, i: Int32): Int32 \ r =
        let at = i * width;
        Vector.range(0, width)
            |> Vector.foldLeft((acc, b) ->
                let byte = Int32.bitwiseAnd(Int8.toInt32(Array.get(at + b, payload)), 255);
                Int32.bitwiseOr(acc, Int32.leftShift(byte, b * 8)), 0)

    ///
    /// Write `value` as entry `i` of `payload`.
    ///
    /// Assumes the value fits; `ofPayload` cannot re-check every entry without
    /// undoing the point of building in place, so the caller that produced the
    /// value is the one that knows its range.
    ///
    pub def putEntry(payload: Array[Int8, r], bits: Int32, i: Int32, value: Int32): Unit \ r =
        if (bits < 8) putPacked(payload, bits, i, value) else putWide(payload, bits / 8, i, value)

    ///
    /// Write an entry narrower than a byte, leaving its neighbours alone.
    ///
    def putPacked(payload: Array[Int8, r], bits: Int32, i: Int32, value: Int32): Unit \ r =
        let perByte = 8 / bits;
        let at = i / perByte;
        let shift = Int32.modulo(i, perByte) * bits;
        let old = Int32.bitwiseAnd(Int8.toInt32(Array.get(at, payload)), 255);
        let hole = Int32.bitwiseNot(Int32.leftShift(mask(bits), shift));
        let merged = Int32.bitwiseOr(Int32.bitwiseAnd(old, hole), Int32.leftShift(value, shift));
        Array.put(narrow(merged), at, payload)

    ///
    /// Write an entry of one or more whole bytes, least significant first.
    ///
    def putWide(payload: Array[Int8, r], width: Int32, i: Int32, value: Int32): Unit \ r =
        let at = i * width;
        Vector.range(0, width) |> Vector.forEach(b ->
            Array.put(narrow(Int32.rightShift(value, b * 8)), at + b, payload))

    ///
    /// A byte's worth of bits as an `Int8`.
    ///
    /// Flix's byte type is signed and there is no `UInt8`, so a full byte with
    /// the top bit set is a negative `Int8`. Nothing here depends on the sign:
    /// `get` masks the value back out.
    ///
    def narrow(v: Int32): Int8 =
        let low = Int32.bitwiseAnd(v, 255);
        let signed = if (low > 127) low - 256 else low;
        Int32.tryToInt8(signed) |> Option.getWithDefault(0i8)

    ///
    /// Freeze a filled payload into a table.
    ///
    pub def ofPayload(
        bits: Int32,
        count: Int32,
        payload: Array[Int8, r]
    ): Result[String, TableView] \ r =
        checkWidth(bits) |> Result.flatMap(_ ->
            let needed = payloadBytes(bits, count);
            if (Array.length(payload) != needed)
                Err("a payload for ${count} entries of ${bits} bits is ${needed} "
                    + "bytes, but this one is ${Array.length(payload)}")
            else
                Ok(TableView(bits, count, Array.toVector(payload))))

    // ---------- the checked flat index ----------

    ///
    /// `row * stride + column`, refused rather than wrapped.
    ///
    /// This is the index a coordinate move table is read at. The product is
    /// formed in `Int64` and only narrowed once it is known to fit, because a
    /// wrapped `Int32` is a plausible-looking index into the same array and
    /// produces a wrong answer instead of a failure.
    ///
    pub def flatIndex(row: Int32, stride: Int32, column: Int32): Result[String, Int32] =
        if (row < 0 or stride < 0 or column < 0)
            Err("a flat index is built from non-negative parts, but this one is "
                + "row ${row}, stride ${stride}, column ${column}")
        else
            let wide = Int32.toInt64(row) * Int32.toInt64(stride) + Int32.toInt64(column);
            match Int64.tryToInt32(wide) {
                case Some(i) => Ok(i)
                case None    =>
                    Err("row ${row} x stride ${stride} + ${column} is ${wide}, past the "
                        + "${Int32.maxValue()} elements a JVM array can hold")
            }

}
