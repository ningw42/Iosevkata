#!/usr/bin/env bash
# Checks if a newer nerd-font-patcher release is available compared to flake.nix.
# Outputs the latest version (without "v" prefix) if an update is available.
# Outputs nothing and exits 0 if already up-to-date.
# Set GITHUB_TOKEN env var to avoid API rate limits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_NIX="${SCRIPT_DIR}/../flake.nix"

# Fetch latest nerd-font-patcher release version from GitHub API
auth_header=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

latest_version=$(
  curl -sf "${auth_header[@]}" \
    "https://api.github.com/repos/ningw42/nerd-font-patcher/releases/latest" \
  | grep -o '"tag_name":\s*"[^"]*"' \
  | head -1 \
  | sed 's/"tag_name":\s*"v\?\([^"]*\)"/\1/'
)

if [[ -z "$latest_version" ]]; then
  echo "Error: failed to fetch latest nerd-font-patcher version from GitHub API" >&2
  exit 1
fi
echo "Latest nerd-font-patcher version: $latest_version" >&2

# Extract current nerd-font-patcher version from flake.nix input URL
current_version=$(
  grep -oP 'nerd-font-patcher\.url\s*=\s*"github:ningw42/nerd-font-patcher/v\K[^"]+' "$FLAKE_NIX"
)

if [[ -z "$current_version" ]]; then
  echo "Error: failed to extract current nerd-font-patcher version from $FLAKE_NIX" >&2
  exit 1
fi
echo "Current nerd-font-patcher version: $current_version" >&2

if [[ "$current_version" != "$latest_version" ]]; then
  echo "Update available: $current_version -> $latest_version" >&2
  echo "$latest_version"
else
  echo "Up-to-date." >&2
fi
