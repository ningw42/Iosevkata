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
    privateBuildPlan = ''
      # Built with https://typeof.net/Iosevka/customizer

      # A `PragmataPro` styled `Iosevka` variant with my tweaks.
      # 1. **A fixed spacing, no ligature.** I once liked ligature, but it's distracting.
      # 2. **A higher underscore.** To make underscore-connected characters feels connected, like `Menlo`.
      # 3. **A lower hex asterisk.** To place it at the center of the line, like `Menlo`.
      # 4. **An oval-dotted zero.** `PragmataPro`'s diamond shaped zero is too sharp for me.
      # 5. **A few decorations mimicking `mononoki`.** For 'B', 'D', 'P' and 'R'.

      # Reference:
      # The metric-override subsection is copied from Pragmasevka and Iosvmata

      [buildPlans.iosevkata]
      family = "Iosevkata"
      spacing = "fixed"
      serifs = "sans"
      no-cv-ss = true
      export-glyph-names = false

      [buildPlans.iosevkata.variants]
      inherits = "ss08"

      [buildPlans.iosevkata.variants.design]
      underscore = "above-baseline"
      asterisk = "hex-low"
      zero = "oval-dotted"
      capital-b = "standard-unilateral-serifed"
      capital-d = "more-rounded-unilateral-serifed"
      capital-p = "closed-motion-serifed"
      capital-r = "curly-top-left-serifed"

      [buildPlans.iosevkata.widths.normal]
      shape = 500         # Unit Width, measured in 1/1000 em.
      menu  = 5           # Width grade for the font's names.
      css   = "normal"    # "font-stretch' property of webfont CSS.

      [buildPlans.iosevkata.metric-override]
      leading = 1100      # a smaller line height. built-in line height, default is 1250.
      xHeight = 550       # a taller 'x'. height of 'x', default is 520.

      [buildPlans.iosevkata.weights.light]
      shape = 300
      menu  = 300
      css   = 300

      [buildPlans.iosevkata.weights.regular]
      shape = 400
      menu  = 400
      css   = 400

      [buildPlans.iosevkata.weights.medium]
      shape = 500
      menu  = 500
      css   = 500

      [buildPlans.iosevkata.weights.semibold]
      shape = 600
      menu  = 600
      css   = 600

      [buildPlans.iosevkata.weights.bold]
      shape = 700
      menu  = 700
      css   = 700
    '';
  in
  {
    packages.x86_64-linux.iosevkata = pkgs.buildNpmPackage {
      inherit version npmDepsHash privateBuildPlan;
      pname = "iosevkata";

      src = pkgs.fetchFromGitHub {
        inherit hash;
        owner = "be5invis";
        repo = "iosevka";
        rev = "v${version}";
      };

      nativeBuildInputs = [
        pkgs.ttfautohint-nox
        pkgs.zip
      ];

      passAsFile = [ "privateBuildPlan" ];

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

        # create distination directories
        dist="$out/share"
        mkdir -p "$dist/Iosevkata"

        # copy built fonts
        cp -r "dist/iosevkata/ttf" "$dist/Iosevkata"

        # add built fonts to build artifact
        cd "$dist/Iosevkata"
        zip -r "$out/Iosevkata-$version.zip" *

        runHook postInstall
      '';

      enableParallelBuilding = true;
    };
  };
}
