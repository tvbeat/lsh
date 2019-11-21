# lsh

Small Lua shell library.

Highly experimental!

See `test/test.lua` for example usage.


## Install and Use

Clone this repo, cd into it, then:

```
nix-env -i .
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
