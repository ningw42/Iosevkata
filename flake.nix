{
  description = "Iosevkata, a customized variant of Iosevka";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      # Metadata: version and dependencies
      version = "25.10.1";
      dependencies = {
        iosevka = {
          version = "33.3.3";
          hash = "sha256-/e65hFA8GabDrHjQ+9MthSTxUku9af0LT4W1ENI+LYc=";
          npmDepsHash = "sha256-QJ3h8NdhCG+lkZ5392akKk+pVHiqmnt+DsC3imixNnw=";
        };
        nerdfonts = {
          version = "3.4.0";
          hash = "sha256-koZj0Tn1HtvvSbQGTc3RbXQdUU4qJwgClOVq1RXW6aM=";
        };
      };

      # Build plans
      privateBuildPlan = builtins.readFile ./private-build-plans.toml;

      # This is the system specific (x86_64-linux) nixpkgs that builds Iosevkata as a system agnostic package
      x64LinuxPkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Builder
      buildIosevkata =
        {
          pkgs,
          variants,
          forRelease,
        }:
        pkgs.buildNpmPackage rec {
          inherit version privateBuildPlan;
          npmDepsHash = dependencies.iosevka.npmDepsHash;
          requiresNerdFonts =
            builtins.elem "IosevkataNerdFont" variants || builtins.elem "IosevkataNerdFontMono" variants;

          pname = "iosevkata";

          srcs = [
            (pkgs.fetchFromGitHub {
              hash = dependencies.iosevka.hash;
              name = "Iosevka";
              owner = "be5invis";
              repo = "Iosevka";
              rev = "v${dependencies.iosevka.version}";
            })
          ]
          ++ pkgs.lib.optionals requiresNerdFonts [
            # optional source for nerd-fonts
            (pkgs.fetchzip {
              name = "nerd-fonts";
              url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${dependencies.nerdfonts.version}/FontPatcher.zip";
              hash = dependencies.nerdfonts.hash;
              stripRoot = false; # assume flat structure from the zip file.
            })
          ];

          nativeBuildInputs = [
            pkgs.gnutar
            pkgs.ttfautohint-nox
            pkgs.zip
            pkgs.zstd
          ]
          ++ pkgs.lib.optionals requiresNerdFonts [
            # optional build inputs for nerd-fonts
            pkgs.parallel # for parallel font patching
            pkgs.fontforge
            (pkgs.python3.withPackages (ps: [
              ps.fontforge
              ps.configargparse
            ]))
          ];

          passAsFile = [ "privateBuildPlan" ];

          sourceRoot = "Iosevka";

          # Optional Patch Phase:
          # 1. replace `argparse` with `configargparse` because argparse isn't available in nixpkgs.
          # 2. put patched nerd-fonts glyphs at the horizontal center of two cells.
          prePatch = pkgs.lib.optionalString requiresNerdFonts ''
            cd ../nerd-fonts
            chmod -R +w .
          '';
          patches = pkgs.lib.optionals requiresNerdFonts [
            ./patches/nerd-fonts/v3.4.0/configargparse.patch
            ./patches/nerd-fonts/v3.4.0/horizontal_centered.patch
          ];
          postPatch = pkgs.lib.optionalString requiresNerdFonts ''
            cd ../Iosevka
          '';

          # Configure Phase: simply copy the build plan file.
          configurePhase = ''
            runHook preConfigure

            cp "$privateBuildPlanPath" private-build-plans.toml

            runHook postConfigure
          '';

          # Build Phase: build Iosevkata first, and then patch with NerdFont.
          buildPhase = ''
            export HOME=$TMPDIR

            runHook preBuild

            # build Iosevkata vanilla
            # pipe to cat to disable progress bar
            npm run build --no-update-notifier --targets ttf::Iosevkata -- --jCmd=$NIX_BUILD_CORES --verbose=9 | cat

            # patch nerd font if necessary
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFont" variants) ''
              nerdfontdir="dist/Iosevkata/NerdFont"
              mkdir $nerdfontdir
              parallel -j $NIX_BUILD_CORES python3 ../nerd-fonts/font-patcher --glyphdir ../nerd-fonts/src/glyphs --careful --complete --outputdir $nerdfontdir ::: dist/Iosevkata/TTF/*
            ''}

            # patch nerd font mono if necessary
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFontMono" variants) ''
              nerdfontmonodir="dist/Iosevkata/NerdFontMono"
              mkdir $nerdfontmonodir
              parallel -j $NIX_BUILD_CORES python3 ../nerd-fonts/font-patcher --glyphdir ../nerd-fonts/src/glyphs --careful --mono --complete --outputdir $nerdfontmonodir ::: dist/Iosevkata/TTF/*
            ''}

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            # setup directories
            mkdir -p $out
            fontdir="$out/share/fonts/truetype"
            install -d "$fontdir"

            # Iosevkata
            ${pkgs.lib.optionalString (builtins.elem "Iosevkata" variants && forRelease) ''
              zip --recurse-paths --junk-paths "$out/Iosevkata-v${version}.zip" "dist/Iosevkata/TTF/"*
              (cd dist/Iosevkata/TTF && tar --transform='s|.*/||' -cf - *) | zstd -o "$out/Iosevkata-v${version}.tar.zst"
            ''}
            ${pkgs.lib.optionalString (builtins.elem "Iosevkata" variants && !forRelease) ''
              install "dist/Iosevkata/TTF"/* "$fontdir"
            ''}

            # IosevkataNerdFont
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFont" variants && forRelease) ''
              zip --recurse-paths --junk-paths "$out/IosevkataNerdFont-v${version}.zip" "dist/Iosevkata/NerdFont"/*
              (cd dist/Iosevkata/NerdFont && tar --transform='s|.*/||' -cf - *) | zstd -o "$out/IosevkataNerdFont-v${version}.tar.zst"
            ''}
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFont" variants && !forRelease) ''
              install "dist/Iosevkata/NerdFont"/* "$fontdir"
            ''}

            # IosevkataNerdFontMono
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFontMono" variants && forRelease) ''
              zip --recurse-paths --junk-paths "$out/IosevkataNerdFontMono-v${version}.zip" "dist/Iosevkata/NerdFontMono"/*
              (cd dist/Iosevkata/NerdFontMono && tar --transform='s|.*/||' -cf - *) | zstd -o "$out/IosevkataNerdFontMono-v${version}.tar.zst"
            ''}
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFontMono" variants && !forRelease) ''
              install "dist/Iosevkata/NerdFontMono"/* "$fontdir"
            ''}

            runHook postInstall
          '';

          enableParallelBuilding = true;
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        overlays = {
          # a default flake to add all variants
          default = final: prev: { iosevkata = self.packages.${prev.system}.iosevkata; };
        };
      };
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          # They are system agnostic, so, they are built with a specific system (x86_64-linux), and aliased to other systems.
          # iosevkata builds all variants for a nix package
          packages.iosevkata = buildIosevkata {
            pkgs = x64LinuxPkgs;
            variants = [
              "Iosevkata"
              "IosevkataNerdFont"
              "IosevkataNerdFontMono"
            ];
            forRelease = false;
          };
          # iosevkata-release builds all variants for zip and zstd
          packages.iosevkata-release = buildIosevkata {
            pkgs = x64LinuxPkgs;
            variants = [
              "Iosevkata"
              "IosevkataNerdFont"
              "IosevkataNerdFontMono"
            ];
            forRelease = true;
          };
          # iosevkata-only builds Iosevkata for a nix package
          packages.iosevkata-only = buildIosevkata {
            pkgs = x64LinuxPkgs;
            variants = [ "Iosevkata" ];
            forRelease = false;
          };
          # iosevkata-nerd-font-only builds IosevkataNerdFont for a nix package
          packages.iosevkata-nerd-font-only = buildIosevkata {
            pkgs = x64LinuxPkgs;
            variants = [ "IosevkataNerdFont" ];
            forRelease = false;
          };
          # iosevkata-nerd-font-mono-only builds IosevkataNerdFontMono for a nix package
          packages.iosevkata-nerd-font-mono-only = buildIosevkata {
            pkgs = x64LinuxPkgs;
            variants = [ "IosevkataNerdFontMono" ];
            forRelease = false;
          };

          # Shells: default development shell, which is system specific.
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.busybox
              pkgs.difftastic
              pkgs.fontforge
              pkgs.nix-prefetch
              pkgs.prefetch-npm-deps
              pkgs.silicon
              (pkgs.python3.withPackages (ps: [
                ps.configargparse
                ps.fontforge
                ps.requests
                ps.rich
                ps.typer
              ]))
            ];
          };
        };
    };
}
