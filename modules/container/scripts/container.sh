#!/bin/bash
# Container Management Script - Enhanced
# Uses host network for builds (speed), bridge network for runtime (security)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORK_DIR="${WORK_DIR:-$PWD}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <command> <profile> [options]

Commands:
    build <profile>    Build container (uses host network for speed)
    run <profile>      Run container (uses bridge network for security)
    list               List all built images
    clean              Remove old/dangling images

Profiles:
    toolbox    Base container with core utilities
    web        Web reconnaissance and OSINT
    re         Reverse engineering and exploit development
    ad         Active Directory assessment

Examples:
    $(basename "$0") build web
    $(basename "$0") run web
    $(basename "$0") list
EOF
    exit 1
}

check_engagement_dir() {
    [[ "$PWD" =~ /engage/[^/]+$ ]] || [[ -d "c2" ]] || [[ -d "recon" ]] || [[ -d "exploit" ]]
}

warn_not_in_engagement() {
    echo -e "${YELLOW}⚠️  Warning: Not in an engagement directory${NC}"
    echo -e "${BLUE}Current:${NC} $PWD"
    echo -e "${YELLOW}Will mount:${NC} $PWD → /work"
    echo ""
    echo -e "${BLUE}Recommended:${NC}"
    echo "  1. cd ~/engage/<engagement-name>"
    echo "  2. chmod 777 ."
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 0
}

build() {
    local PROFILE="$1"
    local IMAGE="localhost/offsec-${PROFILE}:0.1.0"
    local DATE_TAG
    DATE_TAG="localhost/offsec-${PROFILE}:$(date +%Y%m%d)"
    local CONTAINERFILE="$REPO_ROOT/modules/container/${PROFILE}/Containerfile"

    [[ -f "$CONTAINERFILE" ]] || {
        echo -e "${RED}[ERROR]${NC} Containerfile not found: $CONTAINERFILE"
        exit 1
    }

    echo -e "${BLUE}[*]${NC} Building ${PROFILE} (${IMAGE})..."
    echo -e "${BLUE}[*]${NC} Using host network for speed..."

    if podman build \
        --network=host \
        -f "$CONTAINERFILE" \
        -t "$IMAGE" \
        -t "$DATE_TAG" \
        "$REPO_ROOT"; then
        echo -e "${GREEN}[✓]${NC} Built: ${IMAGE}"
        echo -e "${GREEN}[✓]${NC} Tagged: ${DATE_TAG}"
    else
        echo -e "${RED}[ERROR]${NC} Build failed"
        exit 1
    fi
}

run() {
    local PROFILE="$1"
    local IMAGE="localhost/offsec-${PROFILE}:0.1.0"

    podman image exists "$IMAGE" || {
        echo -e "${RED}[ERROR]${NC} Image not found: $IMAGE"
        echo "Build it: $0 build $PROFILE"
        exit 1
    }

    check_engagement_dir || warn_not_in_engagement

    echo -e "${BLUE}[*]${NC} Running ${PROFILE}..."
    echo -e "${BLUE}[*]${NC} Mount: $WORK_DIR → /work"
    echo -e "${BLUE}[*]${NC} Network: bridge (isolated)"

    podman run -it --rm \
        -v "$WORK_DIR:/work:z" \
        -w /work \
        --cap-add=NET_RAW \
        --cap-add=NET_ADMIN \
        --hostname "offsec-${PROFILE}" \
        "$IMAGE" \
        bash -l
}

list() {
    echo -e "${BLUE}[*]${NC} Container images:"
    podman images | grep -E "offsec-(toolbox|web|re|ad)" | sort
}

clean() {
    echo -e "${YELLOW}[*]${NC} Cleaning..."
    podman image prune -f
    echo -e "${GREEN}[✓]${NC} Done"
}

# Main
case "${1:-}" in
    build) build "${2:-}" ;;
    run) run "${2:-}" ;;
    list) list ;;
    clean) clean ;;
    *) usage ;;
esac
