{
  description = "Small Lua shell library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat }:
    flake-utils.lib.eachDefaultSystem (system: {
      packages.default = self.packages.${system}.lsh;
      packages.lsh = with nixpkgs.legacyPackages.${system};
        luajit.pkgs.buildLuaPackage {
          pname = "lsh";
          version = "pre";

          src = ./.;

          nativeBuildInputs = [ makeWrapper luajit.pkgs.ldoc ];
          nativeCheckInputs = [ luajit.pkgs.busted ];
          propagatedBuildInputs = [ luajit.pkgs.ljsyscall ];

          buildPhase = ''
            ldoc .
          '';

          doCheck = true;
          checkPhase = ''
            runHook preCheck
            busted
            runHook postCheck
          '';

          installPhase = ''
            mkdir -p $out/share/lua/${luajit.luaversion}/
            cp lsh.lua $out/share/lua/${luajit.luaversion}/
            cp -r lsh $out/share/lua/${luajit.luaversion}/

            mkdir -p $out/bin
            cp bin/lsh $out/bin/
            wrapProgram $out/bin/lsh \
              --argv0 lsh \
              --set LUA_PATH  "${luajit.pkgs.luaLib.genLuaPathAbsStr luajit.pkgs.ljsyscall};$out/share/lua/${luajit.luaversion}/?.lua;;" \
              --set LUA_CPATH ";;"

            mkdir -p $out/share/doc/lsh
            cp -r doc/* $out/share/doc/lsh/
          '';

          meta = with lib; {
            description = "Small Lua shell library";
            homepage = "https://github.com/tvbeat/lsh";
            license = licenses.mit;
          };
        };

      devShells.default = with nixpkgs.legacyPackages.${system};
        mkShell {
          name = "lsh";

          packages = [
            luajit
            luajit.pkgs.busted
            luajit.pkgs.ldoc
            luajit.pkgs.ljsyscall
          ];

          shellHook = ''
            LUA_PATH="$LUA_PATH;$(pwd)/?.lua"
          '';
        };
    });
}
