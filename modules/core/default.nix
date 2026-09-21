{ ... }: {
  imports = [
    ./pkgs.nix
    ./git.nix
    ./linux.nix
    ./env.nix
    ./secrets.nix
  ];

  time.timeZone = "Asia/Shanghai";
  services.openssh.enable = true;

  networking.firewall.enable = true;

  # Run unpatched dynamic binaries on NixOS.
  programs.nix-ld.enable = true;
}
