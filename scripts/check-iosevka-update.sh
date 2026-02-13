#!/usr/bin/env bash
# Checks if a newer Iosevka release is available compared to flake.nix.
# Outputs the latest version (without "v" prefix) if an update is available.
# Outputs nothing and exits 0 if already up-to-date.
# Set GITHUB_TOKEN env var to avoid API rate limits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_NIX="${SCRIPT_DIR}/../flake.nix"

# Fetch latest Iosevka release version from GitHub API
auth_header=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

latest_version=$(
  curl -sf "${auth_header[@]}" \
    "https://api.github.com/repos/be5invis/Iosevka/releases/latest" \
  | grep -o '"tag_name":\s*"[^"]*"' \
  | head -1 \
  | sed 's/"tag_name":\s*"v\?\([^"]*\)"/\1/'
)

if [[ -z "$latest_version" ]]; then
  echo "Error: failed to fetch latest Iosevka version from GitHub API" >&2
  exit 1
fi

# Extract current Iosevka version from flake.nix (inside the iosevka = { ... } block)
current_version=$(
  sed -n '/iosevka = {/,/};/p' "$FLAKE_NIX" \
  | grep -oP 'version\s*=\s*"\K[^"]+' \
  | head -1
)

if [[ -z "$current_version" ]]; then
  echo "Error: failed to extract current Iosevka version from $FLAKE_NIX" >&2
  exit 1
fi

if [[ "$current_version" != "$latest_version" ]]; then
  echo "$latest_version"
fi
