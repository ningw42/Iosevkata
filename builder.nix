# Infrastructure: nixpkgs and build tooling
{
  pkgs,
  nerd-font-patcher,
}:
# Metadata: version and dependencies
{
  version,
  iosevka,
  privateBuildPlan,
}:
# Build configuration: what artifacts to produce
{
  variants,
  forRelease,
}:
let
  nerdFontPatcher = nerd-font-patcher.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hasUpstreamIosevkataPatches = pkgs.lib.versionAtLeast nerdFontPatcher.version "3.5.0";
  centerWideArgs = pkgs.lib.optionalString hasUpstreamIosevkataPatches "--experimental center-wide";
  symbolsCenterWideArgs = pkgs.lib.optionalString hasUpstreamIosevkataPatches "--center-wide";
in
pkgs.buildNpmPackage rec {
  inherit version privateBuildPlan;
  npmDepsHash = iosevka.npmDepsHash;
  requiresNerdFonts =
    builtins.elem "IosevkataNerdFont" variants
    || builtins.elem "IosevkataNerdFontMono" variants
    || builtins.elem "IosevkataSymbolsNerdFont" variants;

  pname = "iosevkata";

  src = pkgs.fetchFromGitHub {
    hash = iosevka.hash;
    name = "Iosevka";
    owner = "be5invis";
    repo = "Iosevka";
    rev = "v${iosevka.version}";
  };

  nativeBuildInputs = [
    pkgs.gnutar
    pkgs.ttfautohint-nox
    pkgs.zip
    pkgs.zstd
  ]
  ++ pkgs.lib.optionals requiresNerdFonts [
    # optional build inputs for nerd-fonts
    # for parallel font patching
    pkgs.parallel
    # For v3.4, this package carries the cellopt reorder and horizontal-centering
    # patches. In v3.5+, cellopt is upstream and horizontal centering is enabled
    # through the upstream center-wide option below.
    nerdFontPatcher
  ];

  passAsFile = [ "privateBuildPlan" ];

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
      parallel -j $NIX_BUILD_CORES nerd-font-patcher ${centerWideArgs} --careful --complete --outputdir $nerdfontdir ::: dist/Iosevkata/TTF/*
    ''}

    # patch nerd font mono if necessary
    ${pkgs.lib.optionalString (builtins.elem "IosevkataNerdFontMono" variants) ''
      nerdfontmonodir="dist/Iosevkata/NerdFontMono"
      mkdir $nerdfontmonodir
      parallel -j $NIX_BUILD_CORES nerd-font-patcher ${centerWideArgs} --careful --mono --complete --outputdir $nerdfontmonodir ::: dist/Iosevkata/TTF/*
    ''}

    # build symbols-only nerd font if necessary
    ${pkgs.lib.optionalString (builtins.elem "IosevkataSymbolsNerdFont" variants) ''
      symbolsdir="dist/Iosevkata/SymbolsNerdFont"
      mkdir $symbolsdir
      nerd-font-patcher-symbols ${symbolsCenterWideArgs} --square-metrics -n SymbolsNerdFontIosevkata -o $symbolsdir dist/Iosevkata/TTF/Iosevkata-Regular.ttf
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

    # IosevkataSymbolsNerdFont
    ${pkgs.lib.optionalString (builtins.elem "IosevkataSymbolsNerdFont" variants && forRelease) ''
      zip --recurse-paths --junk-paths "$out/IosevkataSymbolsNerdFont-v${version}.zip" "dist/Iosevkata/SymbolsNerdFont"/*
      (cd dist/Iosevkata/SymbolsNerdFont && tar --transform='s|.*/||' -cf - *) | zstd -o "$out/IosevkataSymbolsNerdFont-v${version}.tar.zst"
    ''}
    ${pkgs.lib.optionalString (builtins.elem "IosevkataSymbolsNerdFont" variants && !forRelease) ''
      install "dist/Iosevkata/SymbolsNerdFont"/* "$fontdir"
    ''}

    runHook postInstall
  '';

  enableParallelBuilding = true;
}
