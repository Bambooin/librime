#!/bin/bash
set -ex

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"
if [[ -z "${RIME_ROOT:-}" ]]; then
    RIME_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "${RIME_ROOT}" ]]; then
        if [[ -f "${PWD}/boost_data.txt" ]]; then
            RIME_ROOT="${PWD}"
        else
            RIME_ROOT="${SCRIPT_DIR}"
        fi
    fi
fi
BOOST_VERSION_FILE="${RIME_ROOT}/boost_data.txt"

[[ -f "${BOOST_VERSION_FILE}" ]] || {
    echo "could not find ${BOOST_VERSION_FILE}" >&2
    exit 1
}

boost_version="${boost_version:-$(awk -F= '$1=="version"{sub(/\r$/,"",$2); print $2; exit}' "${BOOST_VERSION_FILE}")}"
boost_sha256sum="${boost_sha256sum:-$(awk -F= '$1=="sha256sum"{sub(/\r$/,"",$2); print $2; exit}' "${BOOST_VERSION_FILE}")}"

if [[ -z "${boost_version}" ]]; then
    echo "missing boost version in ${BOOST_VERSION_FILE}" >&2
    exit 1
fi

if [[ -z "${boost_sha256sum}" ]]; then
    echo "missing SHA256 checksum in ${BOOST_VERSION_FILE}" >&2
    echo "set boost_sha256sum in environment to override" >&2
    exit 1
fi

BOOST_ROOT="${BOOST_ROOT=${RIME_ROOT}/deps/boost-${boost_version}}"
export boost_version BOOST_ROOT

boost_tarball="boost_${boost_version//./_}.tar.gz"
download_url="https://archives.boost.io/release/${boost_version}/source/${boost_tarball}"
boost_tarball_sha256sum="${boost_sha256sum}  ${boost_tarball}"

download_boost_source() {
    cd "${RIME_ROOT}/deps"
    if ! [[ -f "${boost_tarball}" ]]; then
        curl -LO "${download_url}"
    fi
    echo "${boost_tarball_sha256sum}" | shasum -a 256 -c
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
