# Iosevkata

A `PragmataPro` styled `Iosevka` variant with my tweaks.

1. **A fixed spacing, no ligature.** I once liked ligature, but it's distracting.
2. **A higher underscore.** To make underscore-connected characters feels connected, like `Menlo`.
3. **A lower hex asterisk.** To place it at the center of the line, like `Menlo`.
4. **An oval-dotted zero.** `PragmataPro`'s diamond shaped zero is too sharp for me.
5. **A few decorations mimicking `mononoki`.** For 'B', 'D', 'P' and 'R'.

# TODOs

- [ ] Add a `Iosevkata NF` with [Nerd Fonts Patcher](https://github.com/ryanoasis/nerd-fonts#font-patcher).

# Build Instructions

You will need [Nix or NixOS](https://nixos.org/).

```nix
# with flake
nix build .#iosevkata

# or without
nix-build default.nix
```

# References
1. [Iosevka](https://github.com/be5invis/Iosevka)
2. [PragmataPro](https://fsd.it/shop/fonts/pragmatapro/)
3. [Menlo](https://en.wikipedia.org/wiki/Menlo_(typeface))
4. [mononoki](https://github.com/madmalik/mononoki)

# Other Similar Variants

1. [Pragmasevka](https://github.com/shytikov/pragmasevka), a `Iosevka` variant solely intended to immitate `PragmataPro`.
2. [Iosvmata](https://github.com/N-R-K/Iosvmata), a `Pragmasevka` based `Iosevka` variant.
