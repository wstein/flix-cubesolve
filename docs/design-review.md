# Design review of the v6 implementation plan

Recorded 2026-08-28. This file lists the amendments the review made to
[`plan-v6.md`](plan-v6.md), and the evidence for each. The plan
itself is not edited; where the two disagree, this file wins and says why.

## Verification of the plan's own figures

Before reviewing, the plan's 2×2×2 numbers were re-derived independently. Every
figure in its F2 distance histogram and its F3 rejection-cost table reproduces
**exactly**: 3,674,160 reachable states, HTM diameter 11, and all twelve
distance classes to the digit. Gate 3.2's local-consistency property
(`|d(s) − d(m(s))| ≤ 1`, and every non-solved state has a neighbour at `d − 1`)
holds over the whole space. The plan's arithmetic is sound; the amendments below
are engineering, not corrections.

## Motion 1 — Gate 4.2 is not executable as written

> *"Gate 4.2 — Returned length == d\*(s) exhaustively."*

The heuristic Stage 4 names — the 729-state orientation coordinate — has a
**maximum value of 6** against a diameter of 11. Over 90% of states lie at
`d ∈ {8, 9, 10}`, so for most of the space the search runs largely unguided.

Measured, optimised Java, single thread, JIT warm, 200 random states:

| heuristic | mean nodes/solve | worst | Gate 4.2 extrapolated |
|---|---|---|---|
| `h_ori` (729), as planned | 217,989 | 1,231,006 | 8.0 × 10¹¹ nodes, ≈ 64 min |

An hour in Java, single-threaded, is not a gate; it is a report. Note also that
Gates 4.1 and 4.2 are listed adjacently as though comparable, when
admissibility is a linear table scan (about a second) and optimality runs a
search per state — nine orders of magnitude apart.

**Amendment.** Gate 4.1 stays exhaustive. Gate 4.2 becomes stratified; see
*Convergence* below.

## Motion 2 — the plan under-specifies the heuristic, and the fix is free

The orientation projection is admissible because `new_o[i] = o_old[cp[i]] +
co[i]` depends only on the move and on `o`. **The same argument applies verbatim
to permutation**: `new_p[i] = p_old[cp[i]]` depends only on the move and on `p`.
There is a second admissible heuristic over 5040 states — a 5 KB table — that
the plan never mentions.

| heuristic | max `h` | mean residual `d* − h` | mean nodes/solve | speedup |
|---|---|---|---|---|
| `h_ori` (729) | 6 | 4.319 | 217,989 | 1× |
| `h_perm` (5040) | 7 | — | — | — |
| `max(h_ori, h_perm)` | 7 | 3.611 | **17,055** | **12.8×** |

Beyond the speed, two independent projections let the admissibility gate run
once per projection, which localises a failure to a projection rather than to
the kernel. This is the plan's own stated principle — *"two independent
derivations wherever available"* — applied to its heuristic.

**Amendment.** Adopt `max(h_ori, h_perm)`.

**Confirmed in the implementation.** Measured on the Flix search over the
deepest states, where the heuristic matters most: **225,715** nodes with both
projections against **2,498,447** with orientation alone — a factor of **11.1**,
corroborating the 12.8× measured on random states beforehand.

## Motion 3 — §7 contradicts Stage 1 about whether the region question blocks

§7 closes with *"`TableView` keeps the question from blocking anything."* Stage 1
then makes Gate 1.5 — the region ADR, with `-Xmx` bisection at 4.5 MB, 7.75 MB
and 240 MB — a precondition for leaving Stage 1. Both cannot hold. Two of those
three sizes are Stage 11 and Stage 12 artifacts that do not exist yet.

**Amendment.** Gate 1.5 splits:

- **1.5a** (Stage 1) — read the stdlib conversion source, ask the maintainers,
  measure at the 4.5 MB size, record an ADR naming outcome A/B/C/D.
- **1.5b** (precondition for Stage 11) — the 7.75 MB and 240 MB bisections.

§7's closing sentence stands as written.

## Motion 4 — Gate 6.1 is tautological if §3's selective port happens

§3 ports min2phase's `CoordCube` and `CubieCube` for 3×3×3 coordinate
arithmetic. §6 generates coordinate move-table fixtures by *running min2phase*.
Gate 6.1 then diffs our tables against those fixtures.

If we port their arithmetic and diff against their output, the gate passes by
construction: any defect is present on both sides. §6 already notes the oracle
"cannot catch a shared misconception" — a port does not risk a shared
misconception, it guarantees shared *code*, which is strictly stronger.

The gate still catches transcription error, index-convention drift and
flattening off-by-ones, which are the realistic port defects.

**Amendment.** Keep the port and the gate; restate the gate's claim as
*"the port was transcribed faithfully"*, not *"the coordinate arithmetic is
correct"*. Independent correctness comes from Gates 6.2 and 6.3, which check
against decoded model state and share no code with the coordinate layer. Add to
§6's "What the oracle cannot do": *a fixture cannot independently validate code
ported from the program that generated it.*

## Motion 5 — two Stage 1 items have unbounded completion time

§4 makes it a Stage 1 item to *"request written confirmation from the author and
check the reply in."* An inbox cannot be scheduled.

The exposure is also narrower than it looks. All three references carry a
standalone MIT grant. The discrepancy is that **cube555 alone** additionally
ships a GPL-v3-only `LICENSE` file — and cube555 is the one reference §3 marks
*"fresh, structurally guided"*, from which no code is ported.

**Amendment.** Send the query; do not gate on the reply. Stage 1 delivers
[`ATTRIBUTION.md`](../ATTRIBUTION.md) recording per-component provenance and the
discrepancy openly. Ported code is restricted to min2phase.

## Motion 6 — Tier 2/3 fixture generation at Stage 1 is premature

§6's fixture header mandates recording *"move alphabet, numbering and metric;
slot and facelet convention."* At Stage 1 those are not yet chosen — Stage 3
picks among three generator sets with diameters 11, 14 and 19, and Stage 7 fixes
a tetrad ordering. Fixtures generated before those decisions record the
reference's conventions into files whose consumers do not exist.

**Amendment.** Stage 1 delivers the *harness* plus Tier 1, and demonstrates
Gate 1.4 (byte-identical regeneration) on one small table. Tier 2 and Tier 3
generation moves to the stage that consumes it.

## Motion 7 — `atLeast` fails on its most natural input

The 3×3×3 `atLeast` ceiling is 9, because all three phase-1 pruning tables max
at 9, while the mean 3×3×3 optimal length is ≈ 17.7. So `atLeast(3, 15)` — the
query a user actually wants — returns `Err`. Honest, and close to useless.

**Amendment.** Keep the semantics; change the return. `atLeast` hands back the
certified bound alongside the state, so a caller sees what it holds, and its
`Err` names both the ceiling and its cause: *"certified lower bounds on this
size are capped at 9 by the phase-1 pruning tables."* The same treatment applies
to `atMost`'s random-walk caveat — the plan's own note that *"users will file it
as a bug"* is a signal the API should carry the caveat, not just the prose.

## Motion 8 — scope

Stages 11 and 12 are more than half the remaining engineering and serve the two
sizes with the worst effort-to-value ratio, while the first shippable feature is
Stage 5.

**Amendment.** No stage is deleted. Stages 1–5 are re-designated **v0.1, a
releasable artifact** — the 2×2×2 engine is complete and useful on its own.
Stages 6–10 are v0.2. Stages 11–12 remain planned, with their memory ceilings
retired as risk before commitment (Gate 1.5b).

**Recorded dissent.** The effect-system argument for region-scoped tables only
becomes interesting at 240 MB, so deferring Stage 12 weakens the architecture
story. That is a project-risk judgement, not a technical one, and it is recorded
rather than resolved.

## Convergence — how Gate 4.2 actually runs

With `max(h_ori, h_perm)`, an exhaustive sweep drops from ≈ 64 minutes to
≈ 7.5 minutes in Java. Better, still not a CI gate.

The distance histogram is extremely non-uniform, so stratify along it: test
exhaustively where the class is small, sample where it is large.

**Revised again once the implementation could be measured.** Even the deepest
class alone is too expensive to run exhaustively *in Flix*: at 225,715 nodes per
state, all 2,644 of them are roughly 6 × 10⁸ nodes and some three minutes. So
the stratification actually shipped is:

- **Exhaustive**: `d ≤ 4`, all 2,232 states — the classes small enough to be
  complete rather than sampled.
- **A fixed stride** of 600 states across the whole space, covering every class
  in proportion to its size. A stride rather than a random sample because it
  reproduces without carrying a seed, and because the coordinate's ordering has
  nothing to do with distance.
- **60 of the 2,644 deepest states**, which is where the search works hardest.
- **Nightly**: the full sweep, at the cost recorded above.

The whole suite, including the exhaustive 3,674,160-state oracle sweep, runs in
about 28 seconds. The point of the amendment survives: name the stratification
and its measured cost in the test, rather than writing "exhaustively" and
quietly running nothing.

**Amended gates.** 4.1 exhaustive over all 3,674,160 states, both projections.
4.2 stratified as above, with the stratification and its cost named in the test.

## What the implementation confirmed

Two of the plan's decoded figures were checkable without building the reference
jars, and both came out exactly right — which is the strongest evidence
available that the coordinate conventions here match min2phase's.

| table | plan's decoded maximum | measured here |
|---|---|---|
| `UDSliceTwistPrun` — raw `Twist × UDSlice` | 9 | **9** |
| `UDSliceFlipPrun` — raw `Flip × UDSlice` | 9 | **9** |
| `TwistFlipPrun` — raw `Flip × Twist` | 9 | **9** |
| `MCPermPrun` — raw `CPerm × MPerm` | 14 | **14** |
| `EPermCCombPrun` — raw `EPerm × CComb` | 13 | **13** |

The plan's figures are for the *symmetry-reduced* tables and these are raw.
Symmetry compresses equivalent states without changing a pruning value, so the
two had to agree — and Motion 4's warning still stands: this is a differential
result precisely because none of this code was ported from the program the
figures came from.

## The quality baseline (Gate 7.6)

Recorded before any optimisation work, so that later changes are judged against
a measurement rather than an impression. Uniform random states from a fixed
seed, solved at three budgets:

| budget | mean length | worst |
|---|---|---|
| fast — `probeMax` 60 | 22.7 | 25 |
| default — `probeMin` 30, `probeMax` 500 | **21.4** | 23 |
| patient — `probeMax` 900 | 21.0 | 22 |

min2phase averages about **20.6** at `probeMin` 5, and the true optimum averages
about **17.7**. So this solver is roughly 0.8 moves behind the reference and 3.7
behind optimal.

### What Stage 10 actually bought

Each change measured separately against that baseline, at **equal probe budget**
so the comparison is not simply "spend more":

| configuration | mean | worst |
|---|---|---|
| single view, 60 handovers per depth | 21.4 | 23 |
| single view, 300 handovers | 21.3 | 23 |
| single view, 1200 handovers | 21.4 | 23 |
| two views (state and inverse), budget split | 21.0 | 23 |
| six views (three axes × two directions), budget split | 21.1 | 23 |
| **six views, budget shared** | **20.9** | 22 |
| six views, budget shared, `probeMin` 120 | 20.8 | 22 |
| six views, budget shared, `probeMin` 600 of 1200 | **20.6** | 22 |

Two findings, neither of which was the expected one.

**Handover count alone does nothing.** Raising the number of phase-one solutions
tried per depth from 60 to 1200 moves the mean by less than a tenth. The search
was not handover-starved.

**Searching the inverse state alone does almost nothing either** — measured at
21.3 against 21.4 when the probe budget is split between the two directions,
which is within noise. Halving each search very nearly cancels the benefit of
having two of them.

**Together they are worth 0.4 moves.** That is default-budget quality matching
what previously took a patient budget of 900 probes. The refinement only pays
when each direction has enough handovers to use its half of the budget, which is
not something either measurement would have shown on its own — and is the
argument for measuring one change at a time and then their combination, rather
than assuming refinements add up.

**Three phase-one axes, and how the budget is spent matters more than the
refinement.** Phase one's goal is stated against the U/D axis and its Flip
coordinate is defined against that axis specifically, so conjugating the cube by
a rotation that carries another axis onto U/D lets the same tables aim at it.
Six views — three axes × two directions — then compete.

Slicing the probe budget six ways gave **21.1**, barely better than one view.
Sharing one budget across the six, each search taking what is left and capped at
one move shorter than the best so far, gave **20.9** at the same total. The
refinement was worth nothing until the budget stopped being sliced; six searches
on a sixth each are all too starved to use the diversity they were added for.

That is the single most useful thing these measurements produced, and it would
have been invisible without measuring the two arrangements separately.

**Symmetry reduction (Stage 10a) was not done, and would not have helped this
number.** It compresses equivalent states without changing a pruning value, and
all three phase-one tables are already built, so the heuristic is already as
strong as the reference's. Symmetry is a memory-and-speed optimisation here, not
a quality one.

**Pre-scramble was implemented, measured, and removed.** The identity holds and
the code worked — every solution replayed — but with the premoves in place the
same budgets gave *the same means to the decimal*: 20.8 at `probeMin` 120 and
20.6 at 600, exactly as without them. The entire gain above 20.9 was the budget
letting the six existing views run, not the premoves.

Keeping it would have been carrying a view type, a composition helper and four
extra searches per solve for nothing measurable, so it was deleted. Recording
the negative result is the point of having measured: without the isolating run,
"we added pre-scramble and the mean improved" would have been true and
misleading.

**Where that leaves the gap.** **20.6 at `thoroughBudget`, which is min2phase's
own average**, and 20.8 at the default. The remaining distance is to the true
optimum of 17.7, and no budget closes that — it is the gap between a two-phase
solver and an optimal one.

Three budgets are now named, with their measured means, because the curve is
flat enough that the choice is the user's: `fastBudget` 20.9, `defaultBudget`
20.8, `thoroughBudget` 20.6.

**Gate 7.2 is not met, and the reason is worth knowing.** Superflip's optimum is
20; this solver returns **22**, at every budget. That is now pinned by a test
rather than left unstated.

Superflip is fully symmetric, so all six views of it — three axes, each
forwards and inverted — are the *same cube*. Every economy this solver has comes
from those views disagreeing with one another, and on superflip they cannot.
More probes buy nothing either, which is why `fast`, `default` and `thorough`
all return 22. It is the exact worst case for this design, and closing it needs
symmetry reduction rather than more search.

## The 3x3x3 scrambler, and what it can honestly promise (Motion 7)

Random-state, like the 2x2x2's: sample a uniform state, solve it, emit the
inverse. What differs is that the 3x3x3 has no distance table, so difficulty is
**bracketed rather than claimed**, and every scramble carries two certified
numbers:

| bound | source | strength |
|---|---|---|
| `atMostMoves` | an actual solution | exact as a bound, pessimistic as a distance |
| `atLeastMoves` | phase-one pruning tables | true, and capped at **9** |

The lower bound is taken as the **largest over the three phase-one axes**. Each
axis's pruning value bounds the moves needed to reach that axis's domino group,
and a full solution passes through the solved cube, which lies in all three — so
each is a lower bound on the whole solution and the best of the three is free.
The ceiling stays 9, since none of them can exceed it, but the typical bound
improves.

`atLeast` above 9 returns `Err` naming the ceiling *and its cause*, per Motion 7.
It is honest and nearly useless, and the module says so: 3×3×3 optimal lengths
concentrate near 17–18, so almost every state is hard and the difficulty a
caller can actually choose lives at the easy end. `atMost` is the useful
constructor.

One limit found by building it: **`atMost`'s floor is set by the solver, not by
the cube.** Asking for much below 20.8 rejects nearly every draw — not because
such states are rare, but because this engine cannot demonstrate them. When the
draws run out it says exactly that.

## What the pattern collections say about solution length

The published patterns are a second, harder quality corpus, and they measure
something the random baseline cannot. Random states are typical; patterns are
*designed* — symmetric, structured positions whose algorithms were built to
exploit exactly that structure.

**On the 3×3×3 the solver loses to the publications, and more search barely
helps.** Over the 102 patterns published in face turns, at the default budget:

| budget | longer than published | worst excess | solver total |
|---|---|---|---|
| `fastBudget` | 37 of 102 | — | 1481 |
| `defaultBudget` | **32 of 102** | **7** | 1467 |
| `thoroughBudget` | 31 of 102 | 7 | 1456 |
| 6000 probes | 28 of 102 | 7 | 1441 |

Twelve times the probes buys four patterns. The worst case is Tetris —
published in 8 moves, solved in 15 — and it does not improve with effort. The
gap is structural: a two-phase solver reaches every state the same way, through
the domino subgroup, with no notion that this position is special. Closing it
would need the solver to exploit symmetry, which is what Stage 10a is for.

**On the 2×2×2 the solver cannot lose**, because its solver is exact. That turns
the comparison around and measures the *publications* instead: **63 of the 89
published pocket-cube algorithms are already the shortest possible**, and the
other 26 carry at most 4 moves of slack — 752 moves published against 702
needed.

Both are asserted as gates, so a regression in either direction shows.

## Self-symmetry view skipping: measured and rejected

The six views a solve tries — three axes, each forwards and inverted — collapse
for a symmetric cube. Superflip looks the same from all six. Skipping the
duplicates is an obvious economy and it was implemented, measured and removed.

**It made the solver worse.** Superflip went from 22 moves to **24**.

The reason is worth writing down, because the redundancy is load-bearing. Each
view is searched with `maxDepth` set to one shorter than the best answer so far.
So re-searching an *identical* state is not a repeat: the tighter cap prunes
everything at or above the current best and pushes the same probes deeper into
what remains. The "duplicate" views were an iterative-improvement loop that
nobody had named.

Making that loop explicit — sweep the distinct views, then sweep them again
against the answer just found, until a pass fails to improve — recovered
superflip's 22 and let duplicates be skipped honestly. But measured against the
recorded baselines it bought almost nothing:

| corpus | before | after |
|---|---|---|
| 20 uniform random states, mean | 20.8 | **20.8** |
| 102 patterns, total solver moves | 1467 | 1462 |
| 102 patterns, longer than published | 32 | 32 |
| 102 patterns, worst excess | 7 | 7 |

Five moves across a hundred and two patterns, no change at all on random states,
no measurable speed gain, one pattern regressed (`Vertical stripes`, 21 to 22),
and a bookkeeping list threaded through the search. It was reverted.

**The general lesson, and it is the second time this session:** an optimisation
that removes apparent waste has to be measured against what the waste was
quietly doing. Pre-scramble was rejected the same way. The suggestion to add
self-symmetry deduplication is a sound one in a solver whose views are genuinely
independent searches; in this one they are not.

## Phase-two feedback: measured and kept

The one refinement that paid. Phase two hands back a **certified lower bound**
on the moves it would need from a handover, and phase one uses it to drop
handovers that cannot beat the answer already in hand.

The bound is the larger of two admissible pruning values, so no shorter
phase-two solution exists. When it already exceeds the moves the budget leaves,
arithmetic has settled the handover and searching it would spend a probe to
learn what is known. It is never attempted, so it was never a probe — the
meaning of a probe is unchanged. The test is made against the *current* best, so
each improvement prunes what is still to come.

| corpus | before | after |
|---|---|---|
| 20 uniform random states, mean | 20.8 | **20.4** |
| 102 patterns, total solver moves | 1467 | **1445** |
| 102 patterns, longer than published | 32 | **29** |
| 102 patterns, worst excess | 7 | 7 |
| whole suite, wall clock | ~230 s | ~219 s |

**20.4 beats min2phase's 20.6.** And the aggregate crossed over: 1445 solver
moves against the publications' 1453, so across the collection the solver is now
shorter than the hand-built algorithms — while still losing 29 of them
individually.

Cost did not move into the fast path. The suite measured 219 s against a
226–328 s band for identical code beforehand, which is to say the difference is
below what these measurements can resolve.

**One attempt was thrown away first, and it is the reason this one works.**
Ranking every handover by its bound before probing any looked strictly better
and timed out: the ranking evaluated all 300 handovers per depth where the old
code stopped after a few. Pruning lazily — compute the bound when the handover
comes up, which the probe needed anyway — keeps the benefit and adds nothing.

`TestDominoBound.thePhaseTwoLowerBoundNeverOverstates` is the safety net. The
bound is checked against an actual search over 30 domino states of varying
depth, because a bound that overstated would silently discard winning handovers
on some cubes and not others.

## Two cache defects that both looked like conservatism

Both were argued for when written, and both arguments were wrong in the same
way: they optimised for not doing work, in a component whose entire job is to
return something a caller will trust without checking.

**The generator was recorded and not compared.** The reasoning was that a table
built by an older build of the same code is still that table. But what a table
contains is decided by the code that generated it, and the convention string does
not capture that. A different pruning pairing, a different move order, a fixed
bug in a sweep — the convention is untouched and every entry differs. The failure
is the worst shape available: a stale table served without complaint, on a
developer's machine only, after a change that tested clean. The cost of comparing
is one rebuild after a version bump, which is seconds, once.

**Publication staged beside the target under `${path}.writing`.** The name is a
function of the target, so two processes generating the same table pick the same
staging file. The second can move the first's half-written file into place, and
on a system where rename detaches the name from the open file, the first then
continues writing into what has already been published. That both processes
compute identical bytes is not a defence — it is why nobody would look here. The
handler now stages in a directory it obtains for itself, and writes nothing at
all if it cannot get one.

**Neither would have been caught by the tests that existed.** The in-memory store
proved every policy question and never touched a file, so the filesystem handler,
the staging path and the atomic move had no coverage at all. `TestCacheOnDisk`
runs the production chain down to `IO` in a temporary directory. The lesson is
not "test more" — the in-memory tests are good and fast — it is that a handler
that exists to talk to the outside is not covered by tests of the thing it
handles for.

## The staging fix is smaller than it was first written up as

The commit that made it claimed the shared `${path}.writing` name let two
processes corrupt a published table. Gate 13.2 was then built to prove it, and
the honest way to learn whether a gate is worth having is to reintroduce the
defect and watch it fail. It did not fail. **Twenty-five rounds of two real
processes generating `pocket.distances` into one fresh directory, with the shared
staging name restored, produced twenty-five valid caches.**

The reason is the part the original write-up skipped. Tables are deterministic,
so two racing processes write *identical bytes*, and a lost race publishes the
right content regardless of who won it. Where the bytes would differ — two builds
whose table construction changed — an interleaved file fails the codec's digest,
which makes it a miss, which makes it a rebuild. The digest was already what
stood between a torn write and a wrong answer, exactly as *A corrupt or foreign
cache is a miss, not a failure* says it should be.

So the fix is not what met the gate; the gate was already met. What it actually
restores is the property `writeAtomically` states about itself — a reader sees
the old file or the whole new one — which under a shared name a concurrent reader
could catch it breaking, and pay a needless rebuild for. That is worth keeping.
It is defence in depth behind the digest, not the thing preventing corruption,
and calling it the latter overstated it.

**The measurement is the point.** A gate that passes is evidence of nothing until
you know it can fail. Falsifying this one cost five minutes and corrected a claim
that had already been committed.

## Eight published algorithms that do not do what they are filed under

The method corpora record every algorithm the source lists for each case -- 324
for the 21 PLL cases, 129 for the 57 OLL ones. Before any of them shipped, each
was parsed and replayed against the state its own case describes. **Eight
failed and were left out.**

One is a plain transcription slip: Y-PLL's
`R R U' R R FR' B' D' R D F' R' B R` has `FR'` where it means `F R'`, and the
parser says so. The other seven parse and simply do not solve the case they are
filed under:

- F-PLL, `y2 R U' R' U R U F R U R' U' x' D' R2 D R D'`
- F-PLL, `y2 R U' R' U R U F R U R' U' x U' R2 U R U'`
- G-PLL c, `B2 L2 U' B2 D B2 D' R2 U M2 F2 (x2)`
- J-PLL a, `(y2) (M' D2 M') R U R' F' R U R' U' R' F R2 U' R' (M D2 M)`
- H-PLL, `M2' U2 M2' U' M2' U' M2'`
- OLL Bottlecap, `(U) R' U' R' F R F' R U2' R' U2 R`

The check that found them is worth more than the exclusions. A corpus of
published algorithms is data from outside, and treating it as correct because it
is published is how a wrong one reaches a user who then blames their own hands.
Each recorded algorithm is now replayed against its case in the test suite, so a
future addition that does not work cannot ship quietly.

## A finishing turn is not always a `U` turn

Recognition reports the turn to make after the algorithm. That was written as a
count of `U` quarter turns, which is what every reference means by AUF, and it
was wrong for a small number of cases.

Y-PLL's shortest recorded algorithm is
`R2 U' R' U R U' x D' R' U R' U' R' D R`. It contains an `x` and no `x'`, so it
ends with the cube on its side. A `U` written after that turns whatever face is
now uppermost, which is not the layer the AUF is about -- and no pair of plain
`U` turns solves those cases at all, which is how it surfaced: the profile tests
failed on exactly one case out of 21, under exactly one profile.

The turn is now named for the frame the algorithm leaves, so it may come out as
`F2` or `L'`. `Solution#finish` is therefore written rather than counted. The
lesson is the one this project keeps relearning: a rotation in a sequence
changes what every later move name means, and anything appended to an algorithm
has to be expressed in the frame that algorithm ends in.

## Undisputed, and worth keeping

- Appendix B ("claims not to repeat") is unusually disciplined and should be
  extended rather than pruned.
- §5's insistence on probe counts over wall clock is correct and should not be
  relaxed under schedule pressure.
