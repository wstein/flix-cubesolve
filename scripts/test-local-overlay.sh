#!/usr/bin/env bash
#
# Integration test suite for the local CLI runner and caching overlay.
# Verifies cold build, warm hit, sidecar corruption recovery, concurrent writers,
# argument forwarding, and --no-cache bypass.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

CACHE_DIR="${ROOT_DIR}/tmp/local-overlay-cache"

echo "==> Testing local CLI runner matrix"

# 1. Cold build / miss
echo "--- 1. Cold build ---"
rm -rf "${CACHE_DIR}"
OUT_COLD="$("${ROOT_DIR}/scripts/run-cli-local.sh" -- solve "R U R' U'")"
if ! echo "${OUT_COLD}" | grep -q "cache: miss (building)"; then
    echo "FAIL: Expected 'cache: miss (building)' on cold run" >&2
    echo "${OUT_COLD}" >&2
    exit 1
fi
if ! echo "${OUT_COLD}" | grep -q "4 moves (HTM)"; then
    echo "FAIL: Expected solution in output" >&2
    exit 1
fi
echo "ok: Cold build produced solution and cached JAR"

# 2. Warm cache hit
echo "--- 2. Warm cache hit ---"
OUT_WARM="$("${ROOT_DIR}/scripts/run-cli-local.sh" -- solve "R U R' U'")"
if ! echo "${OUT_WARM}" | grep -q "cache: hit"; then
    echo "FAIL: Expected 'cache: hit' on repeated run" >&2
    echo "${OUT_WARM}" >&2
    exit 1
fi
echo "ok: Repeated run used cached JAR"

# 3. Corrupted JAR recovery
echo "--- 3. Corrupted JAR integrity verification ---"
CACHED_JAR="$(find "${CACHE_DIR}" -name "*.jar" | head -n 1)"
echo "CORRUPTED_BYTES" >> "${CACHED_JAR}"
OUT_CORRUPT="$("${ROOT_DIR}/scripts/run-cli-local.sh" -- solve "R U R' U'" 2>&1)"
if ! echo "${OUT_CORRUPT}" | grep -q "warning: cached jar failed integrity check, rebuilding"; then
    echo "FAIL: Runner did not detect corrupted cached JAR" >&2
    echo "${OUT_CORRUPT}" >&2
    exit 1
fi
if ! echo "${OUT_CORRUPT}" | grep -q "4 moves (HTM)"; then
    echo "FAIL: Runner failed to recover and solve after corruption" >&2
    exit 1
fi
echo "ok: Corrupted JAR was detected, evicted, and rebuilt cleanly"

# 4. No-cache bypass
echo "--- 4. CUBESOLVE_NO_CACHE=1 bypass ---"
OUT_NOCACHE="$(CUBESOLVE_NO_CACHE=1 "${ROOT_DIR}/scripts/run-cli-local.sh" -- solve "R U R' U'")"
if ! echo "${OUT_NOCACHE}" | grep -q "cache: miss (building)"; then
    echo "FAIL: CUBESOLVE_NO_CACHE=1 did not force rebuild" >&2
    exit 1
fi
echo "ok: No-cache bypass verified"

# 5. Argument forwarding (--no-net, -q)
echo "--- 5. Argument forwarding ---"
OUT_NONET="$("${ROOT_DIR}/scripts/run-cli-local.sh" -- solve "R U R' U'" --no-net)"
if echo "${OUT_NONET}" | grep -q "┌───"; then
    echo "FAIL: --no-net still printed net" >&2
    exit 1
fi
if ! echo "${OUT_NONET}" | grep -q "4 moves (HTM)"; then
    echo "FAIL: --no-net omitted solution" >&2
    exit 1
fi
echo "ok: Option flags forwarded properly"

# 6. Concurrent writers stress test
echo "--- 6. Concurrent writers stress test (5 parallel processes on empty cache) ---"
rm -rf "${CACHE_DIR}"
pids=()
for i in {1..5}; do
    "${ROOT_DIR}/scripts/run-cli-local.sh" -- solve "R U R' U'" >/dev/null 2>&1 &
    pids+=($!)
done

failed_concurrency=0
for pid in "${pids[@]}"; do
    wait "${pid}" || failed_concurrency=1
done

if [ "${failed_concurrency}" -ne 0 ]; then
    echo "FAIL: Concurrent runner processes collided" >&2
    exit 1
fi
echo "ok: Concurrent execution completed without writer collisions"

echo "==> All local CLI overlay integration tests passed successfully"
