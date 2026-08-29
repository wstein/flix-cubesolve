# flix-cubesolve

[![Build and Test](https://github.com/wstein/flix-cubesolve/actions/workflows/build-and-test.yaml/badge.svg)](https://github.com/wstein/flix-cubesolve/actions/workflows/build-and-test.yaml)
[![Flix](https://img.shields.io/badge/dynamic/toml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fwstein%2Fflix-cubesolve%2Fmain%2F.flixw%2Flock.toml&query=%24.compiler.version&label=flix&color=blue)](.flixw/lock.toml)
[![flixw](https://img.shields.io/badge/dynamic/toml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fwstein%2Fflix-cubesolve%2Fmain%2F.flixw%2Flock.toml&query=%24.wrapperVersion&label=flixw&color=blue)](https://github.com/wstein/flixw)
[![Java](https://img.shields.io/badge/java-21%2B-blue)](https://adoptium.net/temurin/releases/?version=21)
[![License](https://img.shields.io/github/license/wstein/flix-cubesolve?color=blue)](LICENSE)

A solving and scrambling engine for n×n×n twisty cubes in [Flix](https://flix.dev),
2×2×2 through 5×5×5.

This is a **library**. It declares no top-level `main`, so a program can depend
on it; everything it defines nests under `CubeSolve`, so nothing it defines
collides with a consumer's names.

## Status

Under construction. What works today:

| | 2×2×2 | 3×3×3 | 4×4×4 | 5×5×5 |
|---|---|---|---|---|
| model, moves, notation | ✅ | ✅ | — | — |
| slice, wide and rotation notation | rotations only | ✅ | — | — |
| reachability validation | ✅ | ✅ | — | — |
| uniform random state | ✅ | ✅ | — | — |
| exact distance oracle | ✅ | — | — | — |
| solving | ✅ optimal | ✅ two-phase, mean 20.4 | — | — |
| random-state scrambling | ✅ | ✅ | — | — |
| exact-difficulty scrambling | ✅ | n/a | n/a | n/a |
| bounded-difficulty scrambling | ✅ | ✅ | — | — |
| table caching between runs | ✅ | ✅ | — | — |

Exact-difficulty scrambling is marked `n/a` above rather than missing: it needs
the whole distance table in memory, which only the 2×2×2 admits. Larger cubes
can certify *bounds* but not an exact distance, which is what the
bounded-difficulty row is — every 3×3×3 scramble carries an upper bound
certified by a real solution and a lower bound from the pruning tables.

`CubeSolve.supportedSizes()` reports this at runtime and is covered by a test
that builds and turns every size it lists, so the list cannot drift ahead of the
implementation. The rest of this README describes the engine being built.

## What it will do

- **Solves.** An exact optimal solver for the 2×2×2, and a two-phase solver for
  the 3×3×3. Larger sizes reduce to the 3×3×3.
- **Scrambles from random state, not random moves.** A uniformly random move
  sequence is *not* uniform over states and produces detectably biased
  scrambles. This samples a legal state uniformly, solves it, and emits the
  inverse — which is why scrambling costs the same as solving.
- **Says why it refused.** Every public entry point returns `Result`. An invalid
  cube comes back as `Err("the corner twists must sum to 0 mod 3")`, never as a
  bare `None` and never as a silently wrong answer.

## Quick start

```sh
./flixw check        # type-check; the fast feedback loop
./flixw test         # run every @Test function under test/ (4 to 5 minutes;
                     #   see Testing below for what costs what)
./flixw doc          # API documentation for this project and the stdlib
./flixw metrics --format md   # code-smell report; run it before committing
```

The only prerequisite is a JDK, Java 21 or newer. You do not need Flix
installed: the first command downloads `flix.jar` for the version pinned in
`.flixw/lock.toml`, checks it against the SHA-256 committed alongside it, caches
it outside the repository, and runs it. Later commands reuse the cache. On
Windows use `.\flixw.cmd`.

`./flixw run` is not available here and that is not a defect — see
[Why there is no `main`](#why-there-is-no-main).

## Two representations, kept apart

The single most important thing to understand about this codebase is that cube
state exists in two forms, and they are deliberately not interchangeable.

| layer | representation | what it is for |
|---|---|---|
| **model** | permutation and orientation vectors, one per orbit | validation, tests, I/O, phase-boundary checks |
| **search** | scalar `Int32` coordinates | `newCoord = table[coord * nMoves + move]` |

A search doing tens of millions of successor steps cannot afford to touch a
vector, so it works in integers. But an integer cannot tell you *why* it is
invalid, and a search bug that corrupts a coordinate would happily validate
itself if you asked the coordinate about it. So every phase boundary is checked
against the **decoded model state**, never by rereading the coordinate the
search just wrote.

Conversions between the two are explicit and property-tested in both
directions. See [`docs/architecture.md`](docs/architecture.md).

## Conventions, and why they are written down

A cube token stores ordinals and no geometry. Relabelling slots by any bijection
preserves every invariant and changes only the encoding — so a table, a fixture
or a test vector without its convention recorded pins nothing at all.

Every convention this engine assumes is stated in
[`docs/conventions.md`](docs/conventions.md) and carried in the header of every
generated table. The load-bearing ones:

- **Slot-indexed permutations.** `p[i]` is the piece sitting in slot `i`; the
  solved cube is the identity. The alternative reading — `p[i]` is the slot
  holding piece `i` — is the inverse permutation, equally defensible, and
  catastrophic if the two are mixed.
- **Composition order.** `(a · b)[i] = a[b[i]]`.
- **Orientation reference frames.** Twist and flip are meaningless without a
  chosen primary facelet per slot and per piece.

## Relationship to `flix-orbit64`

```
flix-cube        interactive simulation and workbench   ← application
     │ depends on
flix-cubesolve   solving and scrambling  (this repo)    ← engine
     │ depends on
flix-orbit64     canonical state encoding               ← external
```

[`flix-orbit64`](https://github.com/wstein/flix-orbit64) supplies the orbit
decomposition, the ranking functions and the "is this a cube at all?" validator.
This package supplies "is this reachable by turning?", the moves, and the
search. The split is not arbitrary: the first question is about *encoding* and
the second is about *the group*, and they have different answers per cube size.

One thing orbit64 deliberately does not model, and this engine must: an odd
cube's six fixed centres. orbit64 treats them as the reference frame rather than
as state, and `fromFacelets` refuses any cube whose fixed centres have moved. A
codec may do that. A solver may not — users paste scrambles containing `M`,
`E`, `S`, `x`, `y`, `z`, and WCA 4×4×4 and 5×5×5 scrambles use wide turns that
move centres relative to the frame. So the model here carries a **whole-cube
orientation** alongside the orbits, and the API boundary normalises into the
canonical frame, solves, and re-expresses the answer in the frame it was given.

## Layout

```
.
├── src/CubeSolve.flix            the root module and its documentation
├── src/CubeSolve/               engine sources, mirroring the module tree
├── test/                        @Test functions, flat, one TestX per subject
├── docs/
│   ├── architecture.md          the layering, and why the layers are separate
│   ├── conventions.md           every convention the engine assumes
│   ├── design-review.md         the v6 plan review and its amendments
│   └── adr/                     dated architecture decision records
├── ATTRIBUTION.md               provenance and licence of every borrowed part
├── flix.toml                    package metadata; the lowest Flix version accepted
└── .flixw/lock.toml             the exact compiler and its SHA-256
```

`flix.toml` states a *floor* and `.flixw/lock.toml` states the *pin*. Any pin at
or above the floor satisfies it, and `./flixw validate` fails when the pin does
not, so the two cannot drift apart unnoticed.

## Testing

Cube code fails in ways that unit tests on hand-picked examples do not catch, so
the strategy is stated explicitly in
[`docs/architecture.md`](docs/architecture.md#testing-strategy). In short:

- **Exhaustive where the space permits.** All 3,674,160 2×2×2 states, for the
  oracle's self-consistency and for heuristic admissibility.
- **Stratified where it does not.** Where an exhaustive sweep would take an
  hour, test every state in the small distance classes and a fixed-seed sample
  of the large ones, rather than quietly testing nothing.
- **Round-trip.** Every solution replays to the identity. Every rank round-trips
  in both directions.
- **Group laws.** Identity, inverse, `m⁴ = id`, opposite-face commutation.
- **Two independent derivations** wherever one is available.
- **Against published algorithms.** 199 patterns from four collections ship in
  `CubeSolve.Patterns`, and the solver is measured against every one that
  documents a half-turn move count.

The suite takes **four to five minutes** — 233 s, 255 s and 328 s on three runs
of identical code, so treat any single figure as approximate. Almost all of it
is a handful of tests that either *run the solver* or *build a table*:

| test | cost |
|---|---|
| `TestPatternBoundsFast` — 27 pattern solves | ~40 s |
| `TestPatternBoundsExhaustive` — all 110 | ~80 s, **off by default** |
| `TestTwoPhase`, `TestScrambleStandard` | ~30 s each |
| `TestDomino`, `TestStandard` — table sweeps | 20 s, 16 s |
| everything else, including both fixture sweeps | under 10 s |

The corpus sweeps are cheap and easy to misjudge: re-recording all 199 patterns
from all 24 orientations costs **0.14 s and 0.05 s**. Solving is what is slow, and
it is slow wherever it appears.

The full 110-pattern gate is therefore stratified rather than dropped. 27
patterns run everywhere, chosen by stated rules — both named hard cases, every
pattern the solver already loses by four moves or more, two per published-length
band, two per source, the slice-notation ones, and both extremes. The other 83
run on main, nightly, and before a release:

```sh
CUBESOLVE_EXHAUSTIVE=1 ./flixw test
```

Skipping it says so out loud rather than passing in silence.

There is no formatting gate: the pinned compiler's `format` has no check-only
mode, so run `./flixw format` before you commit.

## License

Apache-2.0. See [LICENSE](LICENSE), and [ATTRIBUTION.md](ATTRIBUTION.md) for the
provenance of anything not written here.
