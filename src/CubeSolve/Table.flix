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
    /// How many bits each entry of `t` occupies: 2, 4 or 8.
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
        let perByte = 8 / bits;
        let byte = Int8.toInt32(Vector.get(i / perByte, payload));
        let shift = (Int32.modulo(i, perByte)) * bits;
        Int32.bitwiseAnd(Int32.rightShift(byte, shift), mask(bits))

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
    def mask(bits: Int32): Int32 = Int32.leftShift(1, bits) - 1

    ///
    /// How many bytes `count` entries of `bits` bits occupy, rounded up.
    ///
    pub def payloadBytes(bits: Int32, count: Int32): Int32 =
        let perByte = 8 / bits;
        (count + perByte - 1) / perByte

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
        if (bits == 2 or bits == 4 or bits == 8)
            Ok(())
        else
            Err("${bits} bits per entry is not supported: an entry occupies 2, 4 "
                + "or 8 bits, so that a whole number of them fits in a byte")

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
    /// Write `value` as entry `i` of `payload`.
    ///
    /// Assumes the value fits; `ofPayload` cannot re-check every entry without
    /// undoing the point of building in place, so the caller that produced the
    /// value is the one that knows its range.
    ///
    pub def putEntry(payload: Array[Int8, r], bits: Int32, i: Int32, value: Int32): Unit \ r =
        let perByte = 8 / bits;
        let at = i / perByte;
        let shift = (Int32.modulo(i, perByte)) * bits;
        let old = Int8.toInt32(Array.get(at, payload));
        let cleared = Int32.bitwiseAnd(old, Int32.bitwiseNot(Int32.leftShift(mask(bits), shift)));
        let merged = Int32.bitwiseOr(cleared, Int32.leftShift(value, shift));
        Array.put(narrow(merged), at, payload)

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
