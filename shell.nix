{ pkgs ? import ./pkgs.nix
}:

with pkgs;
with import ./common.nix { inherit pkgs; };

stdenv.mkDerivation rec {
  name = "lsh1";

  inherit buildInputs;

  enableParallelBuilding = true;

  shellHook = ''
    function ltest() {
      luajit test/test.lua
    }
    
    export PS1="\[\033[38;5;10m\]\u@\h[${name} nix-shell]\[$(tput sgr0)\]\[\033[38;5;15m\]:\[$(tput sgr0)\]\[\033[38;5;39m\]\w\[$(tput sgr0)\]\\$\[$(tput sgr0)\] \[$(tput sgr0)\]"

    export prefix=$(pwd)

    # LuaJIT
    LUA_PATH="$LUA_PATH;$prefix/?.lua"

  '';
}
