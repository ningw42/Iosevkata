#!/bin/sh

# silicon cannot use external font yet, so we have to install the fonts before generating a preview.
silicon ./preview/sources/rust.rs --output ./preview/images/rust.png --language rust --theme ./preview/themes/Catppuccin\ Frappe.tmTheme --pad-horiz 0 --pad-vert 0 --background '#fff0' --font "Iosevkata=48" --no-window-controls --no-round-corner
