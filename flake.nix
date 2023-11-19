{
  description = "Niosevka, a customized variant of Iosevka";

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
  in
  {
    packages.x86_64-linux.niosevka = pkgs.buildNpmPackage {
      inherit version npmDepsHash privateBuildPlan;
      pname = "niosevka";

      src = pkgs.fetchFromGitHub {
        inherit hash;
        owner = "be5invis";
        repo = "iosevka";
        rev = "v${version}";
      };

      nativeBuildInputs = [
        pkgs.ttfautohint-nox
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

      meta = with pkgs.lib; {
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
    };
  };
}
