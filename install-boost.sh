#!/bin/bash
set -ex

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"
if [[ -z "${RIME_ROOT:-}" ]]; then
    RIME_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "${RIME_ROOT}" ]]; then
        if [[ -f "${PWD}/boost-version" ]]; then
            RIME_ROOT="${PWD}"
        else
            RIME_ROOT="${SCRIPT_DIR}"
        fi
    fi
fi
BOOST_VERSION_FILE="${RIME_ROOT}/boost-version"

[[ -f "${BOOST_VERSION_FILE}" ]] || {
    echo "could not find ${BOOST_VERSION_FILE}" >&2
    exit 1
}

boost_version_from_file="$(sed -n 's/^boost_version=//p' "${BOOST_VERSION_FILE}")"
boost_version_from_file="${boost_version_from_file%$'\r'}"
boost_sha256_from_file="$(sed -n 's/^boost_sha256=//p' "${BOOST_VERSION_FILE}")"
boost_sha256_from_file="${boost_sha256_from_file%$'\r'}"

[[ -n "${boost_version_from_file}" ]] || {
    echo "could not read boost_version from ${BOOST_VERSION_FILE}" >&2
    exit 1
}
[[ -n "${boost_sha256_from_file}" ]] || {
    echo "could not read boost_sha256 from ${BOOST_VERSION_FILE}" >&2
    exit 1
}

boost_version="${boost_version:-${boost_version_from_file}}"
boost_tarball_sha256="${boost_sha256:-${boost_sha256_from_file}}"

BOOST_ROOT="${BOOST_ROOT=${RIME_ROOT}/deps/boost-${boost_version}}"
export boost_version BOOST_ROOT

boost_tarball="boost_${boost_version//./_}.tar.gz"
download_url="https://archives.boost.io/release/${boost_version}/source/${boost_tarball}"

download_boost_source() {
    if [[ "${boost_version}" != "${boost_version_from_file}" && -z "${boost_sha256:-}" ]]; then
        echo "boost_sha256 must be set when boost_version differs from ${BOOST_VERSION_FILE}" >&2
        exit 1
    fi
    cd "${RIME_ROOT}/deps"
    if ! [[ -f "${boost_tarball}" ]]; then
        curl -LO "${download_url}"
    fi
    printf '%s  %s\n' "${boost_tarball_sha256}" "${boost_tarball}" | shasum -a 256 -c
    tar -xzf "${boost_tarball}"
    mv "boost_${boost_version//./_}" "boost-${boost_version}"
    [[ -f "${BOOST_ROOT}/bootstrap.sh" ]]
}

boost_cxxflags='-arch arm64 -arch x86_64'

build_boost_macos() {
    cd "${BOOST_ROOT}"
    ./bootstrap.sh --with-toolset=clang --with-libraries="${boost_libs}"
    ./b2 -q -a link=static architecture=arm cxxflags="${boost_cxxflags}" stage
    for lib in stage/lib/*.a; do
        lipo $lib -info
    done
}

build_boost_linux() {
    local boost_toolset=
    if [[ "${CXX:-}" =~ clang ]]; then
        boost_toolset=clang
    elif [[ "${CXX:-}" =~ g\+\+|gcc ]]; then
        boost_toolset=gcc
    fi
    cd "${BOOST_ROOT}"
    if [[ -n "${boost_toolset}" ]]; then
        ./bootstrap.sh --with-toolset="${boost_toolset}" --with-libraries="${boost_libs}"
    else
        ./bootstrap.sh --with-libraries="${boost_libs}"
    fi
    ./b2 -q -a link=shared stage
}

if [[ $# -eq 0 || " $* " =~ ' --download ' ]]; then
    if [[ ! -f "${BOOST_ROOT}/bootstrap.sh" ]]; then
        download_boost_source
    else
        echo "found boost at ${BOOST_ROOT}"
    fi
    cd "${BOOST_ROOT}"
    ./bootstrap.sh
    ./b2 headers
fi
if [[ ($# -eq 0 || " $* " =~ ' --build ') && -n "${boost_libs}" ]]; then
    if [[ "$OSTYPE" =~ 'darwin' ]]; then
        build_boost_macos
    elif [[ "$OSTYPE" =~ 'linux' ]]; then
        build_boost_linux
    fi
fi
