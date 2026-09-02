let
  sources = import ./npins;

  pkgs = import sources.nixpkgs { };
in
pkgs.mkShellNoCC {
  packages = with pkgs; [
    tinymist
    typst
    harper
    shellcheck
    bash-language-server
    nixos-rebuild-ng
    retry
    python314Packages.tqdm
    nushell
  ];
}
