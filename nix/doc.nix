{ pkgs ? import ./default.nix { } }:
let
  common = import ./common.nix { inherit pkgs; };
in
pkgs.stdenv.mkDerivation rec {
  pname = "lsh";
  version = "pre";
  src = ../.;

  nativeBuildInputs = [ pkgs.makeWrapper ];
  buildInputs = common.buildInputs ++ [ common.lsh-bin common.luajit.pkgs.ldoc ];

  buildPhase = ''
    ldoc .
  '';

  installPhase = ''
    mkdir -p $out/share/doc/lsh
    cp -r doc/* $out/share/doc/lsh/
  '';

}
