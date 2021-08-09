{ isShell ? false }:
let
  pkgs = import ../nixpkgs.nix;
  pkg = pkgs.buildGoModule {
    name = "ssh-forward";
    src = ./.;
    vendorSha256 = "0kmcsr1g08gjw8xn6xbp3jwfmv8xr936sxsk9365ph6fj44rfd6z";
  };
  shell = pkgs.mkShell {
    inputsFrom = [ pkg ];
    nativeBuildInputs = [ pkgs.gopls ];
  };
in if isShell then shell else pkg
