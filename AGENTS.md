# Working on this project

`flix-cubesolve` is a solving and scrambling engine for n×n×n twisty cubes,
2×2×2 through 5×5×5. It is a **library**: no top-level `main`, everything under
`CubeSolve`.

The project carries its own compiler. `./flixw` downloads the exact `flix.jar`
pinned in `.flixw/lock.toml`, verifies it against a committed SHA-256, and runs
it. Nothing needs installing but a JDK — 21 or newer.

## Commands

Run everything through the wrapper: `flix` is not expected to be on `PATH`, and
a `flix` that is may be a different version than this project pins. On Windows
use `.\flixw.cmd` wherever these say `./flixw`.

- `./flixw check` — type-check without generating code; the fast feedback loop
- `./flixw test` — run every `@Test` function under `test/`
- `./flixw build` — compile to `build/class`
- `./flixw format` — reformat sources in place; the pinned compiler has no
  check-only mode, so CI does not gate on formatting
- `./flixw doc` — write API documentation for the standard library and this
  project to `build/doc/`
- `./flixw metrics --format md` — code-smell report: over-long and crammed
  lines, complexity, nesting, coupling, doc coverage. **Run it before every
  commit and fix what it finds**; it needs the project to compile first

`./flixw run` does **not** work here and should not be made to. Flix allows one
`main` per program, so a library that ships one cannot be depended on. The
command line lives in its own package, `examples/cli-tool`, depending on the
*published* `cubesolve` the same way any other consumer would — proof that a
released build is actually usable, not only that the library compiles:

```sh
./flixw examples run cli-tool -- help
./flixw examples run cli-tool -- solve R U R' U'
```

`examples/cli-tool` carries no wrapper of its own and needs a `cubesolve`
release to resolve against; see `docs/architecture.md` for the full rationale
and `examples/cli-tool/README.md` for running it directly with `flix run`.

`--entrypoint` still reaches a definition under `test/` for the Gate 13.2
harness, which runs without putting anything in `src/`:

```sh
./flixw build-fatjar --entrypoint QualifyCacheRace.qualify
```

Note that `build-fatjar` runs redundancy checks `check` does not — a pure
function declared `\ IO` passes `./flixw check` and fails the jar build.

The wrapper adds verbs of its own, ahead of the compiler's:

- `./flixw validate` — the wrapper's own consistency checks, for CI
- `./flixw doctor` — those checks plus the full picture, for bug reports
- `./flixw pin <version>` — move to another compiler and rewrite the lock

## Layout

- `src/CubeSolve.flix` — the root module
- `src/CubeSolve/` — engine sources; directories mirror module paths.
  `Model/Stickers.flix` turns cubes larger than a 3x3x3 as facelets, since the
  geometry is uniform in `n` where per-orbit move tables are not.
  `CubeSolve/Patterns/` holds the 199 published patterns as generated source:
  one canonical copy, consumed by the tests rather than duplicated in them
- `test/` — `@Test` functions, flat, one `TestX` per subject
- `docs/` — architecture, conventions, design review, and dated ADRs
- `ATTRIBUTION.md` — provenance and licence of anything not written here
- `flix.toml` — package metadata, dependencies, and the *lowest* Flix version
  this project accepts
- `.flixw/lock.toml` — the exact compiler and its digest. `flix.toml` states a
  floor; this states the pin. Both are committed, and `validate` fails when
  they disagree
- `flixw`, `flixw.cmd`, `.flixw/flixw.java` — the wrapper itself. Generated;
  change it with `./flixw wrapper --upgrade`, never by hand
- `.github/workflows/` — `build-and-test.yaml` on three platforms,
  `update-flix.yaml` weekly, `docs.yaml` for the API documentation. All three
  drive the wrapper; none of them install Flix
- `build/`, `artifact/`, `lib/`, `tmp/` — generated or scratch; do not edit and
  do not commit

`CLAUDE.md` and `.github/copilot-instructions.md` both point at this file
rather than repeating it, so that each tool finds the same instructions under
the name it looks for.

## The one thing to read before changing anything

**Cube state exists in two representations and they are not interchangeable.**

| layer | representation | used for |
|---|---|---|
| model | permutation and orientation vectors, one per orbit | validation, tests, I/O, phase-boundary checks |
| search | scalar `Int32` coordinates | `newCoord = table[coord * nMoves + move]` |

A phase boundary is validated against the **decoded model state**, never by
rereading the coordinate the search just wrote — otherwise a search bug that
corrupts a coordinate validates itself. If you find yourself checking a search
coordinate for legality, you are in the wrong layer.

Every convention the engine assumes — slot indexing, composition order,
orientation reference frames, move numbering — is in `docs/conventions.md` and
is carried in the header of every generated table. **A table or fixture without
its convention recorded pins nothing**, because relabelling slots by any
bijection preserves every invariant and changes only the encoding.

## Dependencies

`flix-orbit64` supplies the orbit decomposition (`Orbit64.Orbit`), the ranking
functions (`Orbit64.Rank`), the "is this a cube at all?" validator
(`Orbit64.Coord.faultOf`) and the facelet interchange (`Orbit64.Net`). Prefer
adopting those to rewriting them.

It does **not** model an odd cube's fixed centres — it treats them as the
reference frame, and `Orbit64.Net.fromFacelets` refuses a cube whose fixed
centres have moved. This engine must accept such cubes, so the model carries a
whole-cube orientation of its own. See `docs/architecture.md`.

## Writing Flix

Your training data is probably older than this compiler. Read
<https://doc.flix.dev/for-llms.html> before writing Flix: it lists what changed.
For the standard library use <https://api.flix.dev>, or run `./flixw doc` and
read `build/doc/`, which matches this project's compiler exactly. `flix-orbit64`
is a working, idiomatic reference at exactly this compiler version.

The mistakes that show up most often:

- `def main(): Unit \ IO = ...` — arguments come from `Env.getArgs()`, not from
  parameters
- effects are written with `\`, not `&`
- effect operations are called like ordinary functions; there is no `do` keyword
- handlers are `run { ... } with handler E { ... }`; chain them rather than
  nesting `run`
- annotations are uppercase: `@Test`, `@Lazy`, `@Parallel`, `@MustUse`
- Java types need a top-level `import`, and all Java interop carries `IO`

Prefer effects and handlers to callbacks or hand-written CPS, and standard
library effects to Java interop.

### Performance-sensitive code

The search layer is the exception to "write it clearly first". It runs tens of
millions of successor steps, so:

- flat primitive arrays, never nested; `Array` inside a `region`, never `MutList`
- tables are read through `CubeSolve.Table.TableView` and through nothing else
- checked `Int64` multiply before narrowing to an `Int32` index — JVM arrays are
  `int`-indexed, so 2³¹−1 elements is a hard cap
- preallocated search path, allocation-free hot loop, no clock reads inside it

## Naming modules

A module has one declaration site in the whole program, dependencies included,
so never take a common top-level name.

- one root namespace per package, named after it: this package roots at
  `CubeSolve`, not `Cube` — `Cube` belongs to `flix-cube`
- directories mirror module paths: `CubeSolve.Model.Move` in
  `src/CubeSolve/Model/Move.flix`
- two or three levels; `Internal` for what is not API
- name a module for what is done there: `CubeSolve.Solve.Pocket` solves pocket
  cubes
- spell names out; tests flat, one `TestX` per subject
- a library deletes `src/Main.flix`: one `main` per program, so a package that
  ships one cannot be depended on

## Testing

Correctness here is not a matter of a few hand-picked examples.

- **Exhaustive where the space permits.** All 3,674,160 2×2×2 states.
- **Stratified where it does not.** Test every state in the small distance
  classes and a fixed-seed sample of the large ones. Say which, in the test name.
- **Round-trip.** Every solution replays to the identity; every rank round-trips
  both directions.
- **Group laws.** Identity, inverse, `m⁴ = id`, opposite-face commutation.
- **Failure reproducibility.** A failing test reports the seed and the canonical
  state token, so the failure can be replayed.

A test that takes minutes is not a gate. If a property is too expensive to check
exhaustively, stratify it and name the stratification — do not quietly check
nothing.

### The slow tier

The suite takes four to five minutes, and the spread between runs is wide — 233 s
to 328 s for identical code — so do not tune against a single measurement.

Cost comes from two things and only two: **running the solver**, and **building
a table**. `TestPatternBounds` solves 110 patterns and is alone worth 96–143 s;
`TestTwoPhase` and `TestScrambleStandard` are about 30 s each; the phase-table
gates are 20 s and 16 s. Everything else is under ten seconds together.

**Do not assume a test is slow because it looks like a lot of work.** Sweeping
all 199 checked-in patterns through all 24 orientations — nearly five thousand
re-recordings — costs 0.14 s and 0.05 s. That was misdiagnosed once as the cause
of the suite's runtime, and consolidating those tests to fix it saved nothing
measurable. Time a test before restructuring it:

```sh
./flixw test 2>&1 | grep " PASS "     # each test prints its own elapsed time
```

If the suite has to come down, the lever is the solver-driven tests: stratify
them the way `Gate 4.2` is stratified, and name the stratification.

That has been done once already. `TestPatternBoundsFast` checks 27 patterns
chosen by stated rules and runs everywhere; `TestPatternBoundsExhaustive` checks
all 110 and is **off unless `CUBESOLVE_EXHAUSTIVE=1`**:

```sh
CUBESOLVE_EXHAUSTIVE=1 ./flixw test    # what CI runs on main and nightly
```

Two rules if you do this again. **Name the split** — two modules, not a quietly
shortened list. And **make the skip loud**: the exhaustive test prints that it
was skipped and how to run it, because a gate nobody knows is disabled is worse
than no gate at all.

### Gate 13.2, which is not a test

`scripts/qualify-cache-race.sh` races two child JVMs onto one cache directory.
It is a script rather than a `@Test` because a test runs inside one JVM, and
what the gate is about is two of them. It builds a fatjar whose entry point is
`test/QualifyCacheRace.flix` -- `--entrypoint` reaches a definition under
`test/`, so the harness stays out of `src/` and the library still ships no
`main`.

```sh
./scripts/qualify-cache-race.sh              # five rounds; CI runs this on main
CUBESOLVE_RACE_ROUNDS=25 ./scripts/qualify-cache-race.sh
```

A race that is lost is still a pass, so treat a single green round as proving
nothing. The same applies to the gate as a whole: it was run with the defect it
exists for put back, and passed twenty-five rounds. `docs/design-review.md` says
why, and it is the better lesson of the two.

## Releasing

A tag publishes. `.github/workflows/release.yaml` builds the package from the
commit the tag names and attaches it to a GitHub release, and `github:`
dependencies resolve through those assets — so a tag without a release is a
version nobody can depend on.

**Three versions move together**, in the release commit:

- `flix.toml` — `version`
- `src/CubeSolve.flix` — the string `generator()` returns
- `examples/cli-tool/flix.toml` — the pin the example resolves through

The generator matters more than a version bump usually does: since `04e59c5` the
cache *compares* it rather than merely recording it, so bumping invalidates every
table an older build left behind. That is intended at a release boundary and
costs one rebuild. Test fixtures pin the string too, and move with it.

Then, in order:

```sh
./flixw format
./flixw validate                     # wrapper, lock and flix.toml agree
./flixw build                        # redundancy checks `check` does not run
CUBESOLVE_EXHAUSTIVE=1 ./flixw test
./flixw metrics --format md
./scripts/qualify-cache-race.sh      # Gate 13.2
git commit                           # the version bump
git push origin main
git tag -a vX.Y.Z -m "..." && git push origin vX.Y.Z
```

**The example cannot be qualified before the tag**, because it resolves through
release assets rather than the working tree. That is the point of it — it sees
only the public surface, under Flix's dependency security context, exactly as
any other project would — and the cost is that a source change cannot compile it
until the version it pins exists. So `release.yaml` qualifies it *after*
publishing, in the `qualify-example` job, and the release is not complete until
that job is green.

**A failed post-publish qualification needs a corrective patch release.** A
version anyone may already have resolved must not change under them, so never
retag: fix forward with `vX.Y.Z+1`.

**`v0.4.0` is `qualify-example`'s first end-to-end run — watch it.** The job was
added after `v0.3.0` had already published, so it has never run against a real
release. Its two guards were exercised on their own: the version-pin check was
run against `examples/cli-tool/flix.toml`, and the "no test count means it ran
nothing" guard is the one from `build-and-test.yaml`, which was watched failing
correctly while `./flixw examples` was broken. The wiring between them was not.
So on the next release, read that job's log rather than only its colour, and
confirm it reports a test count from the version just published.

## Commits

Conventional commits, single-purpose, with the type and scope naming the primary
change.

Before every commit, in this order:

```sh
./flixw format                  # no check-only mode, so this must run first
./flixw check                   # type-check; a minute, not five
./flixw metrics --format md     # code smells; fix them, do not carry them
```

**The full suite is a nightly gate, not a per-commit one.** This project is
pre-alpha and nothing depends on it being stable, so paying four to five minutes
on every commit buys repetition rather than coverage. CI runs `validate` and
`check` on every push and pull request, and the whole suite — three platforms,
every pattern, the two-process cache race — at 03:30 nightly and on request.
A type error is caught in a minute; a behavioural regression is caught within a
day.

Run `./flixw test` yourself when you have changed something the type-checker
cannot judge: a search, a table, a predicate, an algorithm corpus. The nightly is
the floor, not the ceiling.

**This trade expires the moment someone depends on this being stable.** The
honest signal for putting the suite back on every push is the first release
somebody builds against.

`metrics` reports against a working tree, so a run with uncommitted changes
describes a state no commit contains — it says so itself. Fix the findings and
re-run rather than reasoning about which ones the commit will keep.
