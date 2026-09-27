{
  description = "Small Lua shell library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      # lsh uses Linux-only interfaces (memfd, /proc, prctl)
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            }
          )
        );

      version = "0.3.0-unstable-${lib.substring 0 8 (self.lastModifiedDate or "19700101")}";
    in
    {
      # adds `lsh` to the LuaJIT package set (`luajit.pkgs.lsh`)
      overlays.default = final: prev: {
        luajit_2_1 = prev.luajit_2_1.override (old: {
          packageOverrides = lib.composeExtensions (old.packageOverrides or (_: _: { })) (
            luaFinal: luaPrev: {
              lsh = luaFinal.callPackage ./package.nix { inherit version; };
            }
          );
        });
      };

      packages = forAllSystems (pkgs: {
        default = pkgs.luajit.pkgs.lsh;
        lsh = pkgs.luajit.pkgs.lsh;
        doc = pkgs.luajit.pkgs.lsh.doc;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "lsh";

          inputsFrom = [ pkgs.luajit.pkgs.lsh ];
          packages = [ pkgs.luajit ];

          shellHook = ''
            LUA_PATH="$LUA_PATH;$(pwd)/?.lua"
          '';
        };
      });
    };
}
