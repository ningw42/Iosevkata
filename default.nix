{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, stdenv ? pkgs.stdenv
, lib ? pkgs.lib
, buildNpmPackage ? pkgs.buildNpmPackage
, fetchFromGitHub ? pkgs.fetchFromGitHub
, remarshal ? pkgs.remarshal
, ttfautohint-nox ? pkgs.ttfautohint-nox
  # Custom font set options.
  # See https://typeof.net/Iosevka/customizer
  # Can be a raw TOML string, or a Nix attrset.

  # Ex:
  # privateBuildPlan = ''
  #   [buildPlans.iosevka-custom]
  #   family = "Iosevka Custom"
  #   spacing = "normal"
  #   serifs = "sans"
  #
  #   [buildPlans.iosevka-custom.variants.design]
  #   capital-j = "serifless"
  #
  #   [buildPlans.iosevka-custom.variants.italic]
  #   i = "tailed"
  # '';

  # Or:
  # privateBuildPlan = {
  #   family = "Iosevka Custom";
  #   spacing = "normal";
  #   serifs = "sans";
  #
  #   variants = {
  #     design.capital-j = "serifless";
  #     italic.i = "tailed";
  #   };
  # }
, privateBuildPlan ? null
  # Extra parameters. Can be used for ligature mapping.
  # It must be a raw TOML string.

  # Ex:
  # extraParameters = ''
  #   [[iosevka.compLig]]
  #   unicode = 57808 # 0xe1d0
  #   featureTag = 'XHS0'
  #   sequence = "+>"
  # '';
, extraParameters ? null
}:

buildNpmPackage rec {
  pname = "niosevka";
  version = "23.0.0";

  src = fetchFromGitHub {
    owner = "be5invis";
    repo = "iosevka";
    rev = "v${version}";
    hash = "sha256-j7JE9UHG4xho0a4TqG5rpCJkYyVxgoLxBuRtNMGfkrw=";
  };

  npmDepsHash = "sha256-/zutJ4kwGqBe3snMxyvReJdvlcsm+02ZZyFMdNN6gmc=";

  nativeBuildInputs = [
    remarshal
    ttfautohint-nox
  ];

  buildPlan =
    if builtins.isAttrs privateBuildPlan then
      builtins.toJSON { buildPlans.${pname} = privateBuildPlan; }
    else
      privateBuildPlan;

  inherit extraParameters;
  passAsFile = [ "extraParameters" ] ++ lib.optionals
    (
      !(builtins.isString privateBuildPlan
        && lib.hasPrefix builtins.storeDir privateBuildPlan)
    ) [ "buildPlan" ];

  configurePhase = ''
    runHook preConfigure
    ${lib.optionalString (builtins.isAttrs privateBuildPlan) ''
      remarshal -i "$buildPlanPath" -o private-build-plans.toml -if json -of toml
    ''}
    ${lib.optionalString (builtins.isString privateBuildPlan
      && (!lib.hasPrefix builtins.storeDir privateBuildPlan)) ''
        cp "$buildPlanPath" private-build-plans.toml
      ''}
    ${lib.optionalString (builtins.isString privateBuildPlan
      && (lib.hasPrefix builtins.storeDir privateBuildPlan)) ''
        cp "$buildPlan" private-build-plans.toml
      ''}
    ${lib.optionalString (extraParameters != null) ''
      echo -e "\n" >> params/parameters.toml
      cat "$extraParametersPath" >> params/parameters.toml
    ''}
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
