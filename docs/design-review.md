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

**Gate 7.2 is not met and is not claimed.** Superflip is solved, but not in 20
moves, and asserting that it were would be asserting a quality the solver does
not have.

## Undisputed, and worth keeping

- Appendix B ("claims not to repeat") is unusually disciplined and should be
  extended rather than pruned.
- §5's insistence on probe counts over wall clock is correct and should not be
  relaxed under schedule pressure.
