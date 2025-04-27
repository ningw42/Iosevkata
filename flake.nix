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
      # Metadata: version, dependency versions and hashes
      version = "25.04.1";
      iosevkaVersion = "33.2.2";
      hash = "sha256-dhMTcceHru/uLHRY4eWzFV+73ckCBBnDlizP3iY5w5w=";
      npmDepsHash = "sha256-5DcMV9N16pyQxRaK6RCoeghZqAvM5EY1jftceT/bP+o=";
      fontPatcherVersion = "3.4.0";
      fontPatcherHash = "sha256-JR4sxV2yOXtrnIjFBh4as304BjNIcKkBzxOKLxrjo2I=";

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
          inherit version npmDepsHash privateBuildPlan;
          needNerdFontPatcher =
            builtins.elem "IosevkataNerdFont" variants || builtins.elem "IosevkataNerdFontMono" variants;

          pname = "iosevkata";

          srcs =
            [
              (pkgs.fetchFromGitHub {
                inherit hash;
                name = "Iosevka";
                owner = "be5invis";
                repo = "Iosevka";
                rev = "v${iosevkaVersion}";
              })
            ]
            ++ pkgs.lib.optionals needNerdFontPatcher [
              # optional source for NerdFontPatcher
              (pkgs.fetchzip {
                name = "nerd-fonts-patcher";
                url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${fontPatcherVersion}/FontPatcher.zip";
                hash = fontPatcherHash;
                stripRoot = false; # assume flat structure from the zip file.
              })
            ];

          nativeBuildInputs =
            [
              pkgs.zip
              pkgs.ttfautohint-nox
            ]
            ++ pkgs.lib.optionals needNerdFontPatcher [
              # optional build inputs for NerdFontPatcher
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
          prePatch = pkgs.lib.optionalString needNerdFontPatcher ''
            cd ../nerd-fonts-patcher
            chmod -R +w .
          '';
          patches = pkgs.lib.optionals needNerdFontPatcher [
            ./patches/fontpatcher/v3.4.0/configargparse.patch
            ./patches/fontpatcher/v3.4.0/horizontal_centered.patch
          ];
          postPatch = pkgs.lib.optionalString needNerdFontPatcher ''
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
              parallel -j $NIX_BUILD_CORES python3 ../nerd-fonts-patcher/font-patcher --glyphdir ../nerd-fonts-patcher/src/glyphs --careful --complete --outputdir $nerdfontdir ::: dist/Iosevkata/TTF/*
            ''}

            # patch nerd font mono if necessary
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFontMono" variants) ''
              nerdfontmonodir="dist/Iosevkata/NerdFontMono"
              mkdir $nerdfontmonodir
              parallel -j $NIX_BUILD_CORES python3 ../nerd-fonts-patcher/font-patcher --glyphdir ../nerd-fonts-patcher/src/glyphs --careful --mono --complete --outputdir $nerdfontmonodir ::: dist/Iosevkata/TTF/*
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
            ''}
            ${pkgs.lib.optionalString (builtins.elem "Iosevkata" variants && !forRelease) ''
              install "dist/Iosevkata/TTF"/* "$fontdir"
            ''}

            # IosevkataNerdFont
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFont" variants && forRelease) ''
              zip --recurse-paths --junk-paths "$out/IosevkataNerdFont-v${version}.zip" "dist/Iosevkata/NerdFont"/*
            ''}
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFont" variants && !forRelease) ''
              install "dist/Iosevkata/NerdFont"/* "$fontdir"
            ''}

            # IosevkataNerdFontMono
            ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFontMono" variants && forRelease) ''
              zip --recurse-paths --junk-paths "$out/IosevkataNerdFontMono-v${version}.zip" "dist/Iosevkata/NerdFontMono"/*
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
          # iosevkata-release builds all variants for zipballs
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
                ps.fontforge
                ps.configargparse
              ]))
            ];
          };
        };
    };
}
