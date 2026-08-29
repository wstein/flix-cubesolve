# Architecture

## The layers

```
CubeSolve.Model      pieces, moves, validation, sampling
CubeSolve.Table      packed lookup tables behind one read handle
CubeSolve.Solve      IDA*, phases, per-size solvers
CubeSolve.Scramble   random-state scrambling, over Solve's public API only
```

The dependency arrows run strictly downward. `Scramble` in particular is written
against `Solve`'s public API and nothing else, because random-state scrambling
*is* solving — sample a legal state, solve it, emit the inverse — and if it
reached inside the solver the two would drift.

## Two representations, kept apart

| layer | representation | used for |
|---|---|---|
| model | permutation and orientation vectors, one per orbit | validation, tests, I/O, phase-boundary checks |
| search | scalar `Int32` coordinates | `newCoord = table[coord * nMoves + move]` |

A search performing tens of millions of successor steps cannot afford to
allocate or to touch a vector, so it works in single integers and a flat table.

An integer, though, cannot say *why* it is invalid. `Err("the corner twists must
sum to 0 mod 3")` needs pieces; `Err("coordinate 1082564 is invalid")` helps
nobody. And a search bug that corrupts a coordinate will happily validate itself
if you ask the coordinate about it. So:

> **Phase-boundary validation is computed from the decoded model state, never by
> rereading the search coordinate the search just wrote.**

This is the single rule that most of the testing strategy exists to protect.

## The model

Cube state factors into orbits — families of pieces that turns permute among
themselves and never mix. `flix-orbit64` derives that decomposition from pure
arithmetic in `n`, and this engine adopts it rather than restating it:

| orbit | slots | state |
|---|---|---|
| Corners | 8 | permutation + twist `0..2`, summing to `0 mod 3` |
| Midges | 12 | permutation + flip `0..1`, summing to `0 mod 2` (odd `n` only) |
| Wings | 24 each | bare permutation, no orientation |
| Centres | 24 each | colour multiset, four of each of six |

Two of these are easy to get wrong and expensive to discover late.

**Wings are chiral even though they carry no orientation.** Two wings of a
colour pair look interchangeable but are not: the pair appears in opposite order
depending on the slot's handedness. The count is `24!`, not `24!/2¹²`. Getting
this wrong puts the 4×4×4 state space out by a factor of 4096.

**Centres are a multiset, not a permutation.** Four indistinguishable centres
per colour gives `24!/(4!)⁶` and a multiset rank, not a Lehmer rank.

This is the same decomposition `cube555` arrives at independently as
`tCenter`/`xCenter`/`wEdge`/`mEdge`. Two derivations agreeing is a good sign.

### Generic over `n`, with typed boundaries

The orbit layout is arithmetic in `n`, so the core is generic:

```
CubeState = { n, orbits }
```

The cost of a generic core is that nothing stops a 4×4×4 state reaching the
3×3×3 solver. The boundary is therefore wrapped in per-size newtypes in
`CubeSolve.Model.Sized` — `Pocket` and `Standard` today, one per size the engine
implements — built by validating smart constructors that name the mismatch. They
are newtypes over the same `Cube`, so there is no second representation and no
conversion cost; what they add is that the two are different types and cannot be
passed for one another.

One caveat, stated rather than glossed: Flix has no private enum case, so the
constructors are reachable. The guarantee the wrappers give is that a size
mismatch is a *type* error at every call site, not that every value was built
through a smart constructor.

### Whole-cube orientation

`flix-orbit64` excludes an odd cube's six fixed centres, treating them as the
reference frame rather than as state, and `Orbit64.Net.fromFacelets` refuses any
cube whose fixed centres have moved.

A codec may refuse those. A solver may not: users paste scrambles containing
`M`, `E`, `S`, `x`, `y`, `z`, and WCA 4×4×4 and 5×5×5 scrambles use wide turns
that move centres relative to the frame.

So `CubeState` carries one field orbit64 does not: a whole-cube orientation, one
of 24. The API boundary normalises into the canonical frame, solves there, and
re-expresses the answer in the caller's frame. This has to be in the model from
the start — bolting it on later means touching every conversion.

### Conversions, not abstraction

There is deliberately **no** `trait CubeRepr` with facelet, cubie and coordinate
instances. The three representations are not interchangeable; they support
genuinely different operations:

| | apply a move | "which piece is in slot 7" | table lookup | render |
|---|---|---|---|---|
| facelet | expensive | indirect | no | yes |
| cubie | cheap | direct | no | via conversion |
| coordinate | one array read | impossible | yes | no |

A neutral interface would be the intersection of those, which is close to empty,
and it would insert dispatch into exactly the layer where JVM inlining matters
most.

The neutrality that *is* worth having is in the conversions. Three concrete
types, explicit conversions, each property-tested in both directions:

```
facelet  ←→  cubie  ←→  coordinate
```

## Tables

Everything downstream — IDA\*, every pruning lookup, every reduction stage —
reads tables through one opaque handle:

```
CubeSolve.Table.TableView      opaque;  get(i): Int32
```

What backs it is an implementation choice: an immutable `Vector`, a frozen
`Array`, a region-scoped `Array` threaded through, or a Java `byte[]`. Fixing
the interface first means the open question in
[ADR-0001](adr/0001-table-backing.md) decides *which backing*, not *whether the
architecture works*.

`Array[Int32]` holding byte-width data multiplies memory by four, so widths are
explicit: `U8Table` (one entry per byte), `Packed4Table` (two), `Packed2Table`
(four). Indices are computed with a checked `Int64` multiply and then narrowed,
because JVM arrays are `int`-indexed and 2³¹−1 elements is a hard cap.

### Keeping tables between runs

Tables are pure and deterministic and expensive, so they are written once and
read back. `CubeSolve.Table.Codec` is the format; `CubeSolve.Table.Cache` is the
policy.

**The cache is an effect, not a filesystem.** `Cache.Store` says only that bytes
can be kept and fetched under a key. `onFilesystem` is one handler, a test's map
is another, and `withoutCache` is a third that always misses. So the logic that
decides *whether a cached table is acceptable* never acquires an `IO` effect,
and it is tested without a disk anywhere near it.

`onFilesystem` leaves the five filesystem effects open, which is what makes that
possible and is also eight nested handlers for anyone who just wants the cache.
`CubeSolve.Table.Cache.Disk.withFilesystem` is that chain, written once, in a
module of its own so the policy module keeps no dependency on the effects it
exists to avoid naming.

**The header is checked, not decorative.** All three identifiers are compared on
read. A table from a different slot numbering is not stale, it is a table of a
different puzzle and would otherwise be read without complaint. The generator is
compared too: what a table contains is decided by the code that built it, and the
convention string does not capture that — change a pruning pairing, a move order,
or fix a bug in a sweep, and every entry differs while the convention is
untouched. This file once called the generator provenance rather than a check;
that was wrong, and the cost of the correction is one rebuild after a version
bump.

**Publication stages somewhere else.** Bytes are written into a directory the
handler obtains for itself and are then moved into place, so a reader sees the
old file or the whole new one. Staging beside the target under a shared name is
what this used to do, and two processes building at once pick the same staging
file: one can publish the other's half-written bytes, and where rename detaches
the name from the open file the loser keeps writing into what is already
published. That breaks the sentence above without corrupting an answer —
deterministic tables mean racing writers produce identical bytes, and where they
would not, a torn file fails its digest and counts as a miss. So the private
directory is defence in depth behind the digest rather than the thing preventing
corruption; *The staging fix is smaller than it was first written up as* in the
design review has the measurement. If no staging directory can be had, nothing is
written.

**A corrupt or foreign cache is a miss, not a failure.** A half-written file
should cost a rebuild, not an outage. `reasonToRebuild` reports which it was, so
a caller can warn rather than guess.

**The tests deliberately do not use the cache.** They call the plain builders,
so they measure building. Sharing a filesystem cache across the suite would cut
its runtime substantially and would leave the builders themselves ungated.
`TestCacheOnDisk` is the exception and covers the handler rather than the tables:
it runs `onFilesystem` through the real `Fs` handlers down to `IO`, in a
temporary directory, and checks that a table survives the round trip, that the
second run reads rather than rebuilds, and that a file from another build is
rebuilt. The in-memory tests prove the policy; that one proves the plumbing,
which is the part that can be wrong without any of them noticing.

## Search

`CubeSolve.Solve.IDAStar` is generic over a phase supplying a move alphabet, a
successor function, a heuristic and a goal test, and is reused unchanged by
every phase of every size.

**Termination is deterministic: probe counts, not wall clock.** Time budgets are
not reproducible — they vary by machine, JDK, JIT warm-up and GC, so a gate
reading "solve in 100 ms" fails on a slow runner and passes on a fast one.

| control | meaning | kind |
|---|---|---|
| `probeMin` | keep improving after the first solution, at least this many probes | quality floor |
| `probeMax` | hard cap; explicit error if exhausted | termination |
| `maxDepth` | reject solutions longer than this | quality constraint |

An optional deadline exists as a secondary safety valve, checked only at probe
boundaries and never inside the node loop. Table initialisation is excluded from
any deadline, and that exclusion is documented — on a cold JVM a small budget is
almost entirely initialisation.

### Admissible heuristics come from homomorphic projections

A projection `π` of cube state is usable as a heuristic when `π(m(s))` depends
only on `π(s)` and `m` — that is, when the move acts on the projection
independently of what was projected away. Distance in the quotient then
lower-bounds distance in the full space, so the heuristic is admissible.

On the 2×2×2 with DBL fixed, *two* projections qualify:

- **orientation**, `new_o[i] = o_old[cp[i]] + co[i]` — 729 states
- **permutation**, `new_p[i] = p_old[cp[i]]` — 5040 states

Both depend only on the move and on the projected part. Using the maximum of the
two is still admissible and is substantially stronger; see
[the design review](design-review.md#motion-2) for the measurements.

## The 3x3x3, in two phases

```
CubeSolve.Solve.Phase1     into  <U, D, R2, L2, F2, B2>
CubeSolve.Solve.Domino     inside that subgroup, to solved
CubeSolve.Solve.Standard   the two together, and the budget
```

Phase one searches `Twist x Flip x UDSlice`, which is 2,217,093,120 states and
overflows `Int32` — which is why the search kernel is parameterised by state
width. Phase two searches `CPerm x EPerm x MPerm`, about 3.9 × 10¹⁰.

The **handover goes through the model**. Phase one's solution is applied to the
cube and phase two's coordinates are read from the result, never from the
coordinate the phase-one search wrote. This is the general rule stated above,
at the place where it matters most: a corrupted coordinate handed to phase two
would produce either a mysterious failure or a confidently solved wrong cube.

The solver works upward through phase-one depths and tries several handovers at
each, because the *shortest* phase one very often leads to a long phase two.

**Phase two prunes phase one.** Before a handover is searched, phase two is
asked for a certified lower bound on what it would need; if that already exceeds
the moves the budget leaves, the handover cannot beat the answer in hand and is
dropped without a probe. It is never attempted, so a probe still means one
phase-two attempt. `Domino.lowerBoundOf` carries that bound, and a test checks
it against real searches, because a bound that overstated would discard winning
handovers silently.
Termination is by **probe count** — one probe is one phase-two attempt — with
`probeMin` as a quality floor and `probeMax` as the hard cap.

It searches **six views of the cube**: three axes, each forwards and inverted.

Phase one's goal is stated against the U/D axis, and its Flip coordinate is
defined against that axis specifically — a cube with every edge oriented in the
U/D sense need not be oriented in the F/B sense. So `Cube.conjugate` re-records
the state from a rotated frame, letting the same tables aim at the other two
axes. And a state and its inverse are equally far from solved but sit
differently with respect to phase one's subgroup, so each axis is searched both
ways.

**All six share one probe budget** rather than taking a sixth each, and each is
capped at one move shorter than the best found so far. That distinction is not a
detail: slicing the budget measured 21.1 moves and sharing it measured 20.9, so
the refinement was worth nothing until the budget stopped being sliced. See
[the design review](design-review.md).

Each phase owns its own tables and re-exports them, so the combining layer talks
to `Solve.Phase1` and `Solve.Domino` rather than reaching into their table
modules.

## Testing strategy

Cube code fails in ways that hand-picked examples do not catch.

- **Exhaustive where the space permits.** All 3,674,160 2×2×2 states for the
  oracle's self-consistency and for heuristic admissibility. Admissibility in
  particular is a linear scan over a table and costs about a second.
- **Stratified where it does not.** Verifying *optimality* exhaustively is nine
  orders of magnitude more expensive than verifying admissibility, because it
  runs a search per state rather than reading a byte. Where that is the case,
  test every state in the small distance classes and a fixed-seed sample of the
  large ones — and name the stratification in the test, rather than quietly
  testing nothing.
- **Round-trip.** Every solution replays to the identity; every rank round-trips
  in both directions.
- **Group laws.** Identity, inverse, `m⁴ = id`, opposite-face commutation.
- **Phase-boundary invariants from decoded model state**, per the rule above.
- **Two sampling regimes, named.** The random-walk sampler is *required to fail*
  the uniformity test that the random-state sampler passes. That is what
  documents why random-state scrambling is necessary.
- **Determinism across machines** for any fixed seed and budget. The
  deterministic RNG is a specified in-library algorithm (SplitMix64), never the
  platform default, whose output is not guaranteed stable across JDK versions
  and would silently invalidate every checked-in fixture.
- **Failure reproducibility.** Every failure preserves its seed and canonical
  state token.

### What the suite costs

Four to five minutes, measured at 233 s, 255 s and 328 s on three runs of
identical code — the spread is wide enough that no single figure means much.

The cost is entirely in tests that **run the solver** or **build a table**.
Solving 110 patterns accounted for roughly half the suite on its own, so that
gate is stratified: `TestPatternBoundsFast` covers 27 patterns chosen by stated
rules and runs everywhere (~40 s), and `TestPatternBoundsExhaustive` covers all
110 behind `CUBESOLVE_EXHAUSTIVE=1` (~80 s), which CI sets on main and nightly.
`TestTwoPhase` and `TestScrambleStandard` are about 30 s each; the two
phase-table gates are 20 s and 16 s.

The fixture sweeps are not the slow tier, though they look like the most work:
re-recording all 199 patterns from all 24 orientations costs 0.14 s and 0.05 s.
That was misattributed once, and the restructuring done to fix it saved nothing
— which is the argument for timing a test before rewriting it.

Tests deliberately do not share a table cache; see the note under *Keeping
tables between runs* for why a faster suite would be an unsound one.
