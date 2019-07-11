{ pkgs }:
with pkgs;
let
# TODO: update nixpkgs and remove these
markdown = with luajitPackages; buildLuarocksPackage {
  pname = "markdown";
  version = "0.33-1";

  src = fetchurl {
    url    = https://luarocks.org/markdown-0.33-1.src.rock;
    sha256 = "01xw4b4jvmrv1hz2gya02g3nphsj3hc94hsbc672ycj8pcql5n5y";
  };
  disabled = (luaOlder "5.1") || (luaAtLeast "5.4");
  propagatedBuildInputs = [ lua ];

  meta = with stdenv.lib; {
    homepage = "https://github.com/mpeterv/markdown";
    description = "Markdown text-to-html markup system.";
    license = {
      fullName = "MIT/X11";
    };
  };
};
ldoc = with luajitPackages; buildLuarocksPackage {
  pname = "ldoc";
  version = "1.4.6-2";

  knownRockspec = (fetchurl {
    url    = https://luarocks.org/ldoc-1.4.6-2.rockspec;
    sha256 = "14yb0qihizby8ja0fa82vx72vk903mv6m7izn39mzfrgb8mha0pm";
  }).outPath;

  src = fetchurl {
    url    = http://stevedonovan.github.io/files/ldoc-1.4.6.zip;
    sha256 = "1fvsmmjwk996ypzizcy565hj82bhj17vdb83ln6ff63mxr3zs1la";
  };

  propagatedBuildInputs = [ penlight markdown ];

  meta = with stdenv.lib; {
    homepage = "http://stevedonovan.github.com/ldoc";
    description = "A Lua Documentation Tool";
    license = {
      fullName = "MIT/X11";
    };
  };
};
check = writeShellScriptBin "check" ''
  luajit test/test.lua
'';
doc = writeShellScriptBin "doc" ''
  ldoc .
'';
in rec
{
  buildInputs = [
    luajit
    luajitPackages.syscall
    ldoc
    check
    doc
  ];

}
