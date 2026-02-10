#!/bin/bash
set -e

# ============================================================
# build.sh - Build and install mod_audio_fork for FreeSWITCH
# ============================================================

# Resolve script directory once (before any cd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration (override via environment variables if needed)
FREESWITCH_INCLUDE_DIR="${FREESWITCH_INCLUDE_DIR:-/usr/local/freeswitch/include/freeswitch}"
FREESWITCH_LIBRARY="${FREESWITCH_LIBRARY:-/usr/local/freeswitch/lib/libfreeswitch.so}"
FREESWITCH_MOD_DIR="${FREESWITCH_MOD_DIR:-/usr/local/freeswitch/mod}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
INSTALL="${INSTALL:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---- Install dependencies ----
install_dependencies() {
    log_info "Installing build dependencies..."
    apt-get update -qq
    apt-get install -y -qq cmake libwebsockets-dev libboost-all-dev git build-essential 2>&1 | tail -5
    log_info "Dependencies installed."
}

# ---- Build ----
build() {
    log_info "Building mod_audio_fork (${BUILD_TYPE})..."
    log_info "  FreeSWITCH include: ${FREESWITCH_INCLUDE_DIR}"
    log_info "  FreeSWITCH library: ${FREESWITCH_LIBRARY}"

    # Verify FreeSWITCH paths exist
    if [ ! -d "${FREESWITCH_INCLUDE_DIR}" ]; then
        log_error "FreeSWITCH include directory not found: ${FREESWITCH_INCLUDE_DIR}"
        exit 1
    fi
    if [ ! -f "${FREESWITCH_LIBRARY}" ]; then
        log_error "FreeSWITCH library not found: ${FREESWITCH_LIBRARY}"
        exit 1
    fi

    # Create build directory
    mkdir -p "${SCRIPT_DIR}/build"
    cd "${SCRIPT_DIR}/build"

    # Configure
    cmake .. \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DFREESWITCH_INCLUDE_DIR="${FREESWITCH_INCLUDE_DIR}" \
        -DFREESWITCH_LIBRARY="${FREESWITCH_LIBRARY}"

    # Build
    make -j"$(nproc)"

    log_info "Build complete: ${SCRIPT_DIR}/build/mod_audio_fork.so"
}

# ---- Install ----
install_module() {
    local so_file="${SCRIPT_DIR}/build/mod_audio_fork.so"

    # Try multiple locations in case of path resolution issues
    if [ ! -f "${so_file}" ]; then
        # Try relative to current directory
        if [ -f "./build/mod_audio_fork.so" ]; then
            so_file="./build/mod_audio_fork.so"
        elif [ -f "./mod_audio_fork.so" ]; then
            so_file="./mod_audio_fork.so"
        else
            # Search for it
            local found
            found="$(find "${SCRIPT_DIR}" -name 'mod_audio_fork.so' -type f 2>/dev/null | head -1)"
            if [ -n "${found}" ]; then
                so_file="${found}"
            else
                log_error "mod_audio_fork.so not found. Run build first."
                log_error "  Searched: ${SCRIPT_DIR}/build/mod_audio_fork.so"
                log_error "  SCRIPT_DIR=${SCRIPT_DIR}"
                log_error "  PWD=$(pwd)"
                ls -la "${SCRIPT_DIR}/build/" 2>/dev/null || true
                exit 1
            fi
        fi
    fi

    log_info "Installing ${so_file} to ${FREESWITCH_MOD_DIR}..."
    cp "${so_file}" "${FREESWITCH_MOD_DIR}/"
    chown freeswitch:freeswitch "${FREESWITCH_MOD_DIR}/mod_audio_fork.so"
    log_info "Module installed successfully."
}

# ---- Main ----
usage() {
    echo "Usage: $0 [deps|build|install|all]"
    echo ""
    echo "Commands:"
    echo "  deps      Install build dependencies (requires root)"
    echo "  build     Configure and build mod_audio_fork"
    echo "  install   Copy mod_audio_fork.so to FreeSWITCH modules dir (requires root)"
    echo "  all       Run deps + build + install (default)"
    echo ""
    echo "Environment variables:"
    echo "  FREESWITCH_INCLUDE_DIR  (default: /usr/local/freeswitch/include/freeswitch)"
    echo "  FREESWITCH_LIBRARY      (default: /usr/local/freeswitch/lib/libfreeswitch.so)"
    echo "  FREESWITCH_MOD_DIR      (default: /usr/local/freeswitch/mod)"
    echo "  BUILD_TYPE              (default: Release)"
}

CMD="${1:-all}"

case "${CMD}" in
    deps)
        install_dependencies
        ;;
    build)
        build
        ;;
    install)
        install_module
        ;;
    all)
        install_dependencies
        build
        install_module
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        log_error "Unknown command: ${CMD}"
        usage
        exit 1
        ;;
esac
