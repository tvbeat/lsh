# lsh

Small Lua shell library.

## Doc

To get started with writing shell scripts, head over to
[LDoc documentation](https://tvbeat.github.io/lsh/).

## Install and Use (NIX)

Clone this repo, cd into it, then:

```
nix-env -if .
```

Run lua scripts with wrapper:

```
lsh <script.lua>
```

## Develop

Build:

```
nix-build
```

Build documentation package:

```
nix-build nix/doc.nix
```

Test:

```
nix-shell --run check
```


Generate Documentation in `doc/` directory:

```
nix-shell --run doc
```
