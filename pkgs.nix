## pinned tvb-nixoveray and nixpkgs
# Generate sha256 with:
##  $ nix-prefetch-url --unpack $url

let
  mirror = "https://tvbeat-nix-channels.s3-eu-west-1.amazonaws.com";

  overlay = fetchTarball {
    url = "${mirror}/tvb-nixoverlay/master/ce9941e/nixexprs.tar.xz";
    sha256 = "0hmynl75li2x880hkhidx80drj2fy8dbl45vl7rnwfdy1sgz0lhd";
  };

  nixpkgs = <nixpkgs>;

  pkgs = import overlay { inherit nixpkgs; };

in pkgs
