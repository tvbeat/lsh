## pinned tvb-nixoveray and nixpkgs
# Generate sha256 with:
##  $ nix-prefetch-url --unpack $url

let
  mirror = "https://tvbeat-nix-channels.s3-eu-west-1.amazonaws.com";

  overlay = fetchTarball {
    url = "${mirror}/tvb-nixoverlay/master/ce9941e/nixexprs.tar.xz";
    sha256 = "0hmynl75li2x880hkhidx80drj2fy8dbl45vl7rnwfdy1sgz0lhd";
  };

  nixpkgs = fetchTarball {
    url = "${mirror}/nixpkgs/c2c4cc6/nixexprs.tar.xz";
    sha256 = "179rwkzpgmmiw3vdrd033x5l5xyp9gm2zd7k6h580whns85lgkra";
  };

  pkgs = import overlay { inherit nixpkgs; };

in pkgs
