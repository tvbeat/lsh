# lsh

Small Lua library for shell scripting.

## Documentation

To start writing shell scripts, read the
[LDoc documentation](https://tvbeat.github.io/lsh/).

## Install and use (Nix)

Install the `lsh` wrapper:

```
nix profile install github:tvbeat/lsh
```

Use the wrapper to run Lua scripts:

```
lsh <script.lua>
```

To use lsh as a library in another flake, add the overlay.
It adds `lsh` to the LuaJIT package set:

```nix
pkgs = import nixpkgs {
  inherit system;
  overlays = [ lsh.overlays.default ];
};

pkgs.luajit.withPackages (ps: [ ps.lsh ])
```

## Develop

Build:

```
nix build
```

Test:

```
nix develop --command busted
```

Run the tests and the selene linter:

```
nix flake check
```

Format the Nix files:

```
nix fmt
```

Build the documentation:

```
nix build .#doc
```

## License

MIT, see [LICENSE](LICENSE).
