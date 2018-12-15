## pinned tvb-nixoveray and nixpkgs
# Generate sha256 with:
##  $ nix-prefetch-url --unpack $url

let
  mirror = "https://tvbeat-nix-channels.s3-eu-west-1.amazonaws.com";

  overlay = fetchTarball {
    url = "${mirror}/tvb-nixoverlay/master/1f71839/nixexprs.tar.xz";
    sha256 = "0qnpq4mq5xwgx66yd0ijd9p69hhcac8ab997mkk9mikd3abx51f1";
  };

  nixpkgs = <nixpkgs>;

  pkgs = import overlay { inherit nixpkgs; };

in pkgs
