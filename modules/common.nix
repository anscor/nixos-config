# 系统级公共配置（两台机器共享）：启动、网络、区域、nix、SSH、基础包
# 用户级配置见 users.nix / dev.nix / pi.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./sops.nix
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  services.openssh.enable = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "anscor" ]; # 免 sudo 使用 nix，也是远程/分布式构建的前提

    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store" # 交大镜像（快）
      "https://cache.nixos.org" # 官方（兜底）
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # nh：简化 rebuild（nh os switch），每周自动清理旧 generations
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
    };
  };

  environment.variables.EDITOR = "vim";

  environment.systemPackages = with pkgs; [
    vim wget git curl sops age ssh-to-age
  ];
}
