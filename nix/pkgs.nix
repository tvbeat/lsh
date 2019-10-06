let
  hostPkgs = import <nixpkgs> {};
  pinnedVersion = hostPkgs.lib.importJSON ./nixpkgs.json;
in import (hostPkgs.fetchFromGitHub {
  owner = "NixOS";
  repo = "nixpkgs";
  inherit (pinnedVersion) rev sha256;
})
