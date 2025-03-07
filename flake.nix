{
  description = "Iosevkata, a customized variant of Iosevka";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Metadata
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      privateBuildPlan = builtins.readFile ./private-build-plans.toml;
      version = "2025.03.03.2";
      iosevkaVersion = "33.0.1";
      hash = "sha256-Yosl6dqbYLsX1whkSazHHlbZ4zhJ5jSZmrdi22BLBJM=";
      npmDepsHash = "sha256-/a2VVz8w2a2KfOgWAg0AWmdbPqQ7bN6rBHhv6b1TwYg=";
      fontPatcherVersion = "3.3.0";
      fontPatcherHash = "sha256-/LbO8+ZPLFIUjtZHeyh6bQuplqRfR6SZRu9qPfVZ0Mw=";

      # Builder
      buildIosevkata =
        {
          pkgs,
          version,
          iosevkaVersion,
          hash,
          npmDepsHash,
          privateBuildPlan,
          fontPatcherVersion,
          fontPatcherHash,
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

          # Optional Patch Phase: replace `argparse` with `configargparse` because argparse isn't available in nixpkgs.
          prePatch = pkgs.lib.optionalString needNerdFontPatcher ''
            cd ../nerd-fonts-patcher
            chmod -R +w .
          '';
          patches = pkgs.lib.optionals needNerdFontPatcher [ ./patches/configargparse_v3.3.0.patch ];
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
    {
      # Packages: Iosevkata
      packages.x86_64-linux.iosevkata = buildIosevkata {
        inherit
          pkgs
          version
          iosevkaVersion
          hash
          npmDepsHash
          privateBuildPlan
          fontPatcherVersion
          fontPatcherHash
          ;
        variants = [ "Iosevkata" ];
        forRelease = false;
      };

      # Packages: IosevkataNerdFont
      packages.x86_64-linux.iosevkata-nerd-font = buildIosevkata {
        inherit
          pkgs
          version
          iosevkaVersion
          hash
          npmDepsHash
          privateBuildPlan
          fontPatcherVersion
          fontPatcherHash
          ;
        variants = [ "IosevkataNerdFont" ];
        forRelease = false;
      };

      # Packages: IosevkataNerdFontMono
      packages.x86_64-linux.iosevkata-nerd-font-mono = buildIosevkata {
        inherit
          pkgs
          version
          iosevkaVersion
          hash
          npmDepsHash
          privateBuildPlan
          fontPatcherVersion
          fontPatcherHash
          ;
        variants = [ "IosevkataNerdFontMono" ];
        forRelease = false;
      };

      # Packages: all variants
      packages.x86_64-linux.iosevkata-all = buildIosevkata {
        inherit
          pkgs
          version
          iosevkaVersion
          hash
          npmDepsHash
          privateBuildPlan
          fontPatcherVersion
          fontPatcherHash
          ;
        variants = [
          "Iosevkata"
          "IosevkataNerdFont"
          "IosevkataNerdFontMono"
        ];
        forRelease = false;
      };

      # Packages: all variants for GitHub release
      packages.x86_64-linux.iosevkata-all-release = buildIosevkata {
        inherit
          pkgs
          version
          iosevkaVersion
          hash
          npmDepsHash
          privateBuildPlan
          fontPatcherVersion
          fontPatcherHash
          ;
        variants = [
          "Iosevkata"
          "IosevkataNerdFont"
          "IosevkataNerdFontMono"
        ];
        forRelease = true;
      };

      # Shells: default development shell
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.busybox
          pkgs.difftastic
          pkgs.fontforge
          pkgs.nix-prefetch
          pkgs.prefetch-npm-deps
          (pkgs.python3.withPackages (ps: [
            ps.fontforge
            ps.configargparse
          ]))
        ];
      };
    };
}
