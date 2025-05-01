#!/bin/sh

echo "Generating preview images from source files..."
echo

for file in ./preview/sources/*; do
  filename=$(basename "$file")
  name="${filename%.*}"
  output="./preview/images/${name}.png"

  echo "🔹 Processing: $filename"
  echo "   ⮕ Output:   ${output}"

  silicon "$file" \
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
