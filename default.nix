{ pkgs ? import <nixpkgs> {}, isShell ? false }:
let
  pkg = pkgs.buildGoModule {
    name = "ssh-forward";
    src = ./.;
    vendorSha256 = "0kmcsr1g08gjw8xn6xbp3jwfmv8xr936sxsk9365ph6fj44rfd6z";
  };
  shell = pkgs.mkShell {
    inputsFrom = [ pkg ];
    nativeBuildInputs = [
      pkgs.gopls
      pkgs.diceware
    ];
  };
in if isShell then shell else pkg
