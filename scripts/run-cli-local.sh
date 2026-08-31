#!/usr/bin/env bash
#
# Run the CLI tool against the local package build in the current checkout.
#
# This creates a disposable, isolated consumer overlay in a temporary directory
# using Flix's resolver-cache mechanism (lib/github/wstein/flix-cubesolve/<version>)
# so you can develop and test CLI features against unreleased or in-flight library
# changes without publishing or modifying the committed example manifest.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

# 1. Build the local package
./flixw build-pkg > /dev/null

FPKG="${ROOT_DIR}/artifact/flix-cubesolve.fpkg"
if [ ! -f "${FPKG}" ]; then
    echo "Error: expected package artifact not found at ${FPKG}" >&2
    exit 1
fi

# 2. Extract metadata
VERSION="$(grep -m1 '^version' "${ROOT_DIR}/flix.toml" | cut -d'"' -f2)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    COMMIT="${COMMIT}-dirty"
fi

if command -v sha256sum >/dev/null 2>&1; then
    DIGEST="$(sha256sum "${FPKG}" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
    DIGEST="$(shasum -a 256 "${FPKG}" | cut -d' ' -f1)"
else
    DIGEST="unknown"
fi

COMPILER="$(grep -m1 '^version' "${ROOT_DIR}/.flixw/lock.toml" | cut -d'"' -f2)"

# 3. Print provenance banner
echo "local package: cubesolve ${VERSION}"
echo "source: ${COMMIT}"
echo "artifact sha256: ${DIGEST}"
echo "compiler: ${COMPILER}"
echo "consumer: disposable local overlay"

# 4. Create disposable consumer directory
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cubesolve-cli-local.XXXXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

# 5. Populate disposable workspace
cp -r "${ROOT_DIR}/examples/cli-tool/src" "${TMP_DIR}/"
if [ -d "${ROOT_DIR}/examples/cli-tool/test" ]; then
    cp -r "${ROOT_DIR}/examples/cli-tool/test" "${TMP_DIR}/"
fi
cp "${ROOT_DIR}/examples/cli-tool/flix.toml" "${TMP_DIR}/"
cp -r "${ROOT_DIR}/.flixw" "${TMP_DIR}/"
cp "${ROOT_DIR}/flixw" "${TMP_DIR}/"

# Re-use cached external dependencies if available to avoid unnecessary downloads
if [ -d "${ROOT_DIR}/examples/cli-tool/lib" ]; then
    mkdir -p "${TMP_DIR}/lib"
    cp -r "${ROOT_DIR}/examples/cli-tool/lib/"* "${TMP_DIR}/lib/" 2>/dev/null || true
fi

# Seed the local package into the consumer resolver cache
CACHE_PKG_DIR="${TMP_DIR}/lib/github/wstein/flix-cubesolve/${VERSION}"
mkdir -p "${CACHE_PKG_DIR}"
cp "${FPKG}" "${CACHE_PKG_DIR}/flix-cubesolve-${VERSION}.fpkg"
cp "${ROOT_DIR}/flix.toml" "${CACHE_PKG_DIR}/flix-cubesolve-${VERSION}.toml"

# 6. Run the CLI tool with provided arguments
if [ $# -gt 0 ] && [ "$1" = "--" ]; then
    shift
fi

cd "${TMP_DIR}"
./flixw run -- "$@"
