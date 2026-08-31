#!/usr/bin/env bash
#
# Run the CLI tool against the local package build in the current checkout.
# Supported on macOS and Linux (and Windows via WSL or Git Bash).
#
# Caches the compiled CLI fatjar under tmp/local-overlay-cache/<hash>.jar keyed
# by the combined SHA-256 digest of library sources, example sources, manifests,
# compiler lock, and dependency caches. If inputs are unchanged and integrity
# verifies against the sidecar, repeated runs execute the cached jar directly
# with zero compilation overhead. If any source changes or corruption is
# detected, a fresh fatjar is built inside a disposable temporary overlay and
# cached atomically.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck source=scripts/overlay-common.sh
source "${ROOT_DIR}/scripts/overlay-common.sh"

CACHE_DIR="${ROOT_DIR}/tmp/local-overlay-cache"
mkdir -p "${CACHE_DIR}"

# 1. Discover Java runtime
JAVA_BIN="$(resolve_jvm "${ROOT_DIR}")"
export FLIX_JAVA_HOME="$(dirname "$(dirname "${JAVA_BIN}")")"
export JAVA_HOME="${FLIX_JAVA_HOME}"

# 2. Extract metadata
VERSION="$(grep -m1 '^version' "${ROOT_DIR}/flix.toml" | cut -d'"' -f2)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    COMMIT="${COMMIT}-dirty"
fi

COMPILER="$(grep -m1 '^version' "${ROOT_DIR}/.flixw/lock.toml" | cut -d'"' -f2)"

# 3. Compute inputs digest
INPUT_HASH="$(compute_inputs_digest "${ROOT_DIR}")"
CACHED_JAR="${CACHE_DIR}/${INPUT_HASH}.jar"

# Pass arguments following '--' if specified
if [ $# -gt 0 ] && [ "$1" = "--" ]; then
    shift
fi

# 4. Check for valid cache hit
if [ "${CUBESOLVE_NO_CACHE:-0}" != "1" ] && [ -f "${CACHED_JAR}" ]; then
    if verify_cached_jar "${CACHED_JAR}"; then
        echo "local package: cubesolve ${VERSION}"
        echo "source: ${COMMIT}"
        echo "cache: hit (${INPUT_HASH:0:12})"
        echo "compiler: ${COMPILER}"
        echo "consumer: cached local build"
        exec "${JAVA_BIN}" -jar "${CACHED_JAR}" "$@"
    else
        echo "warning: cached jar failed integrity check, rebuilding" >&2
        rm -f "${CACHED_JAR}" "${CACHED_JAR}.sha256"
    fi
fi

# Acquire per-key compilation lock to prevent concurrent build races
LOCK_DIR="${CACHE_DIR}/.lock_${INPUT_HASH}"
acquire_lock "${LOCK_DIR}"
cleanup_lock() {
    release_lock "${LOCK_DIR}"
}
trap cleanup_lock EXIT

# Re-check after acquiring lock in case another process just finished building
if [ "${CUBESOLVE_NO_CACHE:-0}" != "1" ] && [ -f "${CACHED_JAR}" ]; then
    if verify_cached_jar "${CACHED_JAR}"; then
        release_lock "${LOCK_DIR}"
        trap - EXIT
        echo "local package: cubesolve ${VERSION}"
        echo "source: ${COMMIT}"
        echo "cache: hit (${INPUT_HASH:0:12})"
        echo "compiler: ${COMPILER}"
        echo "consumer: cached local build"
        exec "${JAVA_BIN}" -jar "${CACHED_JAR}" "$@"
    fi
fi

# 5. Cache miss: build fresh package and fatjar in disposable overlay
echo "local package: cubesolve ${VERSION}"
echo "source: ${COMMIT}"
echo "cache: miss (building)"
echo "compiler: ${COMPILER}"
echo "consumer: disposable local overlay"

./flixw build-pkg > /dev/null

FPKG="${ROOT_DIR}/artifact/flix-cubesolve.fpkg"
if [ ! -f "${FPKG}" ]; then
    echo "Error: expected package artifact not found at ${FPKG}" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-cli-local.XXXXXXXX")"
cleanup_all() {
    rm -rf "${TMP_DIR}" 2>/dev/null || true
    release_lock "${LOCK_DIR}"
}
trap cleanup_all EXIT

# Populate disposable overlay with tracked wrapper only (no .flixw/local)
cp -r "${ROOT_DIR}/examples/cli-tool/src" "${TMP_DIR}/"
if [ -d "${ROOT_DIR}/examples/cli-tool/test" ]; then
    cp -r "${ROOT_DIR}/examples/cli-tool/test" "${TMP_DIR}/"
fi
cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${TMP_DIR}/"
stage_tracked_wrapper "${ROOT_DIR}" "${TMP_DIR}"
seed_dependency_cache "${ROOT_DIR}" "${TMP_DIR}"
seed_local_package "${ROOT_DIR}" "${TMP_DIR}" "${FPKG}" "${VERSION}"

# Build fatjar inside overlay
(cd "${TMP_DIR}" && ./flixw build-fatjar > /dev/null)

# Assert exactly one jar was generated
JAR_COUNT="$(find "${TMP_DIR}/artifact" -name "*.jar" 2>/dev/null | wc -l | tr -d ' ')"
if [ "${JAR_COUNT}" -ne 1 ]; then
    echo "Error: expected exactly 1 built fatjar, found ${JAR_COUNT}" >&2
    exit 1
fi

BUILT_JAR="$(find "${TMP_DIR}/artifact" -name "*.jar" | head -n 1)"

# Atomically cache the built fatjar with sidecar
atomic_cache_jar "${BUILT_JAR}" "${CACHED_JAR}" "${CACHE_DIR}"

# Cleanup overlay and lock before exec replaces shell process
rm -rf "${TMP_DIR}" 2>/dev/null || true
release_lock "${LOCK_DIR}"
trap - EXIT

# Execute
exec "${JAVA_BIN}" -jar "${CACHED_JAR}" "$@"
