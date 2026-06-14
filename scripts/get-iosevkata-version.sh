#!/usr/bin/env bash
# Extracts the top-level Iosevkata calver (YY.0M.Micro, without "v") from flake.nix.
# This is the release version to tag. Value -> stdout, diagnostics -> stderr.
# Exits non-zero on failure. Run from anywhere: ./scripts/get-iosevkata-version.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_NIX="${SCRIPT_DIR}/../flake.nix"

# The first `version = "..."` in flake.nix is the top-level Iosevkata calver,
# which always precedes the `iosevka = { ... }` block. `awk ... exit` stops
# before that block so the dependency version (e.g. 34.6.3) is never matched.
version=$(awk -F'"' '/^[[:space:]]*version[[:space:]]*=/ { print $2; exit }' "$FLAKE_NIX")

if [[ ! "$version" =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]]; then
  echo "Error: failed to extract a valid Iosevkata version from $FLAKE_NIX (got: '$version')" >&2
  exit 1
fi

echo "Iosevkata version: $version" >&2
echo "$version"
