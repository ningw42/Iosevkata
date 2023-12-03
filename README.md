# Iosevkata 

A `PragmataPro` styled `Iosevka` variant with my own tweaks.

1. **A fixed spacing, no ligature.** I once liked ligature, but it's distracting.
2. **A higher underscore.** To make underscore-connected characters feels connected, like `Menlo`.
3. **A lower hex asterisk.** To place it at the center of the line, like `Menlo`.
4. **An oval-dottet zero.** `PragmataPro`'s diamond shaped zero is too sharp for me.
5. **A few decorations mimicking `mononoki`.** For 'B', 'D', 'P' and 'R'.

# Build

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
5. [Iosvmata](https://github.com/N-R-K/Iosvmata), a `Iosevka` variant **without** my personal preferences.
6. [Pragmasevka](https://github.com/shytikov/pragmasevka), a `Iosevka` variant **with** the author's personal preferences.
