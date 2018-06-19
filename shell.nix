let
  nixpkgs = ./nixpkgs;
  overlay = ./tvb-nixoverlay;
  pkgs = import overlay { inherit nixpkgs; };
in 
with pkgs;
stdenv.mkDerivation rec {
  name = "lsh";
  buildInputs = [
    luajit
    luajitPackages.syscall
  ];

  shellHook = ''
    function test() {
      luajit test/test.lua
    }
    
    export PS1="\[\033[38;5;10m\]\u@\h[${name} nix-shell]\[$(tput sgr0)\]\[\033[38;5;15m\]:\[$(tput sgr0)\]\[\033[38;5;39m\]\w\[$(tput sgr0)\]\\$\[$(tput sgr0)\] \[$(tput sgr0)\]"

    export prefix=$(pwd)

    # LuaJIT
    LUA_PATH="$LUA_PATH;$prefix/?.lua"
    #LUA_CPATH="$LUA_CPATH;$prefix/lib/lua/5.1/?.so"

  '';
}
