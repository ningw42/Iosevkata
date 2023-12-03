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
        cp -r "dist/iosevkata/ttf/" "$dist/Iosevkata"

        # add built fonts to build artifact
        cd "$dist/Iosevkata"
        zip -r "$out/Iosevkata-$version.zip" *

        runHook postInstall
      '';

      enableParallelBuilding = true;
    };
  };
}
