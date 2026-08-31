#!/usr/bin/env bash
#
# Run the CLI tool against the local package build in the current checkout.
#
# Caches the compiled CLI fatjar under tmp/local-overlay-cache/<hash>.jar keyed
# by the combined SHA-256 digest of library sources, example sources, manifests,
# and compiler lock. If inputs are unchanged, repeated runs execute the cached
# jar directly with zero compilation overhead. If any source changes, a fresh
# fatjar is built inside a disposable temporary overlay.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

CACHE_DIR="${ROOT_DIR}/tmp/local-overlay-cache"
mkdir -p "${CACHE_DIR}"

# 1. Discover Java runtime
if [ -f "${ROOT_DIR}/.flixw/local/java" ]; then
    JAVA_BIN="$(cat "${ROOT_DIR}/.flixw/local/java")"
else
    JAVA_BIN="$(command -v java || echo "")"
fi

if [ -z "${JAVA_BIN}" ] || [ ! -x "${JAVA_BIN}" ]; then
    echo "Error: Java runtime not found" >&2
    exit 1
fi

# 2. Extract metadata
VERSION="$(grep -m1 '^version' "${ROOT_DIR}/flix.toml" | cut -d'"' -f2)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    COMMIT="${COMMIT}-dirty"
fi

COMPILER="$(grep -m1 '^version' "${ROOT_DIR}/.flixw/lock.toml" | cut -d'"' -f2)"

# Helper for cross-platform SHA-256 hashing
compute_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        (
            find src examples/cli-tool/src -type f | sort | xargs sha256sum
            sha256sum flix.toml examples/cli-tool/flix.toml .flixw/lock.toml
        ) | sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        (
            find src examples/cli-tool/src -type f | sort | xargs shasum -a 256
            shasum -a 256 flix.toml examples/cli-tool/flix.toml .flixw/lock.toml
        ) | shasum -a 256 | cut -d' ' -f1
    else
        echo "unknown"
    fi
}

INPUT_HASH="$(compute_hash)"
CACHED_JAR="${CACHE_DIR}/${INPUT_HASH}.jar"

# Pass arguments following '--' if specified
if [ $# -gt 0 ] && [ "$1" = "--" ]; then
    shift
fi

# 3. Check for cache hit
if [ -f "${CACHED_JAR}" ] && [ "${CUBESOLVE_NO_CACHE:-0}" != "1" ]; then
    echo "local package: cubesolve ${VERSION}"
    echo "source: ${COMMIT}"
    echo "cache: hit (${INPUT_HASH:0:12})"
    echo "compiler: ${COMPILER}"
    echo "consumer: cached local build"
    exec "${JAVA_BIN}" -jar "${CACHED_JAR}" "$@"
fi

# 4. Cache miss: build fresh package and fatjar in disposable overlay
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
trap 'rm -rf "${TMP_DIR}"' EXIT

# Populate disposable overlay
cp -r "${ROOT_DIR}/examples/cli-tool/src" "${TMP_DIR}/"
if [ -d "${ROOT_DIR}/examples/cli-tool/test" ]; then
    cp -r "${ROOT_DIR}/examples/cli-tool/test" "${TMP_DIR}/"
fi
cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${TMP_DIR}/"
cp -r "${ROOT_DIR}/.flixw" "${TMP_DIR}/"
cp "${ROOT_DIR}/flixw" "${TMP_DIR}/"

if [ -d "${ROOT_DIR}/examples/cli-tool/lib" ]; then
    mkdir -p "${TMP_DIR}/lib"
    cp -r "${ROOT_DIR}/examples/cli-tool/lib/"* "${TMP_DIR}/lib/" 2>/dev/null || true
fi
if [ -d "${ROOT_DIR}/lib/github" ]; then
    mkdir -p "${TMP_DIR}/lib"
    cp -r "${ROOT_DIR}/lib/github" "${TMP_DIR}/lib/"
fi

# Seed the local package into the consumer resolver cache
CACHE_PKG_DIR="${TMP_DIR}/lib/github/wstein/flix-cubesolve/${VERSION}"
mkdir -p "${CACHE_PKG_DIR}"
cp "${FPKG}" "${CACHE_PKG_DIR}/flix-cubesolve-${VERSION}.fpkg"
cp "${ROOT_DIR}/flix.toml" "${CACHE_PKG_DIR}/flix-cubesolve-${VERSION}.toml"

# Build fatjar inside overlay
(cd "${TMP_DIR}" && ./flixw build-fatjar > /dev/null)

BUILT_JAR="$(find "${TMP_DIR}/artifact" -name "*.jar" 2>/dev/null | head -n 1)"
if [ -z "${BUILT_JAR}" ] || [ ! -f "${BUILT_JAR}" ]; then
    echo "Error: failed to build CLI fatjar" >&2
    exit 1
fi

# Atomically update the persistent cache
cp "${BUILT_JAR}" "${CACHED_JAR}.tmp"
mv "${CACHED_JAR}.tmp" "${CACHED_JAR}"

# Execute
exec "${JAVA_BIN}" -jar "${CACHED_JAR}" "$@"
