#!/run/current-system/sw/bin/bash

# Color codes
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
LIGHT_GRAY="\e[37m"
RESET="\e[0m"

# Check if the number of arguments is not 0 or 2
if [[ $# -ne 0 && $# -ne 2 ]]; then
    echo "Usage:"
    echo "  1. prefetch_checksums.sh, to prefetch checksums for the latest Iosevka and nerd-fonts."
    echo "  2. prefetch_checksums.sh iosevka_version nerdfontpatcher_version, to prefetch checksums for the specified versions."
    exit 1
fi

# Metadata line range
metadata_begin_linenumber=18
metadata_end_linenumber=23

# Requested versions
iosevka_version=""
nerdfontpatcher_version=""
if [[ $# -eq 0 ]]; then
  echo -e "${LIGHT_GRAY}Fetching latest versions...${RESET}"
  iosevka_version_tag=$(curl -s https://api.github.com/repos/be5invis/Iosevka/releases/latest | jq -r '.tag_name')
  nerdfontpatcher_version_tag=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r '.tag_name')
  iosevka_version=${iosevka_version_tag:1}
  nerdfontpatcher_version=${nerdfontpatcher_version_tag:1}
fi
if [[ $# -eq 2 ]]; then
  iosevka_version="$1"
  nerdfontpatcher_version="$2"
fi

# Current versions
current_version=$(grep -oE 'version = "[0-9]+\.[0-9]+\.[0-9]+"' < flake.nix | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
current_iosevka_version=$(grep -oE 'iosevkaVersion = "[0-9]+\.[0-9]+\.[0-9]+"' < flake.nix | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
current_nerdfontpatcher_version=$(grep -oE 'fontPatcherVersion = "[0-9]+\.[0-9]+\.[0-9]+"' < flake.nix | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# Compare versions
if [[ "$current_iosevka_version" != "$iosevka_version" ]]; then
  iosevka_needs_update=true
  echo -e "Iosevka: ${RED}$current_iosevka_version${RESET} -> ${GREEN}$iosevka_version${RESET}"
else
  echo "Iosevka: $current_iosevka_version -> $iosevka_version"
fi

if [[ "$current_nerdfontpatcher_version" != "$nerdfontpatcher_version" ]]; then
  nerdfontpatcher_needs_update=true
  echo -e "nerd-fonts: ${RED}$current_nerdfontpatcher_version${RESET} -> ${GREEN}$nerdfontpatcher_version${RESET}"
else
  echo "nerd-fonts: $current_nerdfontpatcher_version -> $nerdfontpatcher_version"
fi

if [[ "$iosevka_needs_update" != true && "$nerdfontpatcher_needs_update" != true ]]; then
  echo -e "${YELLOW}Nothing to update, exiting without any change to flake.nix${RESET}"
  exit 0
fi

# Calculate hashes for direct dependencies
# remove --silent for debugging
echo -e "${LIGHT_GRAY}Calculating hashes...${RESET}"
iosevka_checksum=$(nix-prefetch --option extra-experimental-features flakes fetchzip --url "https://github.com/be5invis/Iosevka/archive/refs/tags/v$iosevka_version.zip" --check-store --silent)
nerdfontpatcher_checksum=$(nix-prefetch --option extra-experimental-features flakes fetchzip --url "https://github.com/ryanoasis/nerd-fonts/releases/download/v$nerdfontpatcher_version/FontPatcher.zip" --no-stripRoot --check-store --silent)

# Calculate hashes for NPM dependencies
echo -e "${LIGHT_GRAY}Calculating dependency (NPM packages) hashes...${RESET}"
filename=$(mktemp)
curl -s -L "https://raw.githubusercontent.com/be5invis/Iosevka/v$iosevka_version/package-lock.json" -o "$filename"
iosevka_npmdeps_checksum=$(prefetch-npm-deps "$filename")
rm "$filename"

# Asking for a new version
printf "Name the new version (currently at $current_version):\n"
read new_version

# Updated metadata
updated_metadata=$(cat << EOF
      version = "$new_version";
      iosevkaVersion = "$iosevka_version";
      hash = "$iosevka_checksum";
      npmDepsHash = "$iosevka_npmdeps_checksum";
      fontPatcherVersion = "$nerdfontpatcher_version";
      fontPatcherHash = "$nerdfontpatcher_checksum";
EOF
)

# Original metadata
original_metadata=$(sed -n "${metadata_begin_linenumber},${metadata_end_linenumber}p" flake.nix)

# Show sources diff with difftastic
echo -e "${LIGHT_GRAY}Changes to flake.nix${RESET}"
difft <(echo "$original_metadata") <(echo "$updated_metadata")

# Asking for confirmation
printf "Apply the changes above to flake.nix? [y/N]"
read confirmation
if [[ "$confirmation" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  # Update flake.nix
  new_flake_file=$(mktemp)
  awk -v start=$metadata_begin_linenumber -v end=$metadata_end_linenumber -v newlines="$updated_metadata" '
  NR == start {
      print newlines
      next
  }
  NR > start && NR <= end {
      next
  }
  {
      print
  }' flake.nix > "$new_flake_file" && mv "$new_flake_file" flake.nix
  echo -e "${GREEN}Updated flake.nix${RESET}"
else
  echo -e "${YELLOW}Aborted without any change to flake.nix${RESET}"
fi
