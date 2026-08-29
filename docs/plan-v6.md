# CubeSolve: Staged Implementation Plan — v6

A solving and scrambling engine for n×n×n twisty cubes in Flix, 2×2×2 through
5×5×5.

```
package     cubesolve
repository  github:wstein/flix-cubesolve
modules     ["CubeSolve"]
```

Every figure is measured from a reference implementation
(`cs0x7f/min2phase`, `cs0x7f/TPR-4x4x4-Solver`, `cs0x7f/cube555`,
`wstein/flix-orbit64`) or computed independently. Unverified claims are marked
as such.

## 1. Ground rules

**IDA\* is the search engine, not Datalog.** All three reference solvers share
`PhaseSearch.idaSearch`, with `VALID_MOVES`, `SKIP_MOVES` and `NEXT_AXIS` per
phase. No fixpoint computation appears in any of them. Datalog's honest uses
here are orbit discovery (Stage 2) and an optional 2×2×2 cross-check (Stage 3).

**Two representations, kept apart.**

| layer | representation | used for |
|---|---|---|
| model | `Coord` — permutation and orientation vectors | validation, tests, I/O, phase-boundary checks |
| search | scalar `Int32` coordinates | `newCoord = table[coord * nMoves + move]` |

Coordinates are **single integers**.

**Phase-boundary validation is computed from the decoded model state**, never by
rereading the search coordinate the search just wrote.

**Move pruning is generator-specific.**

- HTM alphabet: forbid consecutive moves on the *same face*.
- Clockwise-only alphabet: do **not** forbid `R` after `R` — that makes `R2`
  inexpressible. Only the commuting-pair ordering rule applies.
- Commuting-pair ordering applies to both: fix an order for opposite faces
  (U/D, R/L, F/B).

**Tables are flat primitive arrays built inside a `region`; search reads them
through `TableView`.** Whether that handle is pure or region-scoped is settled
by §7 *Table backing*. `IO` at the program edge only.

**Do not claim tail-call elimination prevents IDA\* stack overflow.** Depth is
bounded by solution length, the references recurse plainly without overflowing,
and IDA\* recursion is not in tail position.

**Reachability invariants are per cube size and per orbit.** Coupled
corner/edge permutation parity is a 3×3×3 constraint. 4×4×4 wing permutation is
*not* constrained the same way — which is why OLL and PLL parity exist.

**Every public entry point returns `Result`.** Invalid input yields the named
reason from `faultOf` — never a bare `None`, never a thrown exception, never a
silently wrong answer. (F10)

**Termination is deterministic.** Probe counts, not wall clock. §5.

---

## 2. Family, packaging and namespace

```
flix-cube        interactive simulation, workbench, guide   ← application
     │ depends on
flix-cubesolve   solving and scrambling engine              ← this repository
     │ depends on
flix-orbit64     canonical state encoding (Apache-2.0)      ← external
```

**One repository, strict module boundaries.**

```
CubeSolve.Model      state, moves, validation, samplers
CubeSolve.Table      packed tables, cache, fixtures
CubeSolve.Solve      IDA*, phases, per-size solvers
CubeSolve.Scramble   depends on CubeSolve.Solve's public API only
```

**Copy orbit64's packaging discipline.** Everything nests under one module so
nothing collides with a consumer's names, and the library defines **no top-level
`main`**. The CLI lives in `examples/cli-tool`, a separate package depending on
the published `cubesolve`, the same split orbit64 itself moved to.

**Diamond to confirm before first release.** If `flix-cube` already depends on
`flix-orbit64` directly, adding `flix-cubesolve` creates a diamond. Workable if
versions stay compatible; pin deliberately and check now.

**Documentation split.** Engine repository carries API docs and the architecture
specification; the learning guide belongs in `flix-cube`, where the workbench
gives it something to run against.

---

## 3. Build strategy

| repo | src files | code lines |
|---|---|---|
| min2phase | 5 | 1,986 |
| TPR-4x4x4-Solver | 15 | 3,050 |
| cube555 | 20 | 4,002 |

**A wholesale port is the wrong shape of work.** It would discard the effect
boundaries that justify using Flix, inherit known defects (TPR's README lists
under TODO: "Many bugs which might cause ArrayIndexOutOfBoundsException"), and
much of it would be undone by this plan's deliberate divergences.

| layer | approach |
|---|---|
| Rank, cube-legality validation | **Reuse `flix-orbit64`** |
| Model, moves, orbit discovery | **Fresh** |
| 2×2×2 oracle, IDA\* kernel | **Fresh** |
| 3×3×3 coordinate arithmetic | **Port selectively** (`CoordCube` + `CubieCube` ≈ 800 lines) |
| 3×3×3 search | **Fresh** |
| 4×4×4, 5×5×5 | **Fresh, structurally guided** |
| All references | **Capture as fixtures** (§6) |

**Do not extract tables or literal arrays from the sources.** Generate fixtures
by *running* the programs.

---

## 4. Licensing

**All three references are dual-licensed GPLv3 and MIT** — every README carries
both sections, attributed to Shuang Chen / Chen Shuang, 2023. The MIT text is a
standalone grant, so porting under MIT terms with attribution is available.

**One discrepancy to resolve.** The READMEs present both licences without stating
"at your option," and **cube555 additionally ships a `LICENSE` file containing
GPL v3 text only**; the other two ship none. Stage 1 action item: request written
confirmation from the author and check the reply in. Not legal advice; if it
matters commercially, have counsel read the files.

**Where GPL does bite.** orbit64 avoided `cube-solvers` and Twizzle Search
because those are GPL-only. Do not use them as sources.

**Not a clean room.** Generating fixtures and implementing against them is not
clean-room reverse engineering — that requires two isolated teams.

---

## 5. Termination and search budgets

Reference API shape: `solution(facelets, maxDepth, probeMax, probeMin, flags)` —
bounded by **phase-2 probe count**, not wall clock.

**Time budgets are non-reproducible.** They vary by machine, JDK, JIT warm-up
and GC. A gate reading "solve in 100 ms" fails on a slow runner and passes on a
fast one. Probe counts are deterministic.

| control | meaning | kind |
|---|---|---|
| `probeMin` | keep improving after the first solution, at least this many probes | quality floor |
| `probeMax` | hard cap; explicit error if exhausted | termination |
| `maxDepth` | reject solutions longer than this | quality constraint |

**Optional deadline as a secondary safety valve**, checked only at probe
boundaries — never inside the IDA\* node loop.

**Anytime behaviour.** Return a first solution immediately, improve on `next()`.
The deadline then returns the best found so far rather than failing.

**Initialisation is excluded from any deadline, and must be documented.**
min2phase's full init is ~195 ms and it runs 5–10× slower without it. A 100 ms
budget on a cold JVM is almost entirely init.

### Recommended defaults (F12)

| size | `probeMin` | `probeMax` | `maxDepth` | expected | typical time |
|---|---|---|---|---|---|
| 2×2×2 | — | — | 11 | optimal | sub-ms, table lookup |
| 3×3×3 | 100 | 1,000,000 | 21 | ~19.7 | ~5 ms |
| 3×3×3 "fast" | 5 | 100,000 | 21 | ~20.6 | ~1 ms |
| 3×3×3 "short" | 1,000 | 10,000,000 | 20 | ~19.1 | ~36 ms |
| 4×4×4 | reference budgets, §Stage 11 | | 50 | ~44.4 | ~250 ms |
| 5×5×5 | reference budgets, §Stage 12 | | 60 | ~51.5 | 1–2 s |

3×3×3 rows derive from min2phase's `Benchmark.md`. The 100 ms figure often
proposed for interactive use is generous for a 3×3×3 and insufficient for a
5×5×5 — which is why there is no global default.

**CI gates use probes only. Benchmarks report time.**

---

## 6. The fixture-oracle subsystem

Reference behaviour captured once, checked in as versioned static files, diffed
in CI. No build-time dependency, no JVM interop in CI, no version drift.
**Live wrapping is retained as a local debugging tool, not a CI gate.**

### Three tiers

**Tier 1 — already checked in.** `min2phase/pruningValue.txt`,
`cube555/PruningValue.txt`, and TPR's README distribution (40:5, 41:32, 42:99,
43:275, 44:590, 45:658, 46:309, 47:32 over 2000 solves).

**Tier 2 — generate; highest diagnostic value.** Coordinate move tables; phase-1
output states for a fixed corpus; per-phase intermediates for 4×4×4 and 5×5×5.

**Tier 3 — generate; weak assertions only.** Scramble → solution corpora, for
distribution and replay-validity. **Never diff solution strings** — min2phase is
probe-limited and suboptimal, and many valid solutions exist per scramble.

### `pruningValue.txt` decoded

The five blocks are **not** in `Algorithm.md`'s order — phase-2 tables come
first. Matched by exact entry count:

| block total | factorisation | table | phase | max depth | avg |
|---|---|---|---|---|---|
| 66,432 | 2768 × 24 | MCPermPrun | 2 | **14** | 9.69 |
| 387,520 | 2768 × 140 | EPermCCombPrun | 2 | **13** | 9.31 |
| 160,380 | 495 × 324 | UDSliceTwistPrun | 1 | **9** | 6.76 |
| 166,320 | 495 × 336 | UDSliceFlipPrun | 1 | **9** | 6.85 |
| 663,552 | 2048 × 324 | TwistFlipPrun | 1 | **9** | 7.18 |

All five match to the digit. These maxima are exact expected values for Gates
6.1 and 10.2 — and they cap `atLeast` (Stage 9).

### Fixture header

Magic; schema version; source repo and commit; cube size; table or corpus
identifier; **move alphabet, numbering and metric**; **slot and facelet
convention**; search settings where applicable; entry count; digest.

The convention fields are not optional. orbit64's README makes the point:
relabelling slots by any bijection preserves every invariant and changes only
the encoding. A fixture without its convention recorded pins nothing.

### What the oracle cannot do

Cannot validate optimality (min2phase is suboptimal by design); cannot validate
what we do differently; cannot catch a shared misconception; bakes in their
conventions.

---

---

## 7. Table backing and the region question

Everything downstream — IDA\*, every pruning lookup, both reduction stages —
reads tables through one opaque handle:

```flix
CubeSolve.Table.TableView    // opaque; get(i): Int32
```

What backs it is an implementation choice: an immutable `Vector`, a frozen
`Array`, a region-scoped `Array` threaded through, or a Java `byte[]` behind
interop. Fixing the interface first means the open question below decides
*which backing*, not *whether the architecture works*.

### The claim under test

An earlier working assumption held that Flix can convert a region-allocated
mutable array to an immutable structure without a deep copy, because the type
system proves no other mutable reference exists. **Treat this as a hypothesis.**
It traces to the same generated artifact that put the 5×5×5 state space at
10⁴⁰ — off by 34 orders of magnitude. What regions certainly provide is that
mutable data cannot *escape* the region scope; a cheap freeze does not follow
from that.

### Answer it cheaply before spiking

- **Read the Flix stdlib source** for the current array-to-vector conversion at
  the pinned version. If it loops and copies, the question is closed.
- **Ask the Flix maintainers** — small, responsive team. Phrase it concretely:
  a 240 MB read-only lookup table built imperatively and read from pure code,
  what is the intended pattern? That also surfaces their recommended idiom,
  which may beat anything invented here.

Spike only what those leave open.

### The spike

Timeboxed to half a day, in a throwaway repository, at sizes that matter —
behaviour diverges from toy sizes:

| size | stands in for |
|---|---|
| 4.5 MB | `Flip × Twist` (Stage 6) |
| 7.75 MB packed | Edge3, 31,006,080 entries at 2 bits (Stage 11) |
| 240 MB | cube555's cache (Stage 12) |

Three questions, in order:

1. **Does it compile?** Type-level; may end the spike immediately.
2. **What is peak heap during conversion?** The real risk. A one-time copy at
   init costs speed, which is tolerable; a transient 240 MB alongside a 240 MB
   result is 480 MB, which is what breaches the Stage 12 ceiling.
3. **What is random-read throughput through `TableView.get` versus a raw array
   read**, in the IDA\* access pattern — random, not sequential?

### Measuring peak heap (used here and by Gates 11.5 and 12.6)

Bisect `-Xmx`: run repeatedly, halving the heap until it OOMs; the smallest heap
that succeeds is the floor. Reproducible, and independent of sampling a GC
MXBean at the right moment. Use the same method everywhere so figures compare.

One JVM constraint to check while there: arrays are `int`-indexed, so
2³¹−1 elements is the hard cap. 240 MB as `Int8` is 240M elements — fine. The
same data naively as `Int32` is 960 MB: under the element cap, over any sane
heap. That is the four-times hazard from Stage 8, in its worst case.

### Pre-committed outcomes

Decided in advance so the spike cannot end ambiguously:

| outcome | decision |
|---|---|
| **A** — compiles, no copy, reads within ~20% of raw | Adopt. Ceilings stand as declared. |
| **B** — compiles, copies once at init | Accept if 2× peak fits the ceiling. Otherwise route generation through disk: build → serialize → drop → load into the immutable form. After first run that is the common path anyway, so the copy only costs on a cold cache. |
| **C** — no such conversion exists | Wrap the whole solve in one long-lived `region r`; tables stay `Array[Int8, r]`; search carries the region instead of being pure. |
| **D** — reads through the abstraction >2× slower than raw | Specialize `TableView` per backing, or accept and re-baseline Gate 7.6 **before** Stage 10 tunes against it. |

**Outcome C changes the architecture story, and that is acceptable.** The report
currently says search functions are pure with tables injected. Under C it says
search is scoped to the table region — still a real effect-system demonstration,
arguably a more interesting one, since the region then tracks a lifetime rather
than merely hiding mutation. What is not acceptable is discovering C at Stage 12
and having written the report as though A held.

---

## Stage 1 — Skeleton, packaging, fixtures, harness

**Deliverables**
- Flix project pinned to a specific compiler version (orbit64 uses 0.75.2).
  `flix.toml` per §2; no top-level `main`.
- Diamond check against `flix-cube`'s dependencies.
- Licence decision recorded; author confirmation requested (§4).
- **Fixture generation harness**: build the three reference jars locally,
  generate Tier 2 and Tier 3 fixtures, write headers per §6, check in.
- Tier 1 fixtures transcribed with provenance, including the block-to-table
  mapping above.
- Benchmark harness: fixed corpus, fixed seed, recorded machine/JDK/settings,
  **peak-heap** measurement.
- CI with per-job time caps. **CI depends on fixtures only, never on the jars.**
- **Region investigation and ADR (§7 *Table backing*).** Read the stdlib conversion source, ask
  the Flix maintainers, spike only what remains. Record the question, the Flix
  version tested, the three measurements, the outcome (A/B/C/D) and the decision
  as a dated ADR in the repository. Pin the version explicitly — a compiler
  release can change this, and a future contributor needs to know whether the
  finding still holds or must be re-run.

**Gate 1.1** — CI green on an empty library, no Java on the classpath.
**Gate 1.2** — Harness reproduces a number twice on the same machine.
**Gate 1.3** — Every fixture carries a complete header and verifies against its
digest.
**Gate 1.4** — Regeneration from the same reference commit and settings gives
byte-identical payloads.
**Gate 1.5** — Region ADR checked in, naming one of outcomes A–D, with peak-heap
figures obtained by `-Xmx` bisection at all three sizes.

---

## Stage 2 — Model, moves, ranking, validation, samplers

**Deliverables**
- `CubeSolve.Model.Coord`, `.Move`, `.Validate`, `.Random`.
- `CubeSolve.Model.Rank` — **adopt `Orbit64.Rank`** rather than rewriting.
- `CubeSolve.Model.OrbitDiscovery` — the Datalog derivation, below.

**Order matters inside this stage.** 4×4×4 and 5×5×5 validation cannot be
written until the orbit structure exists, so orbit discovery comes first.

### State sampling vs. scramble generation (F7)

Two distinct things, in two different stages:

- **Stage 2 produces a uniform legal *state*.** Sample coordinates, reject those
  failing the reachability invariants. Needs no solver.
- **Stage 9 produces a scramble *sequence*.** Take a Stage 2 state, solve it,
  emit the inverse. Needs a solver for that size.

### Random generation — two variants

```flix
def sampleDeterministic(seed: Int64, n: Int32): (Cube, Int64)   // pure
def sampleSecure(n: Int32): Cube \ IO                            // SecureRandom
```

The deterministic generator must use a **specified, in-library algorithm**
(SplitMix64 or similar). Do **not** call the platform default RNG: its output is
not guaranteed stable across JDK versions, which would silently invalidate every
checked-in fixture. Returning the next seed keeps it pure and threadable.

The differing effect signatures are a genuine demonstration of the effect
system, worth calling out in the architecture document.

### Orbit discovery

```
Same(x, y) :- Turn(x, y).
Same(x, y) :- Same(y, x).
Same(x, z) :- Same(x, y), Same(y, z).
```

Connected components of the "one turn carries this piece to that one" graph.
Cheap (218 surface pieces at 7×7×7), shares no code with the arithmetic version,
and catches real errors — an extra wing orbit fails at the 2×2×2, midges on even
cubes fails at the 4×4×4. **This is the Datalog showcase for the report.**

### Validation, split two ways

- *Is this a cube at all?* — `Orbit64.Coord.faultOf` names the broken rule.
- *Is this reachable by turning?* — per size:
  - **2×2×2**: twist sum ≡ 0 mod 3; no permutation parity constraint.
  - **3×3×3**: twist sum, flip sum, **coupled** corner/edge permutation parity.
  - **4×4×4**: corner twist sum; wing permutation parity **unconstrained**
    relative to corners.
  - **5×5×5**: midge flip sum, plus per-orbit invariants from discovery.

**Gate 2.1** — Discovery matches arithmetic `layout(n)` for n = 2..7.
**Gate 2.2** — `rank`/`unrank` round-trip both directions.
**Gate 2.3** — Validator accepts every random-walk state and rejects hand-built
violations of each invariant, with the correct reason.
**Gate 2.4** — Deterministic generator reproduces a checked-in sequence from a
fixed seed, asserted independent of JDK version.
**Gate 2.5** — Convention recorded: orbit64's `stateCount(3)` is exactly 2× the
classic 43,252,003,274,489,856,000 and `stateCount(4)` exactly 24× the classic
7.40 × 10⁴⁵, both to zero remainder.

---

## Stage 3 — Exact 2×2×2 BFS oracle

Fix the DBL corner; U, R and F suffice. **5040 × 729 = 3,674,160** states.

```
permutation coordinate:  7!  = 5040
orientation coordinate:  3^6 =  729
combined index:          permIndex * 729 + oriIndex
```

**Factored move tables.** `new_o[i] = o_old[cp_move[i]] + co_move[i]` depends
only on the move and on `o`, not on the permutation. Separate tables
(`5040 × nMoves`, `729 × nMoves`), not one of 3.6 million rows.

**Table width (F1).** Start with flat `Int8` — ~3.67 MB, simplest, no dependency
on Stage 8. Read it through `TableView` from the outset (§7 *Table backing*) so the Stage 8
migration is a backing swap rather than a rewrite of every call site. Migrate to `Packed4Table` (1,837,080 bytes) under Gate 8.4. Flix's
byte type is signed `Int8`; there is no `UInt8`. Mod-3 packing supports descent
only and **cannot represent 0–11**, so it is unsuitable for an oracle.

**Verified diameters** (independent BFS):

| generator set | states | diameter |
|---|---|---|
| all 9 HTM moves | 3,674,160 | **11** |
| U, U', R, R', F, F' (QTM) | 3,674,160 | **14** |
| U, R, F clockwise only | 3,674,160 | **19** |

Use the 9-move HTM set by default. Note the move-pruning caveat in §1 before
reusing the clockwise-only set.

### HTM distance histogram (F2)

Computed independently; this is Gate 3.4's expected value.

| d | states | share | cumulative |
|---|---|---|---|
| 0 | 1 | 0.000% | 1 |
| 1 | 9 | 0.000% | 10 |
| 2 | 54 | 0.001% | 64 |
| 3 | 321 | 0.009% | 385 |
| 4 | 1,847 | 0.050% | 2,232 |
| 5 | 9,992 | 0.272% | 12,224 |
| 6 | 50,136 | 1.365% | 62,360 |
| 7 | 227,536 | 6.193% | 289,896 |
| 8 | 870,072 | 23.681% | 1,159,968 |
| 9 | 1,887,748 | 51.379% | 3,047,716 |
| 10 | 623,800 | 16.978% | 3,671,516 |
| 11 | 2,644 | 0.072% | 3,674,160 |

Over 90% of states lie at d ∈ {8, 9, 10}. The concentration that makes 3×3×3
difficulty tuning hard is already visible here.

**On the Datalog version.** orbit64 ran this as a lattice rule
(`Dist(t; d+1) :- Dist(s; d), Move(s, t)`): it terminates, but **dies of heap
exhaustion at the JVM's 4 GB default after nearly five minutes and needs 12 GB
to finish in under three.** The bottleneck is the materialized `Move` relation,
not the result. Array BFS is primary; any Datalog version is gated out of CI.

That README reports "22 quarter turns," matching none of the three figures above;
its fact count (11,022,480 ÷ 3,674,160 = 3 per state) implies the clockwise-only
set, which measures 19. The experiment is not in the repository. **Do not quote
22 without re-deriving it.**

**Gate 3.1** — Reachable state count is exactly 3,674,160.
**Gate 3.2** — Exhaustive: `d(solved) = 0`; `|d(s) − d(move(s))| ≤ 1` for every
state and move; every non-solved state has a neighbour at `d − 1`.
**Gate 3.3** — Coordinate moves agree with model moves for every state and move.
**Gate 3.4** — Distance histogram matches the table above exactly.
**Gate 3.5** — Group laws: identity, inverse, `m⁴ = id`, opposite-face
commutation.

---

## Stage 4 — IDA\* differential testing against the oracle

**The diagnostic, stated correctly.** IDA\* returns an actual path, so its length
is always ≥ d\*(s) — it **cannot** return a shorter-than-optimal solution, and
the absence of one proves nothing. An inadmissible heuristic prunes the optimal
branch and returns a *longer* solution. Test both properties:

- **Admissibility**: `h(s) ≤ d*(s)` for all 3,674,160 states, exhaustively.
- **Optimality**: returned length `== d*(s)`.

**Heuristic choice.** The fixed-corner **729-state** orientation coordinate.

**Deliverables**
- `CubeSolve.Solve.IDAStar` — generic over a phase supplying `VALID_MOVES`, a
  successor function, a heuristic and a goal test. Reused unchanged by Stages 6,
  7, 11, 12.
- Preallocated search path; allocation-free hot loop; no clock reads inside it.

**Gate 4.1** — `h(s) ≤ d*(s)` exhaustively.
**Gate 4.2** — Returned length `== d*(s)` exhaustively.
**Gate 4.3** — Every returned solution replays to the identity.
**Gate 4.4** — Node counts drop measurably with move pruning enabled, and the
count is regression-tested.
**Gate 4.5** — Every failure preserves its seed and canonical state token.

---

## Stage 5 — 2×2×2 solver and exact-difficulty scrambler

First shippable feature; needs nothing beyond Stages 3 and 4.

**Deliverables**
- `CubeSolve.Solve.Pocket` — optimal 2×2×2 solver, table-driven, returning
  `Result`.
- `CubeSolve.Scramble.exactDistance(2, d)` — uniform sample from states at
  **exactly** distance d, for d ∈ 0..11.

### Sampling method (F3)

**Rejection sampling is not viable at the extremes.** Expected draws per accept,
from the histogram above:

| d | draws/accept | | d | draws/accept |
|---|---|---|---|---|
| 0 | 3,674,160 | | 6 | 73 |
| 1 | 408,240 | | 7 | 16 |
| 2 | 68,040 | | 8 | 4.2 |
| 3 | 11,446 | | 9 | 1.9 |
| 4 | 1,989 | | 10 | 5.9 |
| 5 | 368 | | 11 | 1,390 |

**Build a bucketed index instead.** One pass over the distance table writes each
state index into its distance bucket; sampling is then one uniform draw within a
bucket. Cost is 3,674,160 × 4 bytes ≈ 14.7 MB for a full `Int32` index.

To stay inside the 2×2×2's small memory budget, index only the sparse classes
(d ≤ 6 and d = 11, together 62,360 + 2,644 = 65,004 states ≈ 260 KB) and use
rejection sampling for d ∈ {7, 8, 9, 10}, where it costs ≤ 16 draws. Both paths
are exactly uniform; the choice is purely about cost.

**Gate 5.1** — Every solution optimal (Gate 4.2) and replays to the identity.
**Gate 5.2** — `exactDistance(2, d)` output has measured optimal length exactly
d, for every d ∈ 0..11.
**Gate 5.3** — Sampling within each distance class is uniform: chi-squared over
the bucket for sparse classes, and over a coarse partition for dense ones.
**Gate 5.4** — Invalid input returns `Result.Err` with the named fault.

---

## Stage 6 — Raw 3×3×3 phase 1

| coordinate | size | meaning |
|---|---|---|
| Twist | 2187 | orientation of the 8 corners |
| Flip | 2048 | orientation of the 12 edges (**11** free bits) |
| UDSlice | 495 | position of FL FR BL BR, without permutation among them |

**Raw pruning tables — all three.** Symmetry reduction compresses equivalent
states; it does not change pruning values. The raw heuristic loses information
only if a *table* is missing.

| table | size | bytes @ 1/entry |
|---|---|---|
| Twist × UDSlice | 2187 × 495 = 1,082,565 | ~1.1 MB |
| Flip × UDSlice | 2048 × 495 = 1,013,760 | ~1.0 MB |
| **Flip × Twist** | 2048 × 2187 = 4,478,976 | ~4.5 MB |

With all three and a max, the raw heuristic matches min2phase's strength;
symmetry becomes purely a memory-and-speed optimisation for Stage 10.

**Goal predicate**: Twist = 0, Flip = 0, UDSlice in its solved combination —
computed from decoded model state.

**Gate 6.1 (differential)** — Coordinate move tables diff entry-by-entry against
Tier 2 fixtures. Raw table depth histograms have **maximum depth 9**, matching
the symmetry-reduced values in §6; the symmetry-reduced versions must reproduce
the Tier 1 histograms exactly at Stage 10.
**Gate 6.2** — Phase-1 output verified in ⟨U, D, R2, L2, F2, B2⟩ by independent
model-state check.
**Gate 6.3** — Every phase-1 sequence replays to the asserted state.
**Gate 6.4** — Table generation deterministic across runs.

---

## Stage 7 — Raw 3×3×3 phase 2, integrated search, termination

**Phase-2 move alphabet — ten moves:** U, U', U2, D, D', D2, R2, L2, F2, B2.

| coordinate | size |
|---|---|
| CPerm | 40320 |
| EPerm | 40320 |
| MPerm | 24 |
| CComb | 140 |

**CComb, defined precisely:** 140 = 2 × 70, where 2 is the parity of all edges
(equivalently of all corners — coupled on a 3×3×3) and 70 = C(8,4) is the
unordered position of the URF / UFL / ULB / UBR **corner** tetrad. Fix and
document the tetrad ordering and parity convention.

**Raw phase-2 tables:** `CPerm × MPerm` = 967,680; `EPerm × CComb` = 5,644,800.
Expected maxima 14 and 13 respectively (§6).

**Integrated search.** Phase 1 produces a *stream*. Specify how many phase-1
solutions are enumerated (`PHASE1_SOLUTIONS 10000` is the reference analogue);
the budget split — a phase-1 solution of length L leaves `budget − L`, bounding
the phase-2 threshold; how candidates are ranked; when the search returns.

**Termination controls per §5**, with the defaults table. Exhaustion returns an
explicit error supporting resumption. Phase 2 never needs more than 18 moves.

**Gate 7.1 (differential)** — Phase-2 coordinate move tables diff against Tier 2
fixtures; pruning maxima are 14 and 13. Over the fixed corpus, every scramble
returns a replay-valid solution within the configured bound.
**Gate 7.2 (quality)** — Superflip returns 20 HTM **under explicitly documented
search settings**. Quality regression, not correctness: a probe-limited
two-phase solver may legitimately return more.
**Gate 7.3** — Exhaustion path exercised by a starved `probeMax`; returns the
documented error rather than hanging or lying. **Met**, and the two exhaustion
reasons are distinguished: out of probes can be answered with `withBudget`, out
of views cannot be answered by this scheduler at all.
**Gate 7.4** — `next()` never returns a longer solution than its predecessor.
**Met**, and structurally so: a view is capped at one move under the best in
hand, so `Improved` is unreachable except on an improvement. The test replays
every solution as well, because "never longer" is satisfied by a `next` that
returns the same answer forever.
**Gate 7.5** — Identical `probeMin`/`probeMax`/`maxDepth`/seed produces an
identical solution on two different machines.
**Gate 7.6** — Average length recorded over the fixed corpus, as Stage 10's
baseline. Compare *distribution* to Tier 3 fixtures; never diff solution strings.

---

## Stage 8 — Packed tables, cache, and fixture format

Ahead of the large cubes because Stages 11 and 12 cannot be built without it.

```
U8Table            flat Int8 payload, one entry per byte
Packed4Table       two entries per byte
Packed2Table       four entries per byte (mod-3 pruning; TPR's Edge3 packs
                   16 entries per Int32)
CheckedFlatIndex   Int64 multiply, range-checked, then narrowed to Int32
TableView          immutable read handle
CacheCodec         serialize / deserialize / verify — shared with fixtures
```

**Why this matters at scale.** `Array[Int32]` holding byte-width data multiplies
memory by four. At 5×5×5, builder storage, the immutable copy and the
serialization buffer can coexist; **peak heap** is what breaches the ceiling.

**Header** — magic; schema version; identifiers; move alphabet, order and metric;
slot and facelet convention; entry count; bit width; generator version; payload
length; byte order; digest. One codec serves caches and fixtures.

**Failure surface:** truncation, corruption, trailing bytes, incompatible schema
version, mismatched move alphabet, mismatched slot convention, interrupted
publication, concurrent first-run generation.

**On "byte-identical".** Applies to the **serialized payload**. Identical *solver
text* additionally requires fixed traversal and tie-breaking — a separate,
stronger property.

**Gate 8.1** — Round-trip byte-identical, every table width.
**Gate 8.2** — Every failure-surface case detected and reported.
**Gate 8.3** — `CheckedFlatIndex` rejects an out-of-range product.
**Backing decision (§7 *Table backing*).** Stage 1's ADR named an outcome; Stage 8 implements it.
Under **C**, revise the architecture document's purity claim here — not at Stage
12 — and re-check that Stages 11 and 12 ceilings still hold with a live region.

**Gate 8.4** — Stage 1 fixtures and Stage 3/6/7 tables migrated onto the shared
codec, Stage 3's oracle now `Packed4Table`, with gates 1.3, 3.x, 6.x and 7.x
still green.
**Gate 8.5** — `TableView` is the only path by which search reads a table; no
call site touches a backing array directly.
**Gate 8.6** — Under outcome D, Gate 7.6's baseline is re-measured and recorded
before Stage 10 begins.

---

## Stage 9 — Random-state scrambler (2×2×2 and 3×3×3)

**Scope (F6): this stage covers the sizes whose solvers exist.** 4×4×4 arrives
at Stage 11, 5×5×5 at Stage 12.

**Scrambles must be random-state, not random-move.** Sample uniformly from legal
states (Stage 2), solve, emit the inverse. A random move sequence is not uniform
over states and produces detectably biased scrambles.

### Four constructors

```flix
uniform(n)                  // WCA-style; the default
exactDistance(n, d)         // 2x2x2 only (Stage 5); Err otherwise
atLeast(n, d)               // certified lower bound; capped, see below
atMost(n, d)                // certified upper bound via solver
named(pattern)              // curated corpus
```

**`atLeast` is capped by the heuristic's maximum depth (F4).** Pruning tables
are admissible, so `h(s) ≤ d*(s)` — but `h` cannot exceed the table's own
maximum. From §6, all three 3×3×3 phase-1 tables max at **9**. So:

| size | `atLeast` ceiling | source |
|---|---|---|
| 2×2×2 | 11 | exact oracle, not a heuristic |
| 3×3×3 | **9** | max of UDSliceTwist / UDSliceFlip / TwistFlip |
| 4×4×4, 5×5×5 | per-phase table maxima, measured at Stages 11–12 | |

`atLeast(3, 15)` must return `Err`, not spin forever. Given that the mean 3×3×3
optimal length is ~17.7, a certified lower bound of 9 is weak — which is exactly
why `atMost` matters more.

**`atMost` is the constructor the concentration argument calls for (F5).** The
3×3×3 optimal-length distribution is extremely concentrated near 17–18, so "hard
random state" is essentially all states and difficulty variation lives at the
easy end. `atMost(n, d)` generates candidates and accepts one whose solver
result is ≤ d — an upper bound on d\*, certified by an actual solution. Generate
candidates by short random walks from solved: a k-move walk gives `d* ≤ k`, not
`= k`, because of cancellation and incidental shortcuts. **Document that**, or
users will file it as a bug.

**`named` needs a convention mapping (F9).** orbit64's curated table — Superflip,
Checkerboard, Four Spots, Six Spots, Cube in a Cube, Tetris, plus 4×4×4 stripes
and a 5×5×5 superflip — gives tokens and, for most, algorithms. But orbit64's
"Slot numbering" section is explicit that a token carries no geometry, and its
own test vectors are not established to share any particular labelling. Import
via the **algorithms** where given (unambiguous), and for token-only entries
establish and check in the slot mapping before use. The 5×5×5 superflip is
given as coordinates rather than an algorithm, so it needs the mapping.

**Cost.** A scrambler for size n pays that size's full table load, because
random-state scrambling *is* solving. There is no lightweight WCA-legal path.

**Gate 9.1** — `uniform(n)` output passes the Stage 2 reachability validator
every time, for n ∈ {2, 3}.
**Gate 9.2** — Scramble applied to solved, then solved again, returns to solved.
**Gate 9.3 (F8)** — Uniformity tested as **marginal chi-squared per coordinate**
— Twist over 2187, Flip over 2048, UDSlice over 495, CPerm and EPerm over
40320 — not as flatness over the full state space, which is untestable at
4.3 × 10¹⁹. The random-walk sampler must **fail** the same test, documenting why
random-state is required.
**Gate 9.4** — `atLeast(n, d)` output has measured `h ≥ d` and solution length
≥ d; `atLeast` above the documented ceiling returns `Err`.
**Gate 9.5** — `atMost(n, d)` output has a certified solution of length ≤ d.
**Gate 9.6** — Deterministic seeding reproduces an identical scramble across
machines and JDK versions.
**Gate 9.7** — Every `named` pattern round-trips: apply, solve, verify the
resulting state matches the pattern's recorded token under the checked-in
convention.

---

## Stage 10 — 3×3×3 symmetry and search optimisation

One measured change at a time, against Gate 7.6's baseline.

**10a — symmetry reduction.** Twist 2187 → 324, Flip 2048 → 336, CPerm and
EPerm 40320 → 2768, giving min2phase's five tables (sizes, maxima and averages
in §6).

**10b — search refinements** above plain two-phase: three phase-1 target axes
(⟨U,R2,F2,D,L2,B2⟩, ⟨U2,R,F2,D2,L,B2⟩, ⟨U2,R2,F,D2,L2,B⟩); solving the inverse
state simultaneously; pre-scramble — if
`PreMoves · Scramble · Phase1 · Phase2 = Solved` then
`Solution = Phase1 · Phase2 · PreMoves`.

**10c — JVM shape.** Phase-specialized IDA\* kernels permitted where callback
inlining fails, justified by measurement.

**Gate 10.1** — Each change benchmarked independently against Gate 7.6.
**Gate 10.2 (differential)** — Symmetry-reduced tables reproduce the Tier 1
histograms **entry for entry**, with maxima 14, 13, 9, 9, 9 as decoded in §6.
Average length at matched probe settings within a documented margin, measured
against a **locally built min2phase on the same machine, JDK and corpus**.
**Gate 10.3** — Gates 7.1–7.5 and 9.1–9.7 still green.

---

## Stage 11 — 4×4×4 three-phase reduction

Reference is a **Three-Phase-Reduction** solver based on **Tsai's 8-step 4×4×4
algorithm**: it merges Tsai's steps 3 and 4 and substitutes min2phase for steps
5–8. Cite it that way.

### Parity

Parity repair after reduction is a legitimate architecture. **This project
carries parity inside the phase coordinates instead**, to match the reference
and make an illegal handoff structurally impossible:

- `Center2.java` — `int parity` field; index is `idx * 2 + parity`; `pmv[]`
  flips it per move.
- `Center3.java` — `this.parity = parity ^ eXc_parity`.
- `Search.java` — `ct2.set(c1.getCenter(), c1.getEdge().getParity())`, then
  `ct3.set(centre, eparity ^ corner.getParity())`.
- cube555's `Phase2Search` — `EParityMove[2][...]`.

Choosing repair instead is defensible; choosing it *late* is not.

| structure | size |
|---|---|
| Center1 raw / sym classes | 735,471 / 15,582 over 36 moves |
| Center2 | `rlmv[70][28]`, `ctmv[6435][28]`, prun `6435 × 35 × 2` |
| Center3 | move and prune tables of `35 × 35 × 12 × 2` |
| Edge3 | `N_SYM 1538 × N_RAW 20160` = 31,006,080 entries, 2 bits, `MAX_DEPTH 10` |

**Reference budgets:** `PHASE1_SOLUTIONS 10000`, `PHASE2_ATTEMPTS 500`,
`PHASE2_SOLUTIONS 100`, `PHASE3_ATTEMPTS 100`.

**Reference targets:** average **44.39 moves** FTM, **250 ms**, **≤ 30 MB**,
init 6–7 s with ~20 MB cached. Distribution spans 40–47, peaking at 45.

**Declared ceiling (F11): 60 MB peak heap**, twice the reference's retained
figure to allow builder, immutable copy and serialization buffer to coexist.

**Handoff contract.** Phase 3 guarantees full virtual-3×3×3 legality including
coupled parity, verified from decoded model state.

**Gate 11.1** — Independent invariant after each phase, from model state.
**Gate 11.2 (differential)** — Per-phase intermediates diff against Tier 2
fixtures. This isolates a parity bug to the exact scramble that triggers it.
**Gate 11.3** — Over thousands of scrambles, **no reduced state is ever rejected
by the 3×3×3 solver**. A single rejection is a phase-coordinate bug, not a retry
case.
**Gate 11.4** — Length distribution compared against the Tier 1 TPR figures.
**Gate 11.5** — Peak heap ≤ 60 MB, measured by `-Xmx` bisection (§7 *Table backing*).
**Gate 11.6** — Cached and freshly generated payloads byte-identical.
**Gate 11.7** — `Scramble.uniform(4)` and `atLeast(4, d)` operational, with the
4×4×4 `atLeast` ceiling measured and documented.

---

## Stage 12 — 5×5×5 five-phase reduction

cube555 is a genuine five-phase reduction with **no canonical published name** —
describe your decomposition, do not cite one. All five phases share
`PhaseSearch.idaSearch`, each with its own `VALID_MOVES`, `SKIP_MOVES`,
`NEXT_AXIS` and `MIN_BACK_DEPTH`.

| phase | key coordinates |
|---|---|
| 1 | TCenter 735,471 → 46,935 sym; XCenter 735,471 → 46,371; `MIN_BACK_DEPTH 5` |
| 2 | TCenter 12,870; XCenter 12,870; EParity 2; `MIN_BACK_DEPTH 5` |
| 3 | WEdge 2,704,156 → 86,048 sym; MEdge 2048; Center 1225 |
| 4 | MEdge 70; HEdge/LEdge 70 × 1680; MLEdge → 29,616 sym; UDCenter 4900; RLCenter 216 |
| 5 | LEdge 40,320 → 5288 sym; Center 70 × 70 × 36 |

**Reference targets:** average **51–52 moves for reduction**, **1–2 seconds**,
**≤ 500 MB**, ~**240 MB** cached on first run.

**Declared ceiling (F11): 700 MB peak heap.** The reference's 500 MB is a
retained figure; builder storage, the immutable copy and the serialization
buffer can coexist during generation. If the Stage 8 zero-copy spike showed a
copy, revisit before committing.

**Deliverables** — one milestone per phase: a named module
(`CubeSolve.Solve.Five.Phase1` … `Phase5`), a goal predicate over model state, a
named independent invariant, its own tables via Stage 8 primitives, and a
handoff contract to the next phase — and for phase 5, to the 3×3×3 solver.

The orbit decomposition — `mEdge`, `wEdge`, `xCenter`, `tCenter` — is the same
one orbit64 derives independently from geometry.

**Gate 12.1** — Each of the five phases passes its named invariant, from model
state.
**Gate 12.2** — Per-phase coordinates diff against Tier 2 fixtures.
**Gate 12.3** — No phase-5 output is ever rejected downstream.
**Gate 12.4** — Pruning histograms match Tier 1 `PruningValue.txt` per phase.
**Gate 12.5** — Average reduction length within a documented margin of 51–52.
**Gate 12.6** — Peak heap ≤ 700 MB with all three buffers coexisting, measured
by `-Xmx` bisection (§7 *Table backing*).
**Gate 12.7** — `Scramble.uniform(5)` operational, its table-load cost documented
in the API, and the 5×5×5 superflip `named` pattern round-tripping under the
checked-in slot mapping.

---

## Stage 13 — Release qualification

**Deliverables**
- Provenance: every table's generator version and digest; every fixture's source
  repo and commit.
- Cross-platform: payloads byte-identical across OS and JDK, or divergence
  documented and the digest scheme adjusted.
- Reproducible benchmark report: machine, JDK, corpus, search settings, and both
  the Flix and reference numbers from the same box.
- API documentation via `flix doc`; the state-count convention; per-size default
  budgets; the `atLeast` ceilings; the `atMost` walk-length caveat.
- Attribution file per §4.
- Integration check: `flix-cube` consumes the published package without name
  collisions or a diamond conflict on orbit64.

**Gate 13.1** — Clean clone builds and passes every gate on a machine that has
never generated a table and has no Java toolchain.
**Gate 13.2** — Concurrent first-run generation by two processes produces one
valid cache. **Met.** `scripts/qualify-cache-race.sh` builds a fatjar whose entry
point is `test/QualifyCacheRace.flix`, starts two child JVMs on one directory
that has never existed, and reads the result back through the cache with
rebuilding refused. Two processes, not two threads: a `@Test` runs in one JVM and
so cannot reach this. `TestCacheOnDisk.twoThreadsRacingOnOneDirectoryLeaveOne`
`ValidCache` is the cheap per-commit regression test and is named for what it is.
The gate was also run with the old shared staging name restored, and passed —
see the design review for what that says about it.
**Gate 13.3** — A consumer importing both `cubesolve` and `orbit64` compiles,
with no top-level `main` conflict.

---

## Cross-cutting: testing

- **Exhaustive where the space permits** — all 3,674,160 2×2×2 states for the
  oracle, admissibility, and coordinate-vs-model move agreement.
- **Differential against fixtures** for everything the reference also computes.
- **Round-trip.** Every solution replays to the identity.
- **Both rank directions.**
- **Group laws**: identity, inverse, `m⁴ = id`, opposite-face commutation.
- **Phase-boundary invariants from decoded model state.**
- **Two sampling regimes, named**, with the random-walk sampler required to fail
  the uniformity test that `uniform` passes.
- **Determinism across machines** for any fixed seed and budget.
- **Failure reproducibility.** Every failure preserves its seed and canonical
  state token.
- **Two independent derivations** wherever available.

---

## Cross-cutting: Flix and JVM

- Flat primitive arrays, never nested. `Array` inside a `region`, returned
  immutable — not `MutList`.
- Search reads tables through `TableView`; `IO` at the program edge only. Whether
  the handle is pure or region-scoped follows from §7 *Table backing*'s outcome.
- Checked `Int64` multiply before narrowing to an `Int32` index. JVM arrays are
  `int`-indexed: 2³¹−1 elements is a hard cap.
- Preallocated search path; allocation-free hot loop; no clock reads inside it.
- Phase-specialized IDA\* kernels where callback inlining fails, justified by
  measurement.
- Measure **peak heap**, not retained size.

**Table backing — investigated at Stage 1, decided at Stage 8.** See §7 *Table backing*. Region
non-escape does **not** imply zero-copy conversion to an immutable table; that
is a hypothesis under test, not a documented fact. `TableView` keeps the
question from blocking anything, and the four pre-committed outcomes keep it
from ending ambiguously.

orbit64 (Flix 0.75.2) is a working syntax reference for `inject xs into Turn/2`
and `query facts, rules select (x, y) from Same(x, y)`.

---

## Appendix A — verified reference figures

| cube | states (classic convention) |
|---|---|
| 2×2×2 | 3,674,160 |
| 3×3×3 | 4.33 × 10¹⁹ |
| 4×4×4 | 7.40 × 10⁴⁵ |
| 5×5×5 | 2.83 × 10⁷⁴ |

| cube | reference | avg length | time | memory | init |
|---|---|---|---|---|---|
| 2×2×2 | this plan | 11 (optimal) | — | 1.84 MB packed | seconds |
| 3×3×3 | min2phase | 20.63 @ probeMin 5 | 0.83 ms | ~1 MB | 195 ms |
| 4×4×4 | TPR-4x4x4 | 44.39 FTM | 250 ms | ≤ 30 MB | 6–7 s, 20 MB cached |
| 5×5×5 | cube555 | 51–52 (reduction) | 1–2 s | ≤ 500 MB | 240 MB cached |

## Appendix B — claims not to repeat

From the earlier artifact set:

- 5×5×5 has 10⁴⁰ states — it is 2.83 × 10⁷⁴.
- 2×2×2 has 264 million states — that is 7! × 3⁷ × 24. Correct: 3,674,160.
- "More configurations than particles in the known universe" — false for the
  5×5×5 (2.83 × 10⁷⁴ vs ~10⁸⁰).
- "Pruning tables usually under a megabyte" — true only for the 3×3×3.
- Tail-call elimination prevents IDA\* stack overflow — wrong three ways.
- Solving 5×5×5 centres "reduces to 4×4×4 complexity" — it targets the 3×3×3.
- Datalog after min2phase in the pipeline — nothing remains to compute.
- `CoordCube` fields as `Array[Int32, r]` — coordinates are scalar integers.
- Edge orientation as 12 free bits — it is 11.

From earlier drafts of this plan:

- `permIndex * 2187 + oriIndex` — valid but sparse; use the dense 729
  coordinate. Diameters computed under it remain correct.
- "An inadmissible heuristic yields a shorter-than-optimal solution" — it cannot.
- "Skipping symmetry weakens the heuristic" — a missing *table* weakens it.
- CComb's tetrad described as edges — they are corners.
- "Never `R` after `R`" as a universal rule — generator-specific.
- Coupled corner/edge parity as a generic reachability check — 3×3×3 only.
- Superflip = 20 as a correctness gate — it is a quality gate.
- 2-bit mod-3 packing for the 2×2×2 oracle — that table needs absolute
  distances.
- "Fixtures avoid GPL obligations" — the references are dual-licensed; the MIT
  grant is available directly.
- "This is clean-room reverse engineering" — it is not.
- Root module `Cube` — collides with `flix-cube`. Use `CubeSolve`.
- Time-bounded solving as a CI gate — bound by probes.
- Random-move scrambling — not uniform; use random-state.
- `atLeast(3, d)` for arbitrary d — capped at 9 by the phase-1 tables.
- Rejection sampling for `exactDistance` at small d — 3.7 million draws at d=0.
- "Flix converts a region array to immutable without a deep copy" stated as
  fact — it is a hypothesis (§7 *Table backing*), from the same source that put the 5×5×5 state
  space at 10⁴⁰.
- "Search functions are pure with tables injected" asserted before §7 *Table backing* resolves —
  true under outcomes A and B, false under C.
