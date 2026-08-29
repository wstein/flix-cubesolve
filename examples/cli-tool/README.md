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
