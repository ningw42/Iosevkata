{
  description = "Iosevkata, a customized variant of Iosevka";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nerd-font-patcher.url = "github:ningw42/nerd-font-patcher/v3.4.0";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      nerd-font-patcher,
      ...
    }:
    let
      # Metadata: version and dependencies
      version = "26.03.2";
      iosevka = {
        version = "34.3.0";
        hash = "sha256-Se+GIx+Uea/lMOdTDhbt/H+F0yeyMHclpSp52U+pmtA=";
        npmDepsHash = "sha256-LSfVuNP2Ck0PUbrjHsCXmoiZfT3x/Mk+CpC9cAj96bE=";
      };

      # Build plans
      privateBuildPlan = builtins.readFile ./private-build-plans.toml;

      # The system that builds Iosevkata
      buildSystem = "x86_64-linux";

      # Builder
      buildIosevkata =
        import ./builder.nix
          {
            pkgs = nixpkgs.legacyPackages.${buildSystem};
            inherit nerd-font-patcher;
          }
          {
            inherit
              version
              iosevka
              privateBuildPlan
              ;
          };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks.flakeModule
      ];
      flake = {
        overlays = {
          # a default flake to add all variants
          default = final: prev: { iosevkata = self.packages.${prev.stdenv.hostPlatform.system}.iosevkata; };
        };
      };
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          # Treefmt configuration
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.black.enable = true;
          };

          # Git hooks configuration
          pre-commit.settings.hooks.treefmt = {
            enable = true;
            package = config.treefmt.build.wrapper;
          };

          # They are system agnostic, so, they are built with a specific system (x86_64-linux), and aliased to other systems.
          # iosevkata builds all variants for a nix package
          packages.iosevkata = buildIosevkata {
            variants = [
              "Iosevkata"
              "IosevkataNerdFont"
              "IosevkataNerdFontMono"
              "IosevkataSymbolsNerdFont"
            ];
            forRelease = false;
          };
          # iosevkata-release builds all variants for zip and zstd
          packages.iosevkata-release = buildIosevkata {
            variants = [
              "Iosevkata"
              "IosevkataNerdFont"
              "IosevkataNerdFontMono"
              "IosevkataSymbolsNerdFont"
            ];
            forRelease = true;
          };
          # iosevkata-only builds Iosevkata for a nix package
          packages.iosevkata-only = buildIosevkata {
            variants = [ "Iosevkata" ];
            forRelease = false;
          };
          # iosevkata-nerd-font-only builds IosevkataNerdFont for a nix package
          packages.iosevkata-nerd-font-only = buildIosevkata {
            variants = [ "IosevkataNerdFont" ];
            forRelease = false;
          };
          # iosevkata-nerd-font-mono-only builds IosevkataNerdFontMono for a nix package
          packages.iosevkata-nerd-font-mono-only = buildIosevkata {
            variants = [ "IosevkataNerdFontMono" ];
            forRelease = false;
          };
          # iosevkata-symbols-nerd-font-only builds IosevkataSymbolsNerdFont for a nix package
          packages.iosevkata-symbols-nerd-font-only = buildIosevkata {
            variants = [ "IosevkataSymbolsNerdFont" ];
            forRelease = false;
          };

          # Shells: default development shell, which is system specific.
          devShells.default = pkgs.mkShell {
            name = "IosevkataDevShell";
            inputsFrom = [
              config.pre-commit.devShell
              config.treefmt.build.devShell
            ];
            packages = [
              pkgs.busybox
              pkgs.difftastic
              pkgs.fontforge
              pkgs.nix-prefetch
              pkgs.prefetch-npm-deps
              pkgs.silicon
              (pkgs.python3.withPackages (ps: [
                ps.fontforge
                ps.requests
                ps.rich
                ps.typer
              ]))
            ];
          };
        };
    };
}
