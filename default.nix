{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, stdenv ? pkgs.stdenv
, lib ? pkgs.lib
, buildNpmPackage ? pkgs.buildNpmPackage
, fetchFromGitHub ? pkgs.fetchFromGitHub
, ttfautohint-nox ? pkgs.ttfautohint-nox
}:

buildNpmPackage rec {
  pname = "niosevka";
  version = "27.2.1";

  src = fetchFromGitHub {
    owner = "be5invis";
    repo = "iosevka";
    rev = "v${version}";
    hash = "sha256-+d6pONsAoA0iI7VCuDHBGGjZPaxgLToouQpFTaX6edY=";
  };

  npmDepsHash = "sha256-c/QvrDjjoq2o1le++e7D0Lb18wyZc/q6ct++rkgYtzg=";

  nativeBuildInputs = [
    ttfautohint-nox
  ];

  privateBuildPlan = ''
    # Built with https://typeof.net/Iosevka/customizer

    ## Niosevka, a PragmataPro styled variant with higher underscore, trimed weights and normal width.
    [buildPlans.niosevka]
      family = "Niosevka"
      spacing = "normal"
      serifs = "sans"
      no-cv-ss = true
      export-glyph-names = false

    [buildPlans.niosevka.variants]
      inherits = "ss08"

    [buildPlans.niosevka.variants.design]
      capital-b = "standard-unilateral-serifed"
      capital-d = "more-rounded-unilateral-serifed"
      capital-p = "closed-motion-serifed"
      capital-r = "curly-top-left-serifed"
      zero = "oval-dotted"
      asterisk = "hex-low"
      underscore = "above-baseline"

    [buildPlans.niosevka.weights.light]
      shape = 300
      menu = 300
      css = 300

    [buildPlans.niosevka.weights.regular]
      shape = 400
      menu = 400
      css = 400

    [buildPlans.niosevka.weights.medium]
      shape = 500
      menu = 500
      css = 500

    [buildPlans.niosevka.weights.semibold]
      shape = 600
      menu = 600
      css = 600

    [buildPlans.niosevka.weights.bold]
      shape = 700
      menu = 700
      css = 700

    # normal width is enough for me
    [buildPlans.niosevka.widths.normal]
      shape = 500        # Unit Width, measured in 1/1000 em.
      menu  = 5          # Width grade for the font's names.
      css   = "normal"   # "font-stretch' property of webfont CSS.




    ## Niosevka Fixed, fixed spacing variant of Niosevka
    [buildPlans.niosevka-fixed]
      family = "Niosevka Fixed"
      spacing = "fixed"
      serifs = "sans"
      no-cv-ss = true
      export-glyph-names = false

    [buildPlans.niosevka-fixed.variants]
      inherits = "ss08"

    [buildPlans.niosevka-fixed.variants.design]
      capital-b = "standard-unilateral-serifed"
      capital-d = "more-rounded-unilateral-serifed"
      capital-p = "closed-motion-serifed"
      capital-r = "curly-top-left-serifed"
      zero = "oval-dotted"
      asterisk = "hex-low"
      underscore = "above-baseline"

    [buildPlans.niosevka-fixed.weights.light]
      shape = 300
      menu = 300
      css = 300

    [buildPlans.niosevka-fixed.weights.regular]
      shape = 400
      menu = 400
      css = 400

    [buildPlans.niosevka-fixed.weights.medium]
      shape = 500
      menu = 500
      css = 500

    [buildPlans.niosevka-fixed.weights.semibold]
      shape = 600
      menu = 600
      css = 600

    [buildPlans.niosevka-fixed.weights.bold]
      shape = 700
      menu = 700
      css = 700

    [buildPlans.niosevka-fixed.widths.normal]
      shape = 500
      menu  = 5
      css   = "normal"
    '';

  passAsFile = [ "privateBuildPlan" ];

  configurePhase = ''
    runHook preConfigure
    cp "$privateBuildPlanPath" private-build-plans.toml
    runHook postConfigure
  '';

  buildPhase = ''
    export HOME=$TMPDIR
    runHook preBuild
    npm run build --no-update-notifier -- --verbose=9 ttf::niosevka
    npm run build --no-update-notifier -- --verbose=9 ttf::niosevka-fixed
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    dist="$out/share/niosevka"
    mkdir -p "$dist"
    cp -r "dist/niosevka/ttf"/* "$dist"
    cp -r "dist/niosevka-fixed/ttf"/* "$dist"
    runHook postInstall
  '';

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "https://typeof.net/Iosevka/";
    downloadPage = "https://github.com/be5invis/Iosevka/releases";
    description = "Versatile typeface for code, from code.";
    longDescription = ''
      Iosevka is an open-source, sans-serif + slab-serif, monospace +
      quasi‑proportional typeface family, designed for writing code, using in
      terminals, and preparing technical documents.
    '';
    license = licenses.ofl;
    platforms = platforms.all;
    maintainers = with maintainers; [
      cstrahan
      jfrankenau
      ttuegel
      babariviere
      rileyinman
      AluisioASG
      lunik1
    ];
  };
}
