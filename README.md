# lsh

Small Lua shell library.

## Doc

To get started with writing shell scripts, head over to
[LDoc documentation](https://tvbeat.github.io/lsh/).

## Install and Use (NIX)

Clone this repo, cd into it, then:

```
nix profile install .#
```

Run lua scripts with wrapper:

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


Generate Documentation in `doc/` directory:

```
nix develop --command ldoc .
```

## License

MIT, see [LICENSE](LICENSE).
