{ pkgs ? import ./nix { } }:

with pkgs;
let
  common = import ./nix/common.nix { inherit pkgs; };
  check = writeShellScriptBin "check" ''
    luajit test/test.lua
  '';
  doc = writeShellScriptBin "doc" ''
    ldoc .
  '';
in
stdenv.mkDerivation rec {
  name = "lsh";

  buildInputs = common.buildInputs ++ [ luajit.pkgs.ldoc check doc ];

  shellHook = ''
    LUA_PATH="$LUA_PATH;$(pwd)/?.lua"
  '';
}
