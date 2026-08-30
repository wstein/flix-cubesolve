# cubesolve-cli

The demo command line for [`cubesolve`](https://github.com/wstein/flix-cubesolve):
solve, scramble, draw and identify NxNxN cubes. Kept as a separate package so
the library itself never defines a top-level `main`.

This is what a consuming project's `flix.toml` and `src/` look like -- it
depends on the published `cubesolve` package exactly the way any other
project would. It carries no wrapper of its own and is not driven by this
repository's `flixw`; run it with your own Flix install, or from the root
project with `./flixw examples run cli-tool -- <args>`:

```
cd examples/cli-tool
flix run -- solve R U R' U'
flix run -- show R U R' U'
flix run -- identify R U R' U'
flix run -- scramble
flix run -- patterns --size 2
flix run -- help
```

```
$ flix run -- solve R U R' U'
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
