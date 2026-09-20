{ ... }: {
  networking.firewall.enable = true;

  # Run unpatched dynamic binaries on NixOS.
  programs.nix-ld.enable = true;

  i18n.defaultLocale = "zh_CN.UTF-8";
  
  time.timeZone = "Asia/Shanghai";
}
