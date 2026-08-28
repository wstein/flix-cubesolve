# Conventions

A cube token stores ordinals and no geometry. Relabelling slots by any bijection
preserves every invariant and changes only the encoding — so a table, a fixture
or a test vector without its convention recorded pins nothing at all.

This file is that record. Every convention here is carried in the header of
every generated table, and changing any of them invalidates every table and
fixture in the repository.

## Faces

Six faces, numbered in Kociemba order:

| index | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| face | U | R | F | D | L | B |
| colour | white | red | green | yellow | orange | blue |

A facelet index is `face * n² + cell`, with cells numbered row-major from the
face's top-left as drawn in the standard unfolded net.

## Permutations are slot-indexed

`p[i]` is **the piece sitting in slot `i`**. The solved cube is the identity.

The alternative reading — `p[i]` is the slot holding piece `i` — is the inverse
permutation. It is equally defensible and it is used by other projects. Mixing
the two produces a solver that solves the inverse of what it was handed, which
is a bug that survives most tests because the two agree on the solved cube, on
every involution, and on every state at distance 1.

## Composition order

For permutations `a` and `b`, applying `b` and then `a`:

```
(a · b)[i] = a[b[i]]
```

Tested by `m⁴ = id` for every move, by opposite-face commutation, and by
"scramble then its inverse returns the identity".

## Corner slots

Kociemba order. The three facelets of each slot are listed starting from the
slot's **orientation facelet**, then clockwise.

| slot | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| name | URF | UFL | ULB | UBR | DFR | DLF | DBL | DRB |

Twist is `0`, `1` or `2`: the number of clockwise thirds by which the piece is
rotated relative to the slot's facelet listing. Equivalently, twist `0` means
the piece's U-or-D facelet lies on the slot's U-or-D facelet. Twists sum to
`0 mod 3` over all eight corners.

## Edge and midge slots

Kociemba order.

| slot | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| name | UR | UF | UL | UB | DR | DF | DL | DB | FR | FL | BL | BR |

Flip is `0` or `1`, `0` meaning the piece's first-listed colour lies on the
slot's first-listed facelet. Flips sum to `0 mod 2` over all twelve edges.

## Agreement with `flix-orbit64` and with min2phase

**These three conventions coincide exactly**, which is why this engine needs no
relabelling layer between its model, its dependency, and reference fixtures.

Verified against `flix-orbit64` v0.3.0 `src/Orbit64/Net.flix` by decoding its
`cornerFacelet`, `edgeFacelet`, `cornerColor` and `edgeColor` tables: all four
reproduce Kociemba's facelet indices entry for entry under
`orbit64-3x3-draft@1`. For example orbit64's corner slot 0 is
`{8, 9, 20}` with colours `{U, R, F}`, which is Kociemba's `URF = {U9, R1, F3}`
in 0-based indices; and its edge slot 8 is `{23, 12}` with colours `{F, R}`,
which is Kociemba's `FR = {F6, R4}`.

This is a *finding*, not a guarantee. If `flix-orbit64` changes its draft
convention, re-run the decoding before assuming this still holds — the failure
mode is silent, because both conventions describe a valid cube and disagree only
about which one.

## Moves

The half-turn metric (HTM). A move is a face and an amount:

```
move index = face * 3 + (amount - 1)      amount in 1..3
```

| index | 0 | 1 | 2 | 3 | 4 | 5 | … | 17 |
|---|---|---|---|---|---|---|---|---|
| move | U | U2 | U' | R | R2 | R' | … | B' |

Faces run in the order above, so `U R F D L B` maps to `0 1 2 3 4 5`. A quarter
turn is clockwise when looking at the face from outside the cube.

**Move pruning is generator-specific**, and getting this wrong silently loses
solutions rather than producing wrong ones:

- Over an HTM alphabet, forbid two consecutive moves on the *same* face.
- Over a clockwise-only alphabet, do **not** forbid `R` after `R` — that makes
  `R2` inexpressible.
- Over both, fix an order for the commuting opposite-face pairs (U/D, R/L, F/B)
  and allow only that order.

## The 2×2×2

A 2×2×2 has no fixed centres, so one corner may be held still without loss of
generality. This engine fixes **DBL** — corner slot 6 — which leaves `U`, `R`
and `F` as a sufficient generator set.

```
permutation coordinate   7!  = 5040     Lehmer rank of the 7 movable corners
orientation coordinate   3⁶  =  729     base-3, the 7th twist forced by the sum
combined index           permIndex * 729 + oriIndex
```

The orientation coordinate is 729 and not 2187: with DBL held at twist 0 the
remaining seven twists still sum to `0 mod 3`, so six are free. Using 2187 is
valid but sparse.

Movable corner slots are `0 1 2 3 4 5 7` — that is, all but DBL — renumbered to
`0..6` in that order.

## Whole-cube orientation

`flix-orbit64` excludes an odd cube's six fixed centres — they define the
reference frame rather than carrying state — and `Orbit64.Net.fromFacelets`
refuses a cube whose fixed centres have moved.

A solver cannot refuse those, because `M`, `E`, `S`, `x`, `y`, `z` and the wide
turns used by WCA 4×4×4 and 5×5×5 scrambles all move centres relative to the
frame. So this engine's model carries a whole-cube orientation, one of 24, and
the API boundary:

1. reads the input in whatever frame it arrives,
2. records the rotation mapping it to the canonical frame,
3. solves in the canonical frame,
4. re-expresses the solution in the caller's frame.

The canonical frame is **U on top, F in front** — orientation index 0.

## Coordinates are canonical-frame, and slice moves look odd because of it

The orbit coordinates always describe the cube **as it would look rotated back
upright**. The frame is carried separately, by the whole-cube orientation. The
pair is faithful; neither half is.

This has one consequence that surprises everybody who meets it. A slice move
physically turns the middle layer: four edges and four centres move, and no
corner does. But a slice move also rotates the frame, and undoing that rotation
to get back to canonical coordinates carries the two outer layers with it. So in
canonical coordinates:

```
M  =  R L'   together with the frame rotation  x'
```

— and all eight corners have moved. That is correct, not a bug. `M` and `R L'`
agree on the arrangement and differ only in the frame, which is exactly why the
frame cannot be dropped.

`TestNotation.aSliceMoveShowsAsOuterLayersInCanonicalCoordinates` pins this, so
that a reader who notices the surprising corner motion and "fixes" it fails a
test that explains why.

## What a table header records

Magic; schema version; source and generator version; cube size; table
identifier; **move alphabet, numbering and metric**; **slot and facelet
convention**; entry count; bit width; payload length; byte order; digest.

The convention fields are not optional, for the reason at the top of this file.
