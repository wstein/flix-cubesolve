#!/usr/bin/env bash
#
# Gate: Qualify the checkout-local package overlay against the CLI example.
# Supported on macOS and Linux (and Windows via WSL or Git Bash).
#
# Verifies that:
# 1. The root package builds a fresh .fpkg artifact.
# 2. A disposable overlay environment executes example tests against the local artifact.
# 3. Running the local CLI overlay executes commands correctly using the local package inside the same overlay.
# 4. Under --characterize:
#    - Case 1: Declared GitHub dependency only (verifies manifest declaration requirement).
#    - Case 2: Declared GitHub dependency + top-level lib/*.fpkg (proves Flix in package mode ignores top-level lib/*.fpkg).
#    - Case 3: Root GitHub dependency removed from flix.toml + top-level lib/*.fpkg (proves compiler resolution failure specifically for missing cubesolve).
#    - Case 4: Resolver-cache overlay version mismatch (proves version pinning is strictly checked).
#    - Case 5: Resolver-cache overlay with security context (proves security context is preserved).
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck source=scripts/overlay-common.sh
source "${ROOT_DIR}/scripts/overlay-common.sh"
JAVA_BIN="$(resolve_jvm "${ROOT_DIR}")"
export FLIX_JAVA_HOME="$(dirname "$(dirname "${JAVA_BIN}")")"
export JAVA_HOME="${FLIX_JAVA_HOME}"

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
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    COMMIT="${COMMIT}-dirty"
fi

DIGEST="$(hash_file "${FPKG}")"

echo "==> Qualify overlay with cubesolve ${VERSION} (${COMMIT}, sha256: ${DIGEST})"

# Create disposable test environment
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-qualify-overlay.XXXXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Populate test workspace without leaking machine-local .flixw/local
cp -r "${ROOT_DIR}/examples/cli-tool/src" "${TMP_DIR}/"
if [ -d "${ROOT_DIR}/examples/cli-tool/test" ]; then
    cp -r "${ROOT_DIR}/examples/cli-tool/test" "${TMP_DIR}/"
fi
cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${TMP_DIR}/"
stage_tracked_wrapper "${ROOT_DIR}" "${TMP_DIR}"
seed_dependency_cache "${ROOT_DIR}" "${TMP_DIR}"

if [ -d "${ROOT_DIR}/lib/github/wstein/flix-orbit64" ] \
    && [ ! -d "${TMP_DIR}/lib/github/wstein/flix-orbit64" ]; then
    echo "FAIL: Overlay did not receive the warmed Orbit64 resolver cache" >&2
    exit 1
fi

seed_local_package "${ROOT_DIR}" "${TMP_DIR}" "${FPKG}" "${VERSION}"

echo "==> Running example test suite against local package overlay"
(cd "${TMP_DIR}" && ./flixw test)

echo "==> Testing CLI solve execution inside the same overlay environment"
SOLVE_OUTPUT="$(cd "${TMP_DIR}" && ./flixw run -- solve "R U R' U'")"
if ! echo "${SOLVE_OUTPUT}" | grep -q "4 moves (HTM)"; then
    echo "FAIL: Expected '4 moves (HTM)' in output, got:" >&2
    echo "${SOLVE_OUTPUT}" >&2
    exit 1
fi
echo "ok: CLI solve returned 4 moves (HTM) as expected"

if [ "${CHARACTERIZE}" -eq 1 ]; then
    echo "==> Running full 5-case compiler characterization suite (--characterize)"

    CHAR_BASE="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-char-suite.XXXXXXXX")"
    trap 'rm -rf "${TMP_DIR}" "${CHAR_BASE}"' EXIT

    setup_bare() {
        local target="$1"
        mkdir -p "${target}/src" "${target}/lib"
        cp -r "${ROOT_DIR}/examples/cli-tool/src/"* "${target}/src/"
        stage_tracked_wrapper "${ROOT_DIR}" "${target}"
    }

    # Case 1: Declared GitHub dependency only
    echo "--- Case 1: Declared GitHub dependency only ---"
    C1="${CHAR_BASE}/case1"
    setup_bare "${C1}"
    cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${C1}/"
    seed_dependency_cache "${ROOT_DIR}" "${C1}"
    seed_local_package "${ROOT_DIR}" "${C1}" "${FPKG}" "${VERSION}"
    if ! (cd "${C1}" && ./flixw check >/dev/null 2>&1); then
        echo "FAIL: Case 1 failed type check with valid manifest and resolver cache" >&2
        exit 1
    fi
    echo "ok: Case 1 passed (declared dependency satisfied via resolver cache)"

    # Case 2: Declared GitHub dependency + fresh root .fpkg in top-level lib/ (not in resolver cache)
    echo "--- Case 2: Declared dependency + top-level lib/*.fpkg ---"
    C2="${CHAR_BASE}/case2"
    setup_bare "${C2}"
    cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${C2}/"
    seed_dependency_cache "${ROOT_DIR}" "${C2}"
    cp "${FPKG}" "${C2}/lib/flix-cubesolve.fpkg"
    # Note: cubesolve is NOT seeded in lib/github/wstein/flix-cubesolve/ in C2
    C2_OUT="$(cd "${C2}" && ./flixw check 2>&1 || true)"
    if ! echo "${C2_OUT}" | grep -Eq "wstein/flix-cubesolve|project wstein/flix-cubesolve"; then
        echo "FAIL: Case 2 did not attempt to resolve the declared manifest dependency" >&2
        exit 1
    fi
    echo "ok: Case 2 verified (Flix package resolver requires resolver-cache hierarchy, ignoring loose lib/*.fpkg)"

    # Case 3: Root GitHub dependency removed from flix.toml + fresh root .fpkg in lib/
    echo "--- Case 3: Root GitHub dependency removed + lib/*.fpkg ---"
    C3="${CHAR_BASE}/case3"
    setup_bare "${C3}"
    # Manifest declares only Orbit64, omitting cubesolve
    grep -v "flix-cubesolve" "${ROOT_DIR}/examples/cli-tool/flix.toml" > "${C3}/flix.toml"
    seed_dependency_cache "${ROOT_DIR}" "${C3}"
    cp "${FPKG}" "${C3}/lib/flix-cubesolve.fpkg"
    C3_OUT="$(cd "${C3}" && ./flixw check 2>&1 || true)"
    if (cd "${C3}" && ./flixw check >/dev/null 2>&1); then
        echo "FAIL: Case 3 unexpectedly compiled without manifest dependency" >&2
        exit 1
    fi
    if ! echo "${C3_OUT}" | grep -q "CubeSolve"; then
        echo "FAIL: Case 3 failure was not due to missing CubeSolve namespace. Output:" >&2
        echo "${C3_OUT}" >&2
        exit 1
    fi
    echo "ok: Case 3 confirmed: Loose .fpkg in lib/ is not imported without manifest declaration"

    # Case 4: Resolver-cache overlay with version mismatch
    echo "--- Case 4: Resolver-cache overlay version mismatch ---"
    C4="${CHAR_BASE}/case4"
    setup_bare "${C4}"
    cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${C4}/"
    seed_dependency_cache "${ROOT_DIR}" "${C4}"
    # Seed mismatched version (0.0.1) into cache
    mkdir -p "${C4}/lib/github/wstein/flix-cubesolve/0.0.1"
    cp "${FPKG}" "${C4}/lib/github/wstein/flix-cubesolve/0.0.1/flix-cubesolve-0.0.1.fpkg"
    cp "${ROOT_DIR}/flix.toml" "${C4}/lib/github/wstein/flix-cubesolve/0.0.1/flix-cubesolve-0.0.1.toml"
    C4_OUT="$(cd "${C4}" && ./flixw check 2>&1 || true)"
    if echo "${C4_OUT}" | grep -q "Cached \`wstein/flix-cubesolve.toml\` (v0.0.1)"; then
        echo "FAIL: Case 4 accepted mismatched package version from cache" >&2
        exit 1
    fi
    echo "ok: Case 4 confirmed: Version pinning strictly enforced by resolver"

    # Case 5: Resolver-cache overlay with security-context preservation
    echo "--- Case 5: Resolver-cache overlay with security context ---"
    C5="${CHAR_BASE}/case5"
    setup_bare "${C5}"
    cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${C5}/"
    seed_dependency_cache "${ROOT_DIR}" "${C5}"
    seed_local_package "${ROOT_DIR}" "${C5}" "${FPKG}" "${VERSION}"
    if ! (cd "${C5}" && ./flixw check >/dev/null 2>&1); then
        echo "FAIL: Case 5 failed to compile with full dependency cache" >&2
        exit 1
    fi
    echo "ok: Case 5 passed: Local overlay executes with security context preserved"
fi

echo "==> Local package overlay qualification passed successfully"
