# Attribution

What in this repository came from somewhere else, under what terms.

## Dependencies

| component | source | licence |
|---|---|---|
| `flix-orbit64` v0.3.0 | [wstein/flix-orbit64](https://github.com/wstein/flix-orbit64) | Apache-2.0 |
| Flix compiler 0.75.2 | [flix/flix](https://github.com/flix/flix) | Apache-2.0 |

`flix-orbit64` supplies the orbit decomposition (`Orbit64.Orbit`), the ranking
functions (`Orbit64.Rank`), the cube-legality validator
(`Orbit64.Coord.faultOf`) and the facelet interchange (`Orbit64.Net`). It is a
declared package dependency, resolved by the compiler; no source is vendored.

## Reference implementations

Three solvers by Shuang Chen (Chen Shuang) inform the design. Their status
differs and the difference matters.

| reference | what is taken | how |
|---|---|---|
| [cs0x7f/min2phase](https://github.com/cs0x7f/min2phase) | 3×3×3 coordinate arithmetic | selective port, planned |
| [cs0x7f/TPR-4x4x4-Solver](https://github.com/cs0x7f/TPR-4x4x4-Solver) | 4×4×4 phase structure | structural guidance only |
| [cs0x7f/cube555](https://github.com/cs0x7f/cube555) | 5×5×5 phase structure | structural guidance only |

**No table or literal array is extracted from any of them.** Where reference
behaviour is captured, it is captured by *running* the program and checking in
the output as a versioned fixture with its provenance in the header.

### Licence position

All three READMEs carry **both** a GPLv3 section and an MIT section, attributed
to Shuang Chen / Chen Shuang, 2023. The MIT text is a standalone grant, so
using the code under MIT terms with attribution is available.

**Two discrepancies, recorded openly.**

The READMEs present both licences without stating "at your option," and
**cube555 additionally ships a `LICENSE` file containing GPL v3 text only**; the
other two ship no separate licence file.

And — checked directly on 2026-08-29, correcting an earlier note here —
**min2phase's `src/Search.java` carries a GPLv3-only header** in the file
itself:

> Copyright (C) 2015 Shuang Chen … you can redistribute it and/or modify it
> under the terms of the GNU General Public License … either version 3 of the
> License, or (at your option) any later version.

Its README does carry both a GPLv3 and an MIT section, dated 2023, so the dual
grant is real. But a 2015 GPLv3 header inside the source file is a stronger and
more specific statement than a 2023 README section, and the two are not
obviously reconciled. `Util.java`, `CubieCube.java`, `CoordCube.java` and
`Tools.java` carry no header at all.

**What this project does about it.** `Search.java` is the file holding the
two-phase *search orchestration* — the part most worth learning from, and the
part this engine deliberately does not take. Nothing here is ported from it, and
nothing here reproduces its structure. The search in `CubeSolve.Solve` was
derived from the published algorithm's description and from measurement, and
where the reference is used at all it is used for **published figures** — the
pruning-table maxima decoded from `pruningValue.txt`, and pattern algorithms
checked in as fixtures with their provenance.

That position is deliberately more conservative than the READMEs would require.
It costs little, because the ideas in a search — skip equivalent branches, feed a
failure bound back into the caller — are not the sort of thing a licence covers,
while an implementation's structure is.

A clarification has been requested from the author. Per
[the design review](docs/design-review.md#motion-5), the project does not block
on the reply — an unanswered email is not a schedule. This file is updated when
one arrives.

This is a record, not legal advice. If it matters commercially, have counsel
read the files.

### What this is not

Generating fixtures from a reference and implementing against them is **not**
clean-room reverse engineering. Clean-room separation requires two isolated
teams, one writing a specification and one implementing it without sight of the
original. That is not what happens here, and describing it that way would be
false.

Two GPL-only projects — `cube-solvers` and Twizzle Search — are deliberately
**not** used as sources.

## Verified figures

The 2×2×2 distance histogram, HTM diameter and heuristic bounds used in this
repository were derived independently rather than copied, and agree with the
published figures. See [`docs/design-review.md`](docs/design-review.md).

## This repository

AGPL-3.0-or-later. See [LICENSE](LICENSE).

This repository is licensed under the GNU Affero General Public License v3 (or
later). Because components of the reference implementations by Shuang Chen
(`cs0x7f`) carry GPL-3.0 notices (e.g. `Search.java` in `min2phase`, and the
`LICENSE` file in `cube555`) and the official WCA scrambler suite
[TNoodle](https://github.com/thewca/tnoodle) is licensed under GNU AGPLv3,
licensing under `AGPL-3.0-or-later` provides 100% legal clarity and full
reciprocal compatibility across the twisty puzzle ecosystem.

## OLL and PLL algorithms

`src/CubeSolve/Method/Pll.flix` records one algorithm and one optimal length for
each of the 21 PLL cases, and `src/CubeSolve/Method/Oll.flix` one algorithm for
each of the 57 OLL cases, taken from the Speedsolving.com wiki, retrieved
2026-08-30:

<https://www.speedsolving.com/wiki/index.php?title=PLL>
<https://www.speedsolving.com/wiki/index.php?title=OLL>

The OLL page carries fifty cases inline and includes `Template:OCLL` for the
seven corner-only ones. Case names are recorded with their aliases as the source
gives them, because most cases go by several and cubers do not agree on one.

Each algorithm is the first listed under its case's *Speedsolving Algorithms*
heading, so it is a speed-oriented choice rather than a shortest one, and the
recorded optimum is what the same page gives under *Optimal Algorithms*. The
page lists many algorithms per case and states that a longer one may be faster
for a given person, so no claim is made here that the recorded choice is the
fastest.

## Layer-by-layer stage structure

`src/CubeSolve/Method/Beginner.flix` follows the stage order every beginner
guide teaches. The published guide at <https://cubesolve.com/> was **consulted as
pedagogy** for that ordering and for nothing else.

Its terms reserve all rights and grant no reuse licence, so no move sequence,
wording or table of its appears here. The stage predicates were written from the
cube's own state -- which piece sits in which slot, and which way round -- and
each is checked against the model rather than trusted because a tutorial printed
it. Any algorithm this method comes to need will be derived by search and
verified by replay, or taken from a source with explicit permissive licensing.

## Kewbz pattern variants

`src/CubeSolve/Patterns/Kewbz.flix` records 36 algorithms from KewbzUK's
published pattern guides, retrieved 2026-08-30:

<https://kewbz.co.uk/blogs/solutions-guides/cool-3x3-rubiks-cube-patterns>
<https://kewbz.co.uk/blogs/solutions-guides/4x4-patterns>
<https://kewbz.co.uk/blogs/solutions-guides/5x5-patterns>

Each fixture carries the specific page identifier (`kewbz3`, `kewbz4`, or
`kewbz5`) that supplied its algorithm. The 4x4 page gives its entries no names;
those variants are labelled by their stable page order, not by an inferred image
title. The notation is copied as functional move data, normalized only from
typographic to ASCII primes, and every resulting state token is independently
derived by replaying it from solved.

The associated notation guides informed acceptance of `Fw`/`Rw`, lower-case
inner slices, and `3Fw` on a 5x5x5:

<https://kewbz.co.uk/blogs/solutions-guides/4x4-notation>
<https://kewbz.co.uk/blogs/solutions-guides/5x5-notation>
