# Architecture

## The layers

```
CubeSolve.Model      pieces, moves, validation, sampling
CubeSolve.Table      packed lookup tables behind one read handle
CubeSolve.Solve      IDA*, phases, per-size solvers
CubeSolve.Scramble   random-state scrambling, over Solve's public API only
CubeSolve.Method     human methods: recognise a partial state, play an algorithm
CubeSolve.Patterns   the published pattern corpora, and recognising one
CubeSolve.Render     a cube drawn as an unfolded net, plain or coloured
```

The command line is not a layer of the library at all — see below.

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

## Turning a cube bigger than a 3x3x3

The 2x2x2 and 3x3x3 turn through per-orbit move tables. Everything larger turns
through `CubeSolve.Model.Stickers`, which unfolds the cube, spins one face,
cycles four strips and folds it back.

**The geometry is uniform in `n`, which is the whole argument for it.** A 4x4x4
adds wing and centre orbits, a 5x5x5 adds more; writing move tables for each is
work the geometry does not need, because neither rule mentions the size. The
price is two conversions per move, paid in the model layer, where no search ever
looks.

**Nothing independent exists to check a 4x4x4 against**, so the check is that the
same formula reproduces the sizes that are already trusted:
`TestStickers.theStickerGeometryAgreesWithTheOrbitTables` runs all eighteen face
turns against the orbit tables at both sizes, on the solved cube and a fixed
sample of random ones. It passed first time; had a strip been read backwards it
would have named the move and the seed. The group laws and a scramble-and-inverse
round trip then run at all four sizes.

### Turnable is not solvable

`CubeSolve.supportedSizes` answers what can be solved and `turnableSizes` what
can be turned, and the second is deliberately the weaker claim: a turnable size
can be built, moved by any face, drawn and round-tripped through facelets, and
need not be validatable, samplable, scramblable or solvable.

Keeping one list for both is what made the command line refuse to draw a 4x4x4
it could draw perfectly well. The command line now names which capability each
command needs -- `Turning`, `Solving` or `Corpus` -- and the refusal names the
one that is missing. Those are three questions, not two: `identify` and
`patterns` want a published collection rather than a solver, and telling their
caller "no solver" would be the same category error in a new place.

### What larger cubes still cannot do

`after`, `inverse` and `conjugate` refuse any cube with a centre orbit, and
`Result` is how they say so.

Centres are held as a multiset of colours rather than as a permutation of pieces,
because the four centres of a face are interchangeable and pretending otherwise
would make equal cubes compare unequal. Composition needs to know where the
right-hand state sent each slot; a list of colours does not say, and nothing
recovers it. Turning is unaffected — a turn is geometry, not composition.

Both of these were silent before, and neither was reachable until a large cube
could be turned. `afterOrbit` returned its left operand for wing and centre
orbits, and `asState` built a two-orbit rotation that `List.zip` then silently
truncated a three-orbit cube against. A refusal is the answer; a plausible cube
is not.

## The command line

**Not part of this library at all.** Flix allows one `main` per program, so a
library that ships one at the top level cannot be depended on — the command
line lives in `examples/cli-tool`, a separate package with its own `flix.toml`
depending on the *published* `cubesolve` exactly as any other consumer would.
That is a stronger claim than a fatjar with `--entrypoint` ever made: it is
proof a released build resolves and runs, not only that the source compiles.

It is split the same way it always was, unmoved by the extraction: `Main`
dispatches and prints, `Args` turns arguments into a cube, `Engine` runs the
solver and `Corpus` reads the pattern collections. `Store` resolves the cache
directory, so the commands can ask for a cache without also acquiring the
filesystem — `Table.Cache` goes to some length to stay free of `IO` and a
caller that reaches for `Fs` alongside it throws that away.

**It is the only real user of the table cache.** The tests build tables so that
they measure building. A person at a terminal waits once: measured cold at 21 s
and warm at 1.2 s on the same machine, which is what the cache exists for and
what nothing else in the repository demonstrates.

See `examples/cli-tool/README.md` for running it, and `./flixw examples run
cli-tool -- <args>` from the root for the short form.

Rendering is pure, including the colours. An ANSI escape is a string like any
other, so `CubeSolve.Render` produces text and printing it is somebody else's
effect — which is why the coloured net can be tested by stripping the escapes and
comparing against the plain one. The colours are 24-bit rather than the sixteen
basic ones for one reason: there is no orange among the sixteen, and orange
against red is the one distinction a cube renderer cannot afford to lose.

## Anytime solving

`solution` answers once and settles. `start`, `next` and `withBudget` are the
same search with the loop turned inside out: the caller takes the first answer,
looks at it, and decides whether to pay for a shorter one.

**One view loop, two stopping rules.** `stepOnce` searches exactly one view and
is the only place a view is run, so the two entry points cannot drift into
searching differently. `solution` stops at the `probeMin` floor — there is an
answer and enough has been spent looking for a better one. `next` has no floor:
a caller asking for a better answer has said what it wants by asking, and stops
when it stops.

**Each answer is strictly shorter than the last**, and that is structural rather
than checked afterwards. A view is capped at one move under the best in hand, so
anything it returns is an improvement and `Improved` is reachable no other way.
Views that find nothing better are searched and passed over silently: one call
may cost several of them.

**Exhaustion says which kind it is.** Out of probes is answerable — `withBudget`
offers every view again under a larger allowance, keeping the best already found
so the answer cannot get worse. Out of views is not: the six views are this
scheduler's whole search space, and more probes alone will not change what it
can reach. A single "exhausted" would have hidden that difference.

## Human methods

`CubeSolve.Method` answers a partial state the way a person does. Two kinds of
step live there and they are not the same kind of thing:

- **Algorithm steps** — OLL, PLL. A constrained state is recognised and a
  memorised sequence played back. These need a corpus.
- **Search steps** — the cross. There is no case list to look up: the four
  edges can be anywhere, so it is solved by searching, and the answer is
  optimal rather than memorised.

The cross is the first of the second kind. Its coordinate tracks four edges and
nothing else -- 190,080 states -- which is small enough to tabulate the exact
distance to solved for every one. An IDA* with an exact heuristic expands only
nodes on an optimal path, so the first answer found is a shortest one.

**No move table.** A successor is four slot lookups; a table to avoid that would
be thirteen megabytes to save a dozen array reads. The two-phase solver's tables
exist because its successors are the hot loop of a search running tens of
millions of steps; this one runs a few thousand.

**The first layer combines two exact tables.** The cross has 190,080 states and
the four bottom corners 136,080, and each holds the true distance to solved.
Neither alone bounds the pair, but the larger of the two always does — a
sequence finishing both is at least as long as one finishing either — so IDA*
over the packed pair searches with an admissible heuristic. It is the
construction phase one of the two-phase solver uses, at a size where both
projections happen to be exact rather than merely admissible.

Measured over 25 uniform random states: **mean 9 moves, worst 11**, with the
bottom corners never more than 7 from home. That is the number that mattered
before committing to the rest of the ladder — a staged solver emitting 150-move
answers would be correct and useless for teaching. The suite asserts the worst
case on a named six-seed stratum, because each search costs seconds.

The search is bounded at 16 moves and **reports failure rather than guessing**
if a state needs more.

**The cross is fixed on `D`.** Which face carries it is method policy rather
than arithmetic, and fixing it keeps one coordinate rather than six. A caller
wanting another face turns the cube first.

`CubeSolve.Solve` answers any cube by searching. `CubeSolve.Method` answers one
particular partial state the way a person does: recognise it, then play back an
algorithm that was memorised for it. These are different products, and neither
is a better version of the other — a method answer is longer than a searched one
and is not offered as a solution to an arbitrary cube.

**Two namespaces, and the split is real.** A step that *searches* lives in
`CubeSolve.Solve` beside the general solver, because it is one — `Solve.Cross`
and `Solve.FirstLayer` are IDA* over coordinates and tables, and differ from
`Solve.Standard` only in what they aim at. A step that *recognises and replays*
lives in `CubeSolve.Method`, because a corpus lookup is a different kind of
thing. `Method.Beginner` names the stages either kind can reach.

So the first steps of CFOP are `Solve.Cross` and `Solve.FirstLayer`, and the last
two are `Method.Oll` and `Method.Pll`. `CubeSolve.Method.lastLayer` runs those two together and returns the
answer as **stages** rather than one sequence, which is the shape a method
explanation needs: which step, which case, which moves, and what it cost.

**A step that is not needed is a stage with no moves**, not an absent one. A last
layer that arrives oriented has no OLL case and one that arrives solved has no
PLL case; both are welcome and both are reported, because a reader given two
stages where they expected three should be told which went and why.

`CubeSolve.Method.Plan` is the written form of a staged answer, and the one
people already write by hand:

```
Scramble: R U R' U' F2 L D B'

y // Inspection
D' L' // Cross
// OLL skip
R U R' U' R' F R2 U' R' U' R U R' F' // PLL: T-PLL
```

`//` is what it writes and both `//` and `#` are accepted when reading. Three
rules make it safe to hand around:

- **A rotation is a move, not a note.** `y` above is a `Frame` operation and
  stays one, because it changes how every later move name resolves. `Plan.ops`
  is the flattened sequence a replay runs, and it is checked against the same
  moves applied directly.
- **`Scramble:` is context.** It is shown above the plan and never joins the
  moves — concatenating it would return a sequence that scrambles the cube
  before solving it.
- **A label is part of the contract.** A step is labelled with the case a method
  actually recognised, checked from decoded model state. It is not decoration,
  and a step must not claim a name it has not established.

`CubeSolve.Model.Notation` stays strict and flat and knows nothing about any of
this: it parses algorithms, `Plan` parses documents.

F2L, which joins the cross to the last layer, is not implemented, so the method
cannot yet answer a whole cube.

**The goal of one step is the precondition of the next**, and they share the
predicates that say so. `Method.LastLayer` answers "are the first two layers
solved" and "does the last layer show the top colour"; OLL finishes exactly when
both hold, which is exactly when PLL may begin. Writing that twice would let the
two drift, and a step disagreeing with its neighbour about where it ends would be
hard to see. A test asserts the join directly: solving any OLL case leaves a cube
PLL accepts.

**OLL takes a setup turn only, where PLL takes two.** A `U` turn cannot change
whether a piece shows the top colour, so once the layer is oriented it stays
oriented however it is spun; where the pieces end up is PLL's business.

**The precondition is decided from decoded model state.** A cube is a PLL case
when the first two layers are solved and the last layer is oriented; that is a
question about pieces in slots, so it is asked of the orbit vectors and not of a
coordinate or a facelet.

**AUF is part of the answer, and is found rather than derived.** The same case
arrives turned any of four ways and its algorithm assumes one, so recognition
reports a `U` turn to make before and one after. It finds them by trying all
21 cases against all sixteen pairs and replaying: an answer is returned only
after it has been applied to the cube in hand and seen to solve it. That costs
less than a case index and cannot be subtly wrong.

**Several algorithms per case, and a profile picks.** `Method.Profile` offers
three stated rules: `default` takes the source's first, `shortest` the fewest
parsed layer turns, and `no-rotations` the first free of whole-cube rotations.
The metric is called *fewest parsed layer turns* rather than fastest or even HTM,
because rotations are deliberately not counted and how long a person takes is not
a property of the sequence.

A rule that cannot be applied says so. `no-rotations` falls back to the source's
first where no rotation-free variant is recorded, and reports that in the
selection rather than quietly substituting -- a caller who asked for
rotation-free moves and silently got others would have no way to tell.

**No algorithm is claimed to be fastest.** The source lists many for
each and says plainly that a longer algorithm can be quicker for a given person,
so "fastest" is not a fact this module can hold. What it records is one
published, replay-checked choice, alongside the optimal length the same source
gives — the two differ for most cases, which is what a speed algorithm is for.

**Nothing connects it to the solver.** `Standard.solution` is unchanged and does
not consult it.

## The pattern corpora

199 published patterns — 110 for the 3x3x3, 89 for the 2x2x2 — with their
provenance, the algorithm as published, a face-turn form, and a canonical
identity. They live in `CubeSolve.Patterns.Standard` and
`CubeSolve.Patterns.Pocket` as source, compiled into the library. They were
under `test/` until they had consumers; a checked-in data file was considered and
rejected, because it would add deployment paths, IO, decoding failures and cache
invalidation to something small, immutable and versioned with the code. `Codec`
and `Cache` serve generated binary tables and are the wrong tool for
source-owned reference data.

**One corpus, not two.** The tests consume these modules rather than keeping a
copy, and compute identities with `Patterns.Standard.identify` and
`Patterns.Pocket.identify` rather than reimplementing them, so what the tests
check is what a consumer runs.

`CubeSolve.Model.Holding` owns identity up to holding — `identityOf`,
`sameUpToHolding` and `ofToken` — and both corpora delegate to it rather than
keeping a copy. It sits in the model because it is a fact about cubes, not about
the published collections; the corpora were simply the first thing that needed
it, and each had grown its own implementation of a rule subtle enough that two
of them would drift.

`identityOf` returns `None` for any size with centre orbits, and
`sameUpToHolding` returns `Option[Bool]` rather than `Bool`: `Some(true)` for the
same pattern, `Some(false)` for comparable-but-different, `None` for a
comparison this engine cannot make. Three answers because there are three cases
— a bare `Bool` has to report the unsupported one as `false`, which reads as
"different patterns" and makes the relation non-reflexive, so not an equivalence
at all. On the domain where it is defined it is a genuine one, and the tests
check reflexivity, symmetry and transitivity there.

**`Eq` on a cube stays exact state equality.** The group laws, the round trips
and the sticker geometry all read `==` as *identical*; making it mean
*equivalent* would silently weaken every one of them. A named function says which
comparison is being asked for.

**The two identities are not interchangeable**, and the difference is the same
one the model draws. A 3x3x3's centres pin the frame, so two recordings of a
pattern are related by conjugation. A 2x2x2 has none, so re-holding it moves
pieces between slots — which is what a move does — and the relation is one-sided,
with the whole-cube rotations spelled `R L'`, `U D'`, `F B'`. Building the 2x2x2
corpus under the 3x3x3 relation was tried: it called distinct orientations
distinct patterns and left four patterns with no coordinate at all.

`recognize` returns the pattern together with the **orientation witness**, the
re-holding that carries the recorded pattern onto the cube in hand, and
`solutionFor` is what that witness is for. A witness that were off by an inverse
would still name the pattern correctly, so the test replays the reframed solution
rather than comparing tokens.

**No solver consults any of this.** Recognising a scramble as a known pattern
does not change the answer given for it. A shortcut firing on 110 states out of
43 quintillion would be untestable in the ordinary case and would make solution
length depend on whether a state happened to be famous. Exposing it as an
explicit opt-in is a later decision, not a default.

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
