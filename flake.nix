{
  description = "Iosevkata, a customized variant of Iosevka";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    version = "27.3.5";
    hash = "sha256-dqXr/MVOuEmAMueaRWsnzY9MabhnyBRtLR9IDVLN79I=";
    npmDepsHash = "sha256-bux8aFBP1Pi5pAQY1jkNTqD2Ny2j+QQs+QRaXWJj6xg=";
    privateBuildPlan = builtins.readFile ./private-build-plans.toml;
  in
  {
    packages.x86_64-linux.iosevkata = pkgs.buildNpmPackage {
      inherit version npmDepsHash privateBuildPlan;
      pname = "iosevkata";

      src = pkgs.fetchFromGitHub {
        inherit hash;
        name = "iosevka";
        owner = "be5invis";
        repo = "iosevka";
        rev = "v${version}";
      };

      nativeBuildInputs = [
        pkgs.ttfautohint-nox
        pkgs.zip
      ];

      passAsFile = [ "privateBuildPlan" ];

      sourceRoot = "iosevka";

      configurePhase = ''
        runHook preConfigure
        cp "$privateBuildPlanPath" private-build-plans.toml
        runHook postConfigure
      '';

      buildPhase = ''
        export HOME=$TMPDIR
        runHook preBuild
        npm run build --no-update-notifier -- --verbose=9 ttf::iosevkata
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cd dist/iosevkata/ttf
        zip -r "$out/Iosevkata-$version.zip" *
        runHook postInstall
      '';

      enableParallelBuilding = true;
    };

    packages.x86_64-linux.iosevkata-nerd-font = pkgs.buildNpmPackage {
      inherit version npmDepsHash privateBuildPlan;
      pname = "iosevkata";

      srcs = [
        (pkgs.fetchFromGitHub {
          inherit hash;
          name = "iosevka";
          owner = "be5invis";
          repo = "iosevka";
          rev = "v${version}";
        })
        (pkgs.fetchzip {
          name = "nerd-fonts-patcher";
          url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FontPatcher.zip";
          hash = "sha256-H2dPUs6HVKJcjxy5xtz9nL3SSPXKQF3w30/0l7A0PeY=";
          stripRoot = false; # assume flat structure from the zip file.
        })
      ];

      nativeBuildInputs = [
        pkgs.autoPatchelfHook
        pkgs.zip
        pkgs.ttfautohint-nox # Iosevka
        pkgs.fontforge # NerdFont
        (pkgs.python3.withPackages (ps: [ ps.fontforge ps.configargparse])) # NerdFont
      ];

      passAsFile = [ "privateBuildPlan" ];

      sourceRoot = "iosevka";

      # Patch Phase: replace `argparse` with `configargparse` because argparse isn't available in nixpkgs.
      prePatch = ''
        cd ../nerd-fonts-patcher
        chmod -R +w .
      '';
      patches = [ ./patches/configargparse.patch ];
      postPatch = ''
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
        runHook preBuild

        # build Iosevkata
        npm run build --no-update-notifier -- --verbose=9 ttf::iosevkata

        # patch nerd font
        nerdfontdir="dist/iosevkata/nerdfont"
        mkdir $nerdfontdir
        find dist/iosevkata/ttf -type f -name "*.ttf" | while read file; do
          echo "patching file: $file"
          python3 ../nerd-fonts-patcher/font-patcher --glyphdir ../nerd-fonts-patcher/src/glyphs --careful --complete $file --outputdir $nerdfontdir
        done

        runHook postBuild
      '';

      # Install Phase: just add artifacts to zip.
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cd dist/iosevkata/ttf
        zip -r "$out/Iosevkata-$version.zip" *
        cd ../nerdfont
        zip -r "$out/IosevkataNerdFont-$version.zip" *
        runHook postInstall
      '';

      enableParallelBuilding = true;
    };
  };
}
