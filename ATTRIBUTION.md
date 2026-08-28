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

**One discrepancy, recorded openly.** The READMEs present both licences without
stating "at your option," and **cube555 additionally ships a `LICENSE` file
containing GPL v3 text only**; the other two ship no separate licence file.

The practical exposure is narrow: cube555 is the repository from which no code
is taken. Ported code is restricted to min2phase, whose README carries the MIT
grant and which ships no contradicting `LICENSE` file.

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

Apache-2.0. See [LICENSE](LICENSE).
