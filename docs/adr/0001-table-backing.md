# ADR-0001 — What backs `TableView`

- **Status**: **Accepted — outcome B**, settled by reading the standard library
- **Date**: 2026-08-28
- **Flix version under test**: 0.75.3 (pinned in `.flixw/lock.toml`)

## Context

Every lookup in this engine — IDA\*, every pruning probe, every reduction phase
— goes through one opaque handle:

```
CubeSolve.Table.TableView      opaque;  get(i): Int32
```

Tables are built imperatively, because building them is a BFS over millions of
entries and nothing else is reasonable. They are then read from code that wants
to be pure. What sits between those two facts is this decision.

An earlier working assumption held that Flix can convert a region-allocated
mutable array into an immutable structure **without a deep copy**, on the
grounds that the type system proves no other mutable reference exists.

**This is a hypothesis, not a documented fact.** It traces to the same generated
artifact that put the 5×5×5 state space at 10⁴⁰ — off by 34 orders of magnitude.
What regions certainly provide is that mutable data cannot *escape* the region's
scope. A cheap freeze does not follow from that.

Fixing the `TableView` interface first means this decision chooses a *backing*,
not whether the architecture works.

## Decision procedure

Cheapest first; stop as soon as the question is closed.

1. **Read the Flix standard library source** for the array-to-vector conversion
   at the pinned version. If it loops and copies, the question is closed and the
   outcome is B.
2. **Ask the Flix maintainers.** Phrased concretely: *a large read-only lookup
   table built imperatively and read from pure code — what is the intended
   pattern?* This also surfaces their recommended idiom, which may beat anything
   invented here.
3. **Spike** only what those leave open, timeboxed, at sizes that matter —
   behaviour diverges from toy sizes.

Three questions, in order: does it compile; what is **peak heap** during
conversion; and what is random-read throughput through `TableView.get` versus a
raw array read, in the IDA\* access pattern (random, not sequential).

### Measuring peak heap

Bisect `-Xmx`: run repeatedly, halving the heap until it OOMs. The smallest heap
that succeeds is the floor. This is reproducible and does not depend on sampling
a GC MXBean at the right moment. The same method is used everywhere so that
figures compare.

One JVM constraint to check while there: arrays are `int`-indexed, so 2³¹−1
elements is a hard cap. 240 MB as `Int8` is 240M elements, which is fine; the
same data naively as `Int32` is 960 MB, under the element cap and over any sane
heap. That is the four-times hazard in its worst case, and it is why table
widths are explicit.

## Outcome: B — it copies, once

Step 1 of the procedure closed the question, so no spike was needed.
`Array.toVector` in the standard library at the pinned version reads:

```flix
pub def toVector(a: Array[a, r]): Vector[a] \ r = region rc {
    let arr1 = copyOfRange(rc, 0, length(a), a);
    unchecked_cast(arr1 as Vector[a])
}
```

It copies. **The zero-copy hypothesis is false**, and the working assumption it
came from — the same generated artifact that put the 5×5×5 state space at 10⁴⁰ —
should not be trusted on anything else either.

Two things follow, and the second is more useful than the first.

**The conversion is a copy, so peak heap during a freeze is twice the table.**
At the size this engine reaches today — 4.5 MB, standing in for the 3×3×3
`Flip × Twist` table — that is 9 MB, far inside any budget. The decision under B
was "accept if twice the peak fits the ceiling", and it does.

**A zero-copy freeze exists, but it is an escape hatch and not a guarantee.**
The `unchecked_cast` above shows that a `Vector` *is* an array at run time, so
casting a region array directly would avoid the copy. What makes the standard
library's use of it sound is that it casts a *fresh* copy that no other
reference points at — the copy is what buys the safety, not a proof from the
type system. Casting a builder's own array would be sound only while nothing
else holds it, which the type system would no longer be checking.

**This engine takes the copy.** `CubeSolve.Table.ofPayload` calls
`Array.toVector` and pays for it once per table at initialisation. If a
measured ceiling later makes that unaffordable, the escape hatch is available
and its precondition is written down here rather than rediscovered.

**Question 3 is deferred, deliberately.** Read throughput through
`TableView.get` versus a raw array read can only be measured against the access
pattern that matters — random reads in an IDA\* inner loop — and there is no
such loop yet. Measuring the abstraction before its consumer exists would
measure nothing. It is the precondition for tuning work, not for building the
table subsystem, and outcome D's remedy (specialise per backing, or re-baseline
before optimising) does not change anything built today.

## Pre-committed outcomes

Decided in advance so the measurement cannot end ambiguously.

| outcome | decision |
|---|---|
| **A** — compiles, no copy, reads within ~20% of raw | Adopt. Declared memory ceilings stand. |
| **B** — compiles, copies once at initialisation | Accept if twice the peak fits the ceiling. Otherwise route generation through disk: build → serialise → drop → load into the immutable form. After the first run that is the common path anyway, so the copy costs only on a cold cache. |
| **C** — no such conversion exists | Wrap the whole solve in one long-lived `region r`; tables stay `Array[Int8, r]`; search carries the region instead of being pure. |
| **D** — reads through the abstraction more than 2× slower than raw | Specialise `TableView` per backing, or accept and re-baseline the search benchmark *before* any optimisation work tunes against it. |

**Outcome C changes the architecture story, and that is acceptable.**
`docs/architecture.md` currently describes search as pure with tables injected.
Under C it would describe search as scoped to the table region — still a real
demonstration of the effect system, arguably a more interesting one, since the
region then tracks a lifetime rather than merely hiding mutation. What is *not*
acceptable is discovering C late and having written the documentation as though
A held.

## Scope of the measurement

Per [the design review](../design-review.md#motion-3), this ADR is settled at
the size the engine actually reaches first:

- **Now** — 4.5 MB, standing in for the 3×3×3 `Flip × Twist` table. Settled
  above: a copy, doubling to 9 MB at the freeze.
- **Before the 4×4×4** — 7.75 MB packed, and 240 MB for the 5×5×5 cache. Still
  open. At 240 MB the doubling is 480 MB, which is the figure that would breach
  the declared 700 MB ceiling once a serialisation buffer joins it, so this is
  the measurement that decides whether the escape hatch above becomes
  necessary.

Deferring the two large sizes is deliberate: they stand in for artifacts that do
not exist yet, and gating early work on them would contradict the reason
`TableView` exists.

## Consequences

- No call site outside `CubeSolve.Table` touches a backing array directly. This
  is testable and is asserted.
- Table widths are explicit (`U8Table`, `Packed4Table`, `Packed2Table`) rather
  than defaulting to `Int32`.
- If this decision is revisited, **re-record the Flix version**. A compiler
  release can change the answer, and a future contributor needs to know whether
  the finding still holds or must be re-run.
