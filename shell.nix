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
in stdenv.mkDerivation rec {
  name = "lsh";

  buildInputs = common.buildInputs ++ [ update-nixpkgs ];

  enableParallelBuilding = true;

  shellHook = ''
    function check() {
      luajit test/test.lua
    }
    
    LUA_PATH="$LUA_PATH;$(pwd)/?.lua"
  '';
}
