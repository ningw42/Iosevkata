{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.fontforge
    (pkgs.python3.withPackages (ps: [ ps.fontforge ps.configargparse ]))
  ];
}
