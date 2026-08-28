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

## Undisputed, and worth keeping

- Appendix B ("claims not to repeat") is unusually disciplined and should be
  extended rather than pruned.
- §5's insistence on probe counts over wall clock is correct and should not be
  relaxed under schedule pressure.
