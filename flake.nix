{
  description = "Iosevkata, a customized variant of Iosevka";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: rec {
    # Metadata
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    privateBuildPlan = builtins.readFile ./private-build-plans.toml;
    version = "30.3.1";
    hash = "sha256-qT7wk8xIGFC44T1W5En9fbebJnwq/3tnwoT87nkmMmY=";
    npmDepsHash = "sha256-VguAsHX1eWivSd5UhkY0+Pvrh4xxqDn87PI2klC+Xfk=";
    fontPatcherVersion = "3.2.1";
    fontPatcherHash = "sha256-3s0vcRiNA/pQrViYMwU2nnkLUNUcqXja/jTWO49x3BU=";

    # Packages: Iosevkata
    packages.x86_64-linux.iosevkata = buildIosevkata {
      inherit pkgs version hash npmDepsHash privateBuildPlan fontPatcherVersion fontPatcherHash;
      withNerdFont = false;
      withNerdFontMono = false;
    };

    # Packages: IosevkataNerdFont
    packages.x86_64-linux.iosevkata-nerd-font = buildIosevkata {
      inherit pkgs version hash npmDepsHash privateBuildPlan fontPatcherVersion fontPatcherHash;
      withNerdFont = true;
      withNerdFontMono = false;
    };

    # Shells: default development shell
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [
        pkgs.busybox
        pkgs.fontforge
        pkgs.nix-prefetch
        pkgs.prefetch-npm-deps
        (pkgs.python3.withPackages (ps: [ ps.fontforge ps.configargparse ]))
      ];
    };

    # Builder
    buildIosevkata = { pkgs, version, hash, npmDepsHash, privateBuildPlan, fontPatcherVersion, fontPatcherHash, withNerdFont, withNerdFontMono }:
      pkgs.buildNpmPackage rec {
        inherit version npmDepsHash privateBuildPlan;
        needNerdFontPatcher = withNerdFont || withNerdFontMono;

        pname = "iosevkata";

        srcs = [
          (pkgs.fetchFromGitHub {
            inherit hash;
            name = "Iosevka";
            owner = "be5invis";
            repo = "Iosevka";
            rev = "v${version}";
          })
        ] ++ pkgs.lib.optionals needNerdFontPatcher [
          # optional source for NerdFontPatcher
          (pkgs.fetchzip {
            name = "nerd-fonts-patcher";
            url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${fontPatcherVersion}/FontPatcher.zip";
            hash = fontPatcherHash;
            stripRoot = false; # assume flat structure from the zip file.
          })
        ];

        nativeBuildInputs = [
          pkgs.zip
          pkgs.ttfautohint-nox
        ] ++ pkgs.lib.optionals needNerdFontPatcher [
          # optional build inputs for NerdFontPatcher
          pkgs.parallel # for parallel font patching
          pkgs.fontforge
          (pkgs.python3.withPackages (ps: [ ps.fontforge ps.configargparse]))
        ];

        passAsFile = [ "privateBuildPlan" ];

        sourceRoot = "Iosevka";

        # Optional Patch Phase: replace `argparse` with `configargparse` because argparse isn't available in nixpkgs.
        prePatch = pkgs.lib.optionalString needNerdFontPatcher ''
          cd ../nerd-fonts-patcher
          chmod -R +w .
        '';
        patches = pkgs.lib.optionals needNerdFontPatcher [ ./patches/configargparse.patch ];
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

          # build Iosevkata
          npm run build --no-update-notifier --targets ttf::Iosevkata -- --jCmd=$NIX_BUILD_CORES --verbose=9

          # patch nerd font if necessary
          ${pkgs.lib.optionalString withNerdFont ''
            nerdfontdir="dist/Iosevkata/nerdfont"
            mkdir $nerdfontdir
            parallel -j $NIX_BUILD_CORES python3 ../nerd-fonts-patcher/font-patcher --glyphdir ../nerd-fonts-patcher/src/glyphs --careful --complete --outputdir $nerdfontdir ::: dist/Iosevkata/TTF/*
          ''}

          # patch nerd font mono if necessary
          ${pkgs.lib.optionalString withNerdFontMono ''
            nerdfontmonodir="dist/Iosevkata/nerdfontmono"
            mkdir $nerdfontmonodir
            parallel -j $NIX_BUILD_CORES python3 ../nerd-fonts-patcher/font-patcher --glyphdir ../nerd-fonts-patcher/src/glyphs --careful --mono --complete --outputdir $nerdfontmonodir ::: dist/Iosevkata/TTF/*
          ''}

          runHook postBuild
        '';

        # Install Phase: just add artifacts to zip.
        installPhase = ''
          runHook preInstall

          # pack Iosevkata
          mkdir -p $out
          cd dist/Iosevkata/TTF
          zip -r "$out/Iosevkata-v$version.zip" *

          # pack Iosevkata Nerd Font if necessary
          ${pkgs.lib.optionalString withNerdFont ''
            cd ../nerdfont
            zip -r "$out/IosevkataNerdFont-v$version.zip" *
          ''}

          # pack Iosevkata Nerd Font Mono if necessary
          ${pkgs.lib.optionalString withNerdFontMono ''
            cd ../nerdfontmono
            zip -r "$out/IosevkataNerdFontMono-v$version.zip" *
          ''}

          runHook postInstall
        '';

        enableParallelBuilding = true;
      };
  };
}
