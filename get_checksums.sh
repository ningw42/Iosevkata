#!/run/current-system/sw/bin/bash

# Versions
iosevka_version="$1"
nerdfontpatcher_version="$2"

# Direct checksums
iosevka_checksum=$(nix-prefetch --option extra-experimental-features flakes fetchFromGitHub --owner be5invis --repo iosevka --rev "v$iosevka_version" --check-store)
nerdfontpatcher_checksum=$(nix-prefetch --option extra-experimental-features flakes fetchzip --url "https://github.com/ryanoasis/nerd-fonts/releases/download/v$nerdfontpatcher_version/FontPatcher.zip" --no-stripRoot --check-store)

# NPM dependencies checksum
filename=$(mktemp)
curl -s -L "https://raw.githubusercontent.com/be5invis/Iosevka/v$iosevka_version/package-lock.json" -o "$filename"
iosevka_npmdeps_checksum=$(prefetch-npm-deps "$filename")

# Output
formatted_output=$(cat << EOF
    version = "$iosevka_version";
    hash = "$iosevka_checksum";
    npmDepsHash = "$iosevka_npmdeps_checksum";
    fontPatcherVersion = "$nerdfontpatcher_version";
    fontPatcherHash = "$nerdfontpatcher_checksum";
EOF
)

echo "$formatted_output"
