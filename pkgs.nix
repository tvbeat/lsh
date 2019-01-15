## pinned tvb-nixoveray and nixpkgs
# Generate sha256 with:
##  $ nix-prefetch-url --unpack $url

let
  mirror = "https://tvbeat-nix-channels.s3-eu-west-1.amazonaws.com";

  overlay = fetchTarball {
    url = "${mirror}/tvb-nixoverlay/master/529487a/nixexprs.tar.xz";
    sha256 = "0fhfb16gx5b6hfsf6wgqw5wi7cily9hac5ysipy2dkc38byzgf14";
  };

  nixpkgs = <nixpkgs>;

  pkgs = import overlay { inherit nixpkgs; };

in pkgs
