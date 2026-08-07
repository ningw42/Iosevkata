#!/usr/bin/env bash
# Extracts the dependency versions (without "v") pinned in flake.nix.
# Emits `key=value` lines on stdout, ready to append to "$GITHUB_OUTPUT":
#   iosevka=34.8.0
#   nerdfonts=3.4.0
# Diagnostics -> stderr. Exits non-zero on failure.
# Run from anywhere: ./scripts/get-dependency-versions.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_NIX="${SCRIPT_DIR}/../flake.nix"

# Iosevka version lives inside the `iosevka = { ... };` block.
iosevka_version=$(
  sed -n '/iosevka = {/,/};/p' "$FLAKE_NIX" \
  | grep -oP 'version\s*=\s*"\K[^"]+' \
  | head -1
)

if [[ -z "$iosevka_version" ]]; then
  echo "Error: failed to extract Iosevka version from $FLAKE_NIX" >&2
  exit 1
fi

# nerd-fonts version is the tag of the nerd-font-patcher flake input.
nerdfonts_version=$(
  grep -oP 'nerd-font-patcher\.url\s*=\s*"github:ningw42/nerd-font-patcher/v\K[^"]+' "$FLAKE_NIX"
)

if [[ -z "$nerdfonts_version" ]]; then
  echo "Error: failed to extract nerd-fonts version from $FLAKE_NIX" >&2
  exit 1
fi

echo "Iosevka version: $iosevka_version" >&2
echo "nerd-fonts version: $nerdfonts_version" >&2

echo "iosevka=$iosevka_version"
echo "nerdfonts=$nerdfonts_version"
