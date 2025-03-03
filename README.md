# Iosevkata

![Preview](preview.png)

A `PragmataPro` styled `Iosevka` variant with my tweaks.

1. **A fixed spacing, no ligature.** I once liked ligature, but it's distracting.
2. **A higher underscore.** To make underscore-connected characters feels connected, like `Menlo`.
3. **A lower hex asterisk.** To place asterisk at the vertical center of the line, like `Menlo`.
4. **An oval-dotted zero.** `PragmataPro`'s diamond shaped zero is too sharp for me.
5. **A few decorations mimicking `mononoki`.** For 'B', 'D', 'P' and 'R'.

# Variants

1. Iosevkata, vanilla Iosevka with the tweaks above.
2. Iosevkata Nerd Font, [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) glyphs are patched in the same way as the official "Nerd Font" variant, "a somehow monospaced variant, maybe". See [ryanoasis/nerd-fonts#1103](https://github.com/ryanoasis/nerd-fonts/discussions/1103).
3. Iosevkata Nerd Font Mono, [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) glyphs are patched in the same way as the official "Nerd Font Mono" variant, "a strictly monospaced variant". See [ryanoasis/nerd-fonts#1103](https://github.com/ryanoasis/nerd-fonts/discussions/1103).

# TODOs

- [x] Add a `Iosevkata Nerd Font` with [Nerd Fonts Patcher](https://github.com/ryanoasis/nerd-fonts#font-patcher).
- [x] A unified builder.
- [x] Run NerdFontPatcher in parallel. Now we just need 3 minutes on an AMD Ryzen 9 3900X compare to 15 minutes when patching is done sequentially.
- [x] Honor `NIX_BUILD_CORES`.
- [x] Add preview image.
- [x] Prefetch script.
- [x] Larger period size in punctuation.
- [x] Build and release with GitHub Actions.
- [x] Switch to [calendar versioning](https://calver.org/) to decouple from Iosevka's semantic versioning.
- [ ] Add `zstd` compressed artifacts.
- [ ] Generate preview automatically in GitHub Actions with colorscheme applied.
- [ ] Put the glyphs from Nerd Fonts at the horizontal center of the cell/grid. See [ryanoasis/nerd-fonts#1644](https://github.com/ryanoasis/nerd-fonts/discussions/1644#discussioncomment-9600894).

# Build

You will need [Nix or NixOS](https://nixos.org/), and [Flake](https://nixos.wiki/wiki/Flakes).

```bash
# Iosevkata
nix build .#iosevkata

# Iosevkata Nerd Font
nix build .#iosevkata-nerd-font

# Iosevkata Nerd Font Mono
nix build .#iosevkata-nerd-font-mono

# All variants at once for zip artifacts
nix build .#iosevkata-all-release

# All variants at once for nix package
nix build .#iosevkata-all
```

# Update
```bash
# enter nix shell with necessary dependencies
nix develop .

# prefetch checksums with the latest Iosevka and nerd-fonts
./prefetch_checksums.sh
# prefetch checksums with the specified Iosevka and nerd-fonts
./prefetch_checksums.sh $iosevka_version $nerdfontpatcher_version # e.g. ./prefetch_checksums.sh 30.3.0 3.2.1

# review the updated flake.nix
```

# References
1. [Iosevka](https://github.com/be5invis/Iosevka)
2. [PragmataPro](https://fsd.it/shop/fonts/pragmatapro/)
3. [Menlo](https://en.wikipedia.org/wiki/Menlo_(typeface))
4. [mononoki](https://github.com/madmalik/mononoki)

# Other Similar Variants

1. [Pragmasevka](https://github.com/shytikov/pragmasevka), a `Iosevka` variant solely intended to immitate `PragmataPro`.
2. [Iosvmata](https://github.com/N-R-K/Iosvmata), a `Pragmasevka` based `Iosevka` variant.
