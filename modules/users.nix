# 用户账户 + 用户级基础配置
{ config, lib, pkgs, ... }:

{
  users.users.anscor = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."anscor_authkey".path;
    home = "/home/anscor";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  home-manager.users.anscor = {
    home.stateVersion = "26.05";

    # 用户级基础工具（功能性的环境见 dev.nix / pi.nix）
    home.packages = with pkgs; [
      which
      tree
    ];
  };
}
