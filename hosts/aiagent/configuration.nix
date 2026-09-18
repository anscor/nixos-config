{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ../../modules/common.nix
    ../../modules/users.nix
    ../../modules/dev.nix
    ../../modules/pi.nix
  ];

  networking.hostName = "aiagent";

  # nix 自身流量（flake inputs 的 github、二进制缓存）走局域网代理
  # 代理机器关机时 nix 下载会失败，届时注释掉这行即可（国内镜像仍可直连）
  nix.settings.proxy = "http://192.168.31.70:7897";

  system.stateVersion = "26.05";
}
