{ pkgs }:

let
  luajit = (pkgs.luajit.overrideAttrs (old: rec {
    name = "luajit-${version}";
    version = "2.1.0-beta3-${rev}";
    rev = "d0cda5c";

    preBuild = ''
      buildFlagsArray+=(CFLAGS+=" -fPIC -O2 -msse4.2" XCFLAGS+=" -DLUAJIT_ENABLE_GC64" LDFLAGS+="-pthread")
    '';

    src = pkgs.fetchFromGitHub {
      inherit rev;
      owner = "openresty";
      repo = "luajit2";
      sha256 = "07ycyz58h3k3s83gydrgg5cbmi2jlykwd4n0rwr7g3axl9g1rc78";
    };

    postInstall = ''
      ( cd "$out/include"; ln -s luajit-*/* . )
      ln -s "$out"/bin/luajit-* "$out"/bin/lua
      ln -s "$out/share/luajit-2.1.0-beta3/jit" "$out/share/lua/5.1/jit"
    '';
  })).override {
    self = luajit;
  };
in rec {

  buildInputs = [
    luajit
    luajit.pkgs.ljsyscall
  ];

}
