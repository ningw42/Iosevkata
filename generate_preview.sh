#!/run/current-system/sw/bin/bash

# silicon cannot use external font yet, so we have to install the fonts before generating a preview.
silicon ./previews/rust.rs --output ./previews/rust.png --language rust --theme ~/.config/bat/themes/catppuccin-frappe.tmTheme --pad-horiz 0 --pad-vert 0 --background '#fff0' --font "Iosevkata=48" --no-window-controls --no-round-corner
