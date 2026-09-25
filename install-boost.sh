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

boost_version_from_file=
boost_sha256_from_file=
while IFS='=' read -r key value; do
    value="${value%$'\r'}"
    case "${key}" in
        boost_version)
            boost_version_from_file="${value}"
            ;;
        boost_sha256)
            boost_sha256_from_file="${value}"
            ;;
    esac
done < "${BOOST_VERSION_FILE}"

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
    local extracted_boost_dir="boost_${boost_version//./_}"
    local managed_boost_root="${RIME_ROOT}/deps/boost-${boost_version}"
    local boost_root_parent=
    if [[ "${boost_version}" != "${boost_version_from_file}" && -z "${boost_sha256:-}" ]]; then
        echo "boost_sha256 must be set when boost_version differs from ${BOOST_VERSION_FILE}" >&2
        exit 1
    fi
    if [[ "${BOOST_ROOT}" != "${managed_boost_root}" && -e "${BOOST_ROOT}" ]]; then
        echo "could not repair existing external BOOST_ROOT at ${BOOST_ROOT}" >&2
        exit 1
    fi
    cd "${RIME_ROOT}/deps"
    if ! [[ -f "${boost_tarball}" ]]; then
        curl -LO "${download_url}"
    fi
    printf '%s  %s\n' "${boost_tarball_sha256}" "${boost_tarball}" | shasum -a 256 -c
    rm -rf "${extracted_boost_dir}"
    tar -xzf "${boost_tarball}"
    if ! [[ -d "${extracted_boost_dir}" ]]; then
        echo "could not extract ${extracted_boost_dir} from ${boost_tarball}" >&2
        exit 1
    fi
    if [[ "${BOOST_ROOT}" == "${managed_boost_root}" ]]; then
        rm -rf "${BOOST_ROOT}"
        mv "${extracted_boost_dir}" "boost-${boost_version}"
    else
        boost_root_parent="$(dirname "${BOOST_ROOT}")"
        mkdir -p "${boost_root_parent}"
        mv "${extracted_boost_dir}" "${BOOST_ROOT}"
    fi
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
        if [[ -d "${RIME_ROOT}/deps/boost_${boost_version//./_}" ]] && \
            [[ "$(cd "${RIME_ROOT}/deps/boost_${boost_version//./_}" && pwd -P)" != "$(cd "${BOOST_ROOT}" && pwd -P)" ]]; then
            rm -rf "${RIME_ROOT}/deps/boost_${boost_version//./_}"
        fi
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
