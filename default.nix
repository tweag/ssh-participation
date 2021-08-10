{ pkgs ? import <nixpkgs> {}, isShell ? false }:
let
  pkg = pkgs.buildGoModule {
    name = "ssh-forward";
    src = ./.;
    vendorSha256 = "0rabkf98y38hyzvdmv1kblc13z8dljgcqqp32xhrrkiam50957k9";
  };
  shell = pkgs.mkShell {
    inputsFrom = [ pkg ];
    nativeBuildInputs = [ pkgs.gopls ];
  };
in if isShell then shell else pkg
