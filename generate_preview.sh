#!/bin/sh

echo "Generating preview images from source files..."
echo

# Get current timestamp
timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Extract font version from local file
font_file=$(find artifacts -maxdepth 1 -type f -name 'Iosevkata-v*.tar.zst' | head -n 1)
if [ -z "$font_file" ]; then
  echo "❌ Font file not found in artifacts/, exiting."
  exit 1
fi

# Extract semver from filename
font_version=$(echo "$font_file" | sed -n 's|.*Iosevkata-v\([0-9.]*\)\.tar\.zst|\1|p')

# Common comment prefix
comment_prefix="//"

# Build comment line
comment="$comment_prefix Preview generated at $timestamp with Iosevkata Nerd Font v$font_version"

for file in ./preview/sources/*; do
  filename=$(basename "$file")
  name="${filename%.*}"
  ext="${filename##*.}"
  output="./preview/images/${name}.png"

  echo "🔹 Processing: $filename"
  echo "   ⮕ Output:   ${output}"
  echo "   ⮕ Appending comment line \"$comment\""

  # Create temporary directory and file with correct extension
  tmpdir=$(mktemp -d)
  tmpfile="$tmpdir/temp.$ext"

  {
    echo "$comment"
    cat "$file"
  } > "$tmpfile"

  silicon "$tmpfile" \
    --output "$output" \
    --theme "./preview/themes/Catppuccin Frappe.tmTheme" \
    --pad-horiz 0 \
    --pad-vert 0 \
    --background '#fff0' \
    --font "Iosevkata Nerd Font=48" \
    --no-window-controls \
    --no-round-corner

  if [ $? -eq 0 ]; then
    echo "   ✅ Success"
  else
    echo "   ❌ Failed to generate image for $filename"
  fi

  echo
done

echo "Done!"
