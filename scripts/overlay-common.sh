#!/usr/bin/env bash
#
# Shared overlay helpers for local CLI runner, qualification, and characterization.
# Supported on macOS and Linux (and Windows via WSL or Git Bash).
#
set -euo pipefail

# Discover the exact JVM resolved by flixw / system
resolve_jvm() {
    local root="$1"
    local java_bin=""

    if [ -f "${root}/.flixw/local/java" ]; then
        local candidate
        candidate="$(cat "${root}/.flixw/local/java" 2>/dev/null || true)"
        if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
            java_bin="${candidate}"
        fi
    fi

    if [ -z "${java_bin}" ]; then
        java_bin="$(command -v java || echo "")"
    fi

    if [ -z "${java_bin}" ] || [ ! -x "${java_bin}" ]; then
        echo "Error: Java runtime not found (checked .flixw/local/java and PATH)" >&2
        return 1
    fi

    local java_home
    java_home="$(dirname "$(dirname "${java_bin}")")"
    export FLIX_JAVA_HOME="${FLIX_JAVA_HOME:-${java_home}}"
    export JAVA_HOME="${JAVA_HOME:-${java_home}}"

    echo "${java_bin}"
}

# Cross-platform SHA-256 stream hashing
hash_stream() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | cut -d' ' -f1
    else
        echo "Error: neither sha256sum nor shasum found" >&2
        return 1
    fi
}

# Cross-platform SHA-256 file hashing
hash_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${file}" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "${file}" | cut -d' ' -f1
    else
        echo "Error: neither sha256sum nor shasum found" >&2
        return 1
    fi
}

# Stage only tracked wrapper files (never leaking untracked machine-local .flixw/local)
stage_tracked_wrapper() {
    local root="$1"
    local target="$2"

    mkdir -p "${target}/.flixw"
    cp "${root}/flixw" "${target}/"
    if [ -f "${root}/flixw.cmd" ]; then
        cp "${root}/flixw.cmd" "${target}/"
    fi
    cp "${root}/.flixw/lock.toml" "${target}/.flixw/"
    cp "${root}/.flixw/flixw.java" "${target}/.flixw/"
}

# Seed dependency caches into consumer overlay
seed_dependency_cache() {
    local root="$1"
    local target="$2"

    if [ -d "${root}/examples/cli-tool/lib" ]; then
        mkdir -p "${target}/lib"
        cp -r "${root}/examples/cli-tool/lib/"* "${target}/lib/" 2>/dev/null || true
    fi
    if [ -d "${root}/lib/github" ]; then
        mkdir -p "${target}/lib"
        cp -r "${root}/lib/github" "${target}/lib/"
    fi
}

# Seed local package artifact into the consumer resolver cache
seed_local_package() {
    local root="$1"
    local target="$2"
    local fpkg="$3"
    local version="$4"

    local cache_pkg_dir="${target}/lib/github/wstein/flix-cubesolve/${version}"
    mkdir -p "${cache_pkg_dir}"
    cp "${fpkg}" "${cache_pkg_dir}/flix-cubesolve-${version}.fpkg"
    cp "${root}/flix.toml" "${cache_pkg_dir}/flix-cubesolve-${version}.toml"
}

# Compute combined input digest for the local CLI cache
compute_inputs_digest() {
    local root="$1"
    (
        cd "${root}"
        find src examples/cli-tool/src -type f | sort | while read -r f; do
            hash_file "${f}"
        done
        hash_file "flix.toml"
        hash_file "examples/cli-tool/flix.toml"
        hash_file ".flixw/lock.toml"
        if [ -d "lib" ]; then
            find lib -type f | sort | while read -r f; do
                hash_file "${f}"
            done
        fi
        if [ -d "examples/cli-tool/lib" ]; then
            find examples/cli-tool/lib -type f | sort | while read -r f; do
                hash_file "${f}"
            done
        fi
    ) | hash_stream
}

# Verify cached JAR integrity against its SHA-256 sidecar
verify_cached_jar() {
    local jar="$1"
    local sidecar="${jar}.sha256"

    if [ ! -f "${jar}" ] || [ ! -f "${sidecar}" ]; then
        return 1
    fi

    local expected_hash
    expected_hash="$(cat "${sidecar}" | tr -d '[:space:]')"
    if [ -z "${expected_hash}" ]; then
        return 1
    fi

    local actual_hash
    actual_hash="$(hash_file "${jar}")"

    if [ "${actual_hash}" != "${expected_hash}" ]; then
        return 1
    fi

    return 0
}

# Atomically cache a built fatjar with sidecar in cache directory
atomic_cache_jar() {
    local src_jar="$1"
    local dest_jar="$2"
    local cache_dir="$3"

    mkdir -p "${cache_dir}"
    local staging_jar
    staging_jar="$(mktemp "${cache_dir}/stage.XXXXXX.jar")"
    local staging_sidecar
    staging_sidecar="$(mktemp "${cache_dir}/stage.XXXXXX.sha256")"

    cp "${src_jar}" "${staging_jar}"
    local digest
    digest="$(hash_file "${staging_jar}")"
    echo "${digest}" > "${staging_sidecar}"

    # Atomic move into final location (jar first, then sidecar)
    mv "${staging_jar}" "${dest_jar}"
    mv "${staging_sidecar}" "${dest_jar}.sha256"
}

# Cross-platform atomic mutex directory locking
acquire_lock() {
    local lock_dir="$1"
    local count=0
    while ! mkdir "${lock_dir}" 2>/dev/null; do
        sleep 0.05
        count=$((count + 1))
        if [ "${count}" -gt 600 ]; then # 30s timeout
            echo "warning: lock timeout on ${lock_dir}, clearing stale lock" >&2
            rm -rf "${lock_dir}"
        fi
    done
}

release_lock() {
    local lock_dir="$1"
    rm -rf "${lock_dir}" 2>/dev/null || true
}

