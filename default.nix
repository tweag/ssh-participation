{ pkgs ? import <nixpkgs> {}, isShell ? false }:
let
  pkg = pkgs.buildGoModule {
    name = "ssh-participation";
    src = ./.;
    vendorSha256 = "0zh9p6vmwbxx30v78vq55hpdwy0wcdl9i5a6qjkvf845w6n4kcnq";
  };
  shell = pkgs.mkShell {
    inputsFrom = [ pkg ];
    nativeBuildInputs = [
      pkgs.gopls
      pkgs.diceware
    ];
  };
in if isShell then shell else pkg
