# cubesolve-cli

The demo command line for [`cubesolve`](https://github.com/wstein/flix-cubesolve):
solve, scramble, draw and identify NxNxN cubes. Kept as a separate package so
the library itself never defines a top-level `main`.

## Optional QR and PNG rendering

QR raster generation and isometric cube PNGs are in the separate
[`render-tool`](../render-tool/README.md) example. It owns the ZXing and Java
AWT dependencies; this command-line package intentionally has none, so normal
cube commands do not resolve external graphics JARs.

This is what a consuming project's `flix.toml` and `src/` look like -- it
depends on the published `cubesolve` package exactly the way any other
project would. It carries no wrapper of its own and is not driven by this
repository's `flixw`; run it with your own Flix install, or from the root
project with `./flixw examples run cli-tool -- <args>`:

```sh
# Using the repository flixw wrapper:
./flixw examples run cli-tool -- solve "R U R' U'"
./flixw examples run cli-tool -- solve --json "R U R' U'"
./flixw examples run cli-tool -- show "M2 E2 S2"
./flixw examples run cli-tool -- show --json "M2 E2 S2"
./flixw examples run cli-tool -- show --size 4 "AH0Hmo16YfPV7lTF3_VGkq_Ontg"
./flixw examples run cli-tool -- show "https://cubesolve.org/#FAMMxrnAODxtJQkle0CmnHZ3c8_Wiv8A78pj8T9iIN"
./flixw examples run cli-tool -- identify --json "AAAAAAAAAAf_"
./flixw examples run cli-tool -- scramble --json
./flixw examples run cli-tool -- patterns --json --size 2
./flixw examples run cli-tool -- help

# Or directly with your own Flix install:
cd examples/cli-tool
flix run -- solve "R U R' U'"
flix run -- show --json "AAAAAAAAAAf_"
```

All commands accepting cube inputs autodetect the input format:
- **Move notations**: Face turns (`R`, `U`), slice moves (`M`, `E`, `S`, `2D`), wide turns (`Rw`, `2-4Fw`), and reorientations (`x`, `y`, `z`).
- **Orbit64 tokens**: State tokens (`[A-Za-z0-9_-]`) with automatic size detection (2x2: 8 chars, 3x3: 12 chars, 4x4: 27 chars, 5x5: 42 chars).
- **URLs**: `https://cubesolve.org/#...` links containing tokens.

`show` renders a face-letter net through the dependency-free
`CubeSolve.Render.net` pretty-printer. Solver and method output is always
standard move notation, ready to paste into another command or timer.

The upcoming library parser will also accept a pasted rendered net as state
input. This released example intentionally does not duplicate that parser;
today, use its Orbit64 token form for state input.

```
$ ./flixw examples run cli-tool -- solve "R U R' U'"
U R U' R'
4 moves
```

Solve tables are cached under `$XDG_CACHE_HOME/cubesolve-cli` (or
`~/.cache/cubesolve-cli`) after the first run.

### `oll <scramble>` and `pll <scramble>`

Recognise a last-layer case and show how to finish it:

```
$ cubesolve pll "(R U R' U' R' F R2 U' R' U' R U R' F')'"
case      T-PLL
setup     none
algorithm R U R' U' R' F R2 U' R' U' R U R' F'
finish    none
sequence  R U R' U' R' F R2 U' R' U' R U R' F'
optimal   10 HTM published for this case; the algorithm above is
          speed-oriented, not shortest
source    https://www.speedsolving.com/wiki/index.php?title=PLL
```

Opt-in and separate from `solve`, which is unchanged: these recognise one
partial state and play back a memorised algorithm, where `solve` searches. Each
refuses anything that is not its case, saying which part is not ready.

Both take `--profile`, which chooses among the algorithms published for a case:

- `default` — the first the source lists
- `shortest` — fewest parsed layer turns, rotations not counted
- `no-rotations` — the first with no whole-cube rotation

A profile that cannot be applied says so rather than substituting quietly:

```
$ cubesolve oll --profile no-rotations "(r U R' U R U2 r')'"
case      Lightning, Wide Sune
profile   no-rotations
selected  default variant (no rotation-free variant is recorded for this
          case, so the first the source lists was used), 8 layer turns
```

Every PLL case has a rotation-free algorithm recorded; sixteen of the 57 OLL
cases do not.
