#!/run/current-system/sw/bin/bash

# Check if the number of arguments is not 0 or 2
if [[ $# -ne 0 && $# -ne 2 ]]; then
    echo "Usage:"
    echo "  1. prefetch_checksums.sh, to prefetch checksums for the latest Iosevka and nerd-fonts."
    echo "  2. prefetch_checksums.sh iosevka_version nerdfontpatcher_version, to prefetch checksums for the specified versions."
    exit 1
fi

# Versions
iosevka_version=""
nerdfontpatcher_version=""
if [[ $# -eq 0 ]]; then
  iosevka_version_tag=$(curl -s https://api.github.com/repos/be5invis/Iosevka/releases/latest | jq -r '.tag_name')
  nerdfontpatcher_version_tag=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r '.tag_name')
  iosevka_version=${iosevka_version_tag:1}
  nerdfontpatcher_version=${nerdfontpatcher_version_tag:1}
fi
if [[ $# -eq 2 ]]; then
  iosevka_version="$1"
  nerdfontpatcher_version="$2"
fi

echo "Iosevka: $iosevka_version"
echo "nerd-fonts: $nerdfontpatcher_version"

# Direct checksums
# iosevka_checksum=$(nix-prefetch --option extra-experimental-features flakes fetchFromGitHub --owner be5invis --repo iosevka --rev "v$iosevka_version" --check-store)
iosevka_checksum=$(nix-prefetch --option extra-experimental-features flakes fetchzip --url "https://github.com/be5invis/Iosevka/archive/refs/tags/v$iosevka_version.zip" --check-store)
nerdfontpatcher_checksum=$(nix-prefetch --option extra-experimental-features flakes fetchzip --url "https://github.com/ryanoasis/nerd-fonts/releases/download/v$nerdfontpatcher_version/FontPatcher.zip" --no-stripRoot --check-store)

# NPM dependencies checksum
filename=$(mktemp)
curl -s -L "https://raw.githubusercontent.com/be5invis/Iosevka/v$iosevka_version/package-lock.json" -o "$filename"
iosevka_npmdeps_checksum=$(prefetch-npm-deps "$filename")
rm "$filename"

# Output
formatted_output=$(cat << EOF
    version = "$iosevka_version";
    hash = "$iosevka_checksum";
    npmDepsHash = "$iosevka_npmdeps_checksum";
    fontPatcherVersion = "$nerdfontpatcher_version";
    fontPatcherHash = "$nerdfontpatcher_checksum";
EOF
)

echo -e "\033[1;33m------ Ignore the output above ------\033[0m"

echo -e "\033[1;33m------ Prefetched hashes ------\033[0m"
echo -e "\033[1;32m$formatted_output\033[0m"
echo -e "\033[1;33m------ Prefetched hashes ------\033[0m"

# Update line numbers when the metadata section is on different lines
metadata_begin_line=12
metadata_end_line=16
new_flake_file=$(mktemp)

echo -e "\033[1;32m------ Updating flake.nix ------\033[0m"

awk -v start=$metadata_begin_line -v end=$metadata_end_line -v newlines="$formatted_output" '
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

echo -e "\033[1;32m------ The text above has been written to flake.nix ------\033[0m"
