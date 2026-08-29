#!/usr/bin/env bash
#
# Gate 13.2 -- concurrent first-run generation by two processes produces one
# valid cache.
#
# Two operating-system processes, not two threads: each gets its own JVM, its
# own open files and its own rename. That boundary is where the defect this
# gate excludes used to live, and it is the one thing the test suite cannot
# reach, since a @Test runs inside a single JVM.
#
# The sequence: build a jar whose entry point is the harness under test/, make
# a cache directory that has never existed, start two children on it at the
# same moment, wait for both, then read the directory back refusing to rebuild
# anything. A file either survives the race intact or the read fails.
#
set -euo pipefail

cd "$(dirname "$0")/.."

jar="artifact/flix-cubesolve.jar"
rounds="${CUBESOLVE_RACE_ROUNDS:-5}"

echo "==> building the harness"
./flixw build-fatjar --entrypoint QualifyCacheRace.qualify

# A race that is lost is still a pass, so one round proves little. Repeat, and
# report the round number, because a failure here is a scheduling accident that
# has to be reproducible enough to debug.
for round in $(seq 1 "$rounds"); do
    dir="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-gate-13-2.XXXXXXXX")"
    trap 'rm -rf "${dir}"' EXIT

    echo "==> round ${round}/${rounds}: two processes into ${dir}"
    java -jar "${jar}" child "${dir}" &
    left=$!
    java -jar "${jar}" child "${dir}" &
    right=$!

    failed=0
    wait "${left}" || failed=1
    wait "${right}" || failed=1
    if [ "${failed}" -ne 0 ]; then
        echo "FAIL (round ${round}): a generating process exited non-zero"
        exit 1
    fi

    if ! java -jar "${jar}" verify "${dir}"; then
        echo "FAIL (round ${round}): the cache the race left is not readable"
        echo "       the directory is kept for inspection: ${dir}"
        trap - EXIT
        exit 1
    fi

    rm -rf "${dir}"
    trap - EXIT
done

echo "==> Gate 13.2: ${rounds} rounds, every one left a single valid cache"
