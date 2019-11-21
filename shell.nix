{ pkgs ? import ./nix/pkgs.nix {}, ... }:

with pkgs;

let
  common = import ./nix/common.nix { inherit pkgs; };
  update-nixpkgs = pkgs.writeShellScriptBin "update-nixpkgs" ''
    ${pkgs.nix-prefetch-git}/bin/nix-prefetch-git \
      https://github.com/nixos/nixpkgs.git \
      --rev refs/heads/master \
      > ./nix/nixpkgs.json
  '';
  check = writeShellScriptBin "check" ''
    luajit test/test.lua
  '';
  doc = writeShellScriptBin "doc" ''
    ldoc .
  '';
in stdenv.mkDerivation rec {
  name = "lsh";

  buildInputs = common.buildInputs ++ [ update-nixpkgs pkgs.luajit.pkgs.ldoc check doc ];

  enableParallelBuilding = true;

  shellHook = ''
    LUA_PATH="$LUA_PATH;$(pwd)/?.lua"
  '';
}
