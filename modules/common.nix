{ config, lib, pkgs, ... }:

{
  imports = [
    ./sops.nix
    ./go.nix
  ];

  # ===== 系统级 =====
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  services.openssh.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.variables.EDITOR = "vim";

  environment.systemPackages = with pkgs; [
    vim wget git curl sops age ssh-to-age
  ];

  nix.settings = {
    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"   # 交大镜像（快）
      "https://cache.nixos.org"                          # 官方（兜底）
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # ===== 用户级（home-manager）=====
  home-manager.users.anscor = {
    home.stateVersion = "26.05";
    home.packages = with pkgs; [
      which
      tree
    ];
  };
}
