{ pkgs }:

with pkgs;

{
  lsh-bin = pkgs.writeScriptBin "lsh" ''
    #!${luajit}/bin/luajit
    local sh = require 'lsh'

    if not arg[1] then error("specify script") end

    local shell_env = setmetatable(sh, { __index = _G })
    setfenv(assert(loadfile(arg[1])), shell_env)()
  '';

  buildInputs = [
    luajit
    luajit.pkgs.ljsyscall
  ];
}
