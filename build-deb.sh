#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -n "${UBLKDRV_VERSION:-}" ]]; then
    PKG_VERSION="$UBLKDRV_VERSION"
else
    PKG_VERSION=$(tr -d '[:space:]' < "$SCRIPT_DIR/version.txt")
fi

[[ -z "$PKG_VERSION" ]] && { echo "Error: could not determine package version" >&2; exit 1; }

echo "Building ublk-drv-dkms version $PKG_VERSION"

# Generate debian/changelog from template
sed \
    -e "s/@@VERSION@@/$PKG_VERSION/g" \
    -e "s/@@DATE@@/$(date -R)/g" \
    "$SCRIPT_DIR/changelog.in" > "$SCRIPT_DIR/debian/changelog"

cd "$SCRIPT_DIR"
dpkg-buildpackage -us -uc -b

echo "Package built; .deb is in $(dirname "$SCRIPT_DIR")/"
