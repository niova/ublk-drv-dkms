#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAPPING="$SCRIPT_DIR/mapping.txt"

kernel_release=$(uname -r)

# Look up a candidate version string in mapping.txt (right column maps to
# source subdirectory in left column).  Prints the directory and returns 0,
# or returns 1 if not found.
match_candidate() {
    local candidate="$1"

    local ver_dir
    ver_dir=$(awk -v c="$candidate" '!/^[[:space:]]*#/ && $2 == c {print $1; exit}' "$MAPPING")

    if [[ -n "$ver_dir" && -d "$SCRIPT_DIR/$ver_dir" ]]; then
        echo "$SCRIPT_DIR/$ver_dir"
        return 0
    fi

    return 1
}

# Build a list of progressively less-specific version strings for the running
# kernel and try each in turn until one matches a source directory.
#
# Example for kernel_release "7.0.0-15-generic":
#   1. "7.0.0-15-generic"  — full uname -r string
#   2. "7.0.0"             — strip distro suffix (everything after the first '-')
#   3. "7.0"               — strip sublevel (.z of x.y.z)
#   4. "7"                 — strip patchlevel (.y of x.y)
#
# Prints the matched directory and returns 0, or returns 1 on no match.
find_version_dir_for_kernel() {
    local kernel_release="$1"

    # Try the full uname -r string first (e.g. "7.0.0-15-generic").
    if match_candidate "$kernel_release"; then
        return 0
    fi

    # Strip the distro suffix — everything from the first '-' onward
    # (e.g. "7.0.0-15-generic" -> "7.0.0").
    local base="${kernel_release%%-*}"
    if [[ "$base" != "$kernel_release" ]]; then
        if match_candidate "$base"; then
            return 0
        fi
    fi

    # Strip the sublevel — the third numeric component
    # (e.g. "7.0.0" -> "7.0").
    local xy="${base%.*}"
    if [[ "$xy" != "$base" ]]; then
        if match_candidate "$xy"; then
            return 0
        fi
    fi

    # Strip the patchlevel — the second numeric component
    # (e.g. "7.0" -> "7").
    local x="${xy%.*}"
    if [[ "$x" != "$xy" ]]; then
        if match_candidate "$x"; then
            return 0
        fi
    fi

    return 1
}

VERSION_DIR=""
if VERSION_DIR=$(find_version_dir_for_kernel "$kernel_release"); then
    echo "Matched kernel $kernel_release -> $VERSION_DIR"
else
    echo "Error: no source directory found for kernel $kernel_release" >&2
    echo "Add an entry to $MAPPING or create a src/<version>/ directory manually." >&2
    exit 1
fi

make -C "/lib/modules/$kernel_release/build" M="$VERSION_DIR" modules
mkdir -p "$SCRIPT_DIR/build-output"
cp "$VERSION_DIR/ublk_drv.ko" "$SCRIPT_DIR/build-output/"
