#!/usr/bin/env bash
#
# Gate 13.2 -- concurrent first-run generation by two processes produces one
# valid cache. Supported on macOS and Linux (and Windows via WSL or Git Bash).
#
# Two operating-system processes, not two threads: each gets its own JVM, its
# own open files and its own rename. That boundary is where the defect this
# gate excludes used to live, and it is the one thing the test suite cannot
# reach, since a @Test runs inside a single JVM.
#
# The sequence: build a jar whose entry point is the harness under test/, make
# a cache directory that has never existed, start two children with a readiness
# barrier so both JVMs finish initialization before racing, wait for both, then
# read the directory back refusing to rebuild anything. A file either survives
# the race intact or the read fails.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck source=scripts/overlay-common.sh
source "${ROOT_DIR}/scripts/overlay-common.sh"

JAVA_BIN="$(resolve_jvm "${ROOT_DIR}")"
export FLIX_JAVA_HOME="$(dirname "$(dirname "${JAVA_BIN}")")"
export JAVA_HOME="${FLIX_JAVA_HOME}"

jar="artifact/flix-cubesolve.jar"
rounds="${CUBESOLVE_RACE_ROUNDS:-5}"

# Validate rounds as positive integer
if ! [[ "${rounds}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: CUBESOLVE_RACE_ROUNDS must be a positive integer, got '${rounds}'" >&2
    exit 1
fi

echo "==> building the harness"
./flixw build-fatjar --entrypoint QualifyCacheRace.qualify

# A race that is lost is still a pass, so one round proves little. Repeat, and
# report the round number, because a failure here is a scheduling accident that
# has to be reproducible enough to debug.
for round in $(seq 1 "$rounds"); do
    dir="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-gate-13-2.XXXXXXXX")"
    barrier_dir="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-barrier.XXXXXXXX")"
    trap 'rm -rf "${dir}" "${barrier_dir}"' EXIT

    echo "==> round ${round}/${rounds}: two synchronized processes into ${dir}"
    "${JAVA_BIN}" -jar "${jar}" child "${dir}" "${barrier_dir}" "1" &
    left=$!
    "${JAVA_BIN}" -jar "${jar}" child "${dir}" "${barrier_dir}" "2" &
    right=$!

    # Wait for both child JVMs to signal readiness before releasing them
    timeout_count=0
    while [ ! -f "${barrier_dir}/ready_1" ] || [ ! -f "${barrier_dir}/ready_2" ]; do
        if ! kill -0 "${left}" 2>/dev/null || ! kill -0 "${right}" 2>/dev/null; then
            echo "FAIL (round ${round}): a child JVM exited prematurely before reaching barrier" >&2
            exit 1
        fi
        sleep 0.05
        timeout_count=$((timeout_count + 1))
        if [ "${timeout_count}" -gt 200 ]; then # 10 seconds timeout
            echo "FAIL (round ${round}): timeout waiting for child JVMs to signal barrier readiness" >&2
            exit 1
        fi
    done

    # Release both processes simultaneously
    touch "${barrier_dir}/go"

    failed=0
    wait "${left}" || failed=1
    wait "${right}" || failed=1
    if [ "${failed}" -ne 0 ]; then
        echo "FAIL (round ${round}): a generating process exited non-zero"
        exit 1
    fi

    if ! "${JAVA_BIN}" -jar "${jar}" verify "${dir}"; then
        echo "FAIL (round ${round}): the cache the race left is not readable"
        echo "       the directory is kept for inspection: ${dir}"
        trap - EXIT
        exit 1
    fi

    rm -rf "${dir}" "${barrier_dir}"
    trap - EXIT
done

echo "==> Gate 13.2: ${rounds} rounds, every one left a single valid cache"
