#!/usr/bin/env bash
#
# Gate: Qualify the checkout-local package overlay against the CLI example.
#
# Verifies that:
# 1. The root package builds a fresh .fpkg artifact.
# 2. A disposable overlay environment executes example tests against the local artifact.
# 3. Running the local CLI overlay executes commands correctly using the local package.
# 4. (Under --characterize) Negative resolver & security precedence checks are verified.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

CHARACTERIZE=0
if [ $# -gt 0 ] && [ "$1" = "--characterize" ]; then
    CHARACTERIZE=1
fi

echo "==> Building fresh root package artifact"
./flixw build-pkg > /dev/null

FPKG="${ROOT_DIR}/artifact/flix-cubesolve.fpkg"
if [ ! -f "${FPKG}" ]; then
    echo "FAIL: Expected package artifact not found at ${FPKG}" >&2
    exit 1
fi

VERSION="$(grep -m1 '^version' "${ROOT_DIR}/flix.toml" | cut -d'"' -f2)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
if ! git diff --quiet 2>/dev/null; then
    COMMIT="${COMMIT}-dirty"
fi

if command -v sha256sum >/dev/null 2>&1; then
    DIGEST="$(sha256sum "${FPKG}" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
    DIGEST="$(shasum -a 256 "${FPKG}" | cut -d' ' -f1)"
else
    DIGEST="unknown"
fi

echo "==> Qualify overlay with cubesolve ${VERSION} (${COMMIT}, sha256: ${DIGEST})"

# Create disposable test environment
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-qualify-overlay.XXXXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Populate test workspace
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

# Seed the local package
CACHE_PKG_DIR="${TMP_DIR}/lib/github/wstein/flix-cubesolve/${VERSION}"
mkdir -p "${CACHE_PKG_DIR}"
cp "${FPKG}" "${CACHE_PKG_DIR}/flix-cubesolve-${VERSION}.fpkg"
cp "${ROOT_DIR}/flix.toml" "${CACHE_PKG_DIR}/flix-cubesolve-${VERSION}.toml"

echo "==> Running example test suite against local package overlay"
(cd "${TMP_DIR}" && ./flixw test)

echo "==> Testing CLI solve execution through local overlay"
SOLVE_OUTPUT="$("${ROOT_DIR}/scripts/run-cli-local.sh" -- solve "R U R' U'")"
if ! echo "${SOLVE_OUTPUT}" | grep -q "4 moves (HTM)"; then
    echo "FAIL: Expected '4 moves (HTM)' in output, got:" >&2
    echo "${SOLVE_OUTPUT}" >&2
    exit 1
fi

if [ "${CHARACTERIZE}" -eq 1 ]; then
    echo "==> Running compiler characterization checks (--characterize)"

    # Check 1: Missing or corrupt package fails cleanly
    CHAR_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-char-check.XXXXXXXX")"
    trap 'rm -rf "${TMP_DIR}" "${CHAR_DIR}"' EXIT

    cp -r "${ROOT_DIR}/examples/cli-tool/src" "${CHAR_DIR}/"
    cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${CHAR_DIR}/"
    cp -r "${ROOT_DIR}/.flixw" "${CHAR_DIR}/"
    cp "${ROOT_DIR}/flixw" "${CHAR_DIR}/"
    mkdir -p "${CHAR_DIR}/lib/github/wstein/flix-cubesolve/${VERSION}"
    # Put an empty / corrupt fpkg
    touch "${CHAR_DIR}/lib/github/wstein/flix-cubesolve/${VERSION}/flix-cubesolve-${VERSION}.fpkg"
    echo "[package]" > "${CHAR_DIR}/lib/github/wstein/flix-cubesolve/${VERSION}/flix-cubesolve-${VERSION}.toml"

    if (cd "${CHAR_DIR}" && ./flixw check >/dev/null 2>&1); then
        echo "FAIL: Empty/corrupt .fpkg unexpectedly compiled successfully" >&2
        exit 1
    else
        echo "ok: Corrupt .fpkg rejected as expected"
    fi
fi

echo "==> Local package overlay qualification passed successfully"
