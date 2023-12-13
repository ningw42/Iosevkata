{
  description = "Iosevkata, a customized variant of Iosevka";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: rec {
    # Packages
    packages.x86_64-linux.iosevkata = buildIosevkata {
      inherit pkgs version hash npmDepsHash privateBuildPlan fontPatcherVersion fontPatcherHash;
      withNerdFont = false;
      withNerdFontMono = false;
    };

    packages.x86_64-linux.iosevkata-nerd-font = buildIosevkata {
      inherit pkgs version hash npmDepsHash privateBuildPlan fontPatcherVersion fontPatcherHash;
      withNerdFont = true;
      withNerdFontMono = true;
    };

    # Metadata
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    version = "27.3.5";
    hash = "sha256-dqXr/MVOuEmAMueaRWsnzY9MabhnyBRtLR9IDVLN79I=";
    npmDepsHash = "sha256-bux8aFBP1Pi5pAQY1jkNTqD2Ny2j+QQs+QRaXWJj6xg=";
    privateBuildPlan = builtins.readFile ./private-build-plans.toml;
    fontPatcherVersion = "3.1.1";
    fontPatcherHash = "sha256-H2dPUs6HVKJcjxy5xtz9nL3SSPXKQF3w30/0l7A0PeY=";

    # Builder
    buildIosevkata = { pkgs, version, hash, npmDepsHash, privateBuildPlan, fontPatcherVersion, fontPatcherHash, withNerdFont, withNerdFontMono }:
      pkgs.buildNpmPackage rec {
        inherit version npmDepsHash privateBuildPlan;
        needNerdFontPatcher = withNerdFont || withNerdFontMono;

        pname = "iosevkata";

        srcs = [
          (pkgs.fetchFromGitHub {
            inherit hash;
            name = "iosevka";
            owner = "be5invis";
            repo = "iosevka";
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
          pkgs.fontforge
          (pkgs.python3.withPackages (ps: [ ps.fontforge ps.configargparse]))
        ];

        passAsFile = [ "privateBuildPlan" ];

        sourceRoot = "iosevka";

        # Optional Patch Phase: replace `argparse` with `configargparse` because argparse isn't available in nixpkgs.
        prePatch = pkgs.lib.optionalString needNerdFontPatcher ''
          cd ../nerd-fonts-patcher
          chmod -R +w .
        '';
        patches = pkgs.lib.optionals needNerdFontPatcher [ ./patches/configargparse.patch ];
        postPatch = pkgs.lib.optionalString needNerdFontPatcher ''
          cd ../iosevka
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
          export WITH_NERD_FONT=${if withNerdFont then "true" else "false"}
          export WITH_NERD_FONT_MONO=${if withNerdFontMono then "true" else "false"}

          runHook preBuild

          # build Iosevkata
          npm run build --no-update-notifier -- --verbose=9 ttf::iosevkata

          # patch nerd font if necessary
          if [ "$WITH_NERD_FONT" = "true" ]; then
            nerdfontdir="dist/iosevkata/nerdfont"
            mkdir $nerdfontdir
            find dist/iosevkata/ttf -type f -name "*.ttf" | while read file; do
              echo "patching file: $file"
              python3 ../nerd-fonts-patcher/font-patcher --glyphdir ../nerd-fonts-patcher/src/glyphs --careful --complete $file --outputdir $nerdfontdir
            done
          fi

          # patch nerd font mono if necessary
          if [ "$WITH_NERD_FONT_MONO" = "true" ]; then
            nerdfontmonodir="dist/iosevkata/nerdfontmono"
            mkdir $nerdfontmonodir
            find dist/iosevkata/ttf -type f -name "*.ttf" | while read file; do
              echo "patching file: $file"
              python3 ../nerd-fonts-patcher/font-patcher --glyphdir ../nerd-fonts-patcher/src/glyphs --careful --mono --complete $file --outputdir $nerdfontmonodir
            done
          fi

          runHook postBuild
        '';

        # Install Phase: just add artifacts to zip.
        installPhase = ''
          runHook preInstall

          # pack Iosevkata
          mkdir -p $out
          cd dist/iosevkata/ttf
          zip -r "$out/Iosevkata-$version.zip" *

          # pack Iosevkata Nerd Font if necessary
          if [ "$WITH_NERD_FONT" = "true" ]; then
            cd ../nerdfont
            zip -r "$out/IosevkataNerdFont-$version.zip" *
          fi

          # pack Iosevkata Nerd Font Mono if necessary
          if [ "$WITH_NERD_FONT_MONO" = "true" ]; then
            cd ../nerdfontmono
            zip -r "$out/IosevkataNerdFontMono-$version.zip" *
          fi

          runHook postInstall
        '';

        enableParallelBuilding = true;
      };
  };
}
