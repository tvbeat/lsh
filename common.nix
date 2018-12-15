{ pkgs }:

with pkgs;

rec {

  buildInputs = [
    luajit
    luajitPackages.syscall
  ];

}
