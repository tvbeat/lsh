{ pkgs ? import ./nix/pkgs.nix {} }:

with pkgs;

let
  common = import ./nix/common.nix { inherit pkgs; };
in stdenv.mkDerivation rec {
  pname = "lsh";
  version = "pre";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = common.buildInputs ++ [ common.lsh-bin ];

  # todo: fix tests to not use file system
  # doCheck = true;

  checkPhase = ''
    LUA_PATH="$LUA_PATH;$(pwd)/?.lua" luajit test/test.lua
  '';

  installPhase = ''
    mkdir -p $out/share/lua/${luajit.luaversion}
    cp -r lsh $out/share/lua/${luajit.luaversion}/
    cp lsh.lua $out/share/lua/${luajit.luaversion}/
    mkdir $out/bin
    cp ${common.lsh-bin}/bin/lsh $out/bin/
    wrapProgram $out/bin/lsh \
      --argv0 lsh \
      --set LUA_PATH  "$LUA_PATH;$out/share/lua/${luajit.luaversion}/?.lua;;" \
      --set LUA_CPATH "$LUA_CPATH;;"
  '';

}
