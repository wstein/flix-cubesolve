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
