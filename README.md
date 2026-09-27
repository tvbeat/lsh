# lsh

Small Lua library for shell scripting.

## Documentation

To start writing shell scripts, read the
[LDoc documentation](https://tvbeat.github.io/lsh/).

## Install and use (Nix)

Clone this repository, go into its directory, and run:

```
nix profile install .#
```

Use the `lsh` wrapper to run Lua scripts:

```
lsh <script.lua>
```

## Develop

Build:

```
nix build
```

Test:

```
nix develop --command ./bin/lsh test/test.lua
```

Generate the documentation in the `doc/` directory:

```
nix develop --command ldoc .
```

## License

MIT, see [LICENSE](LICENSE).
