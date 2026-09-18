# pi 编码 agent（https://github.com/earendil-works/pi，nixpkgs 收录，提供 pi 命令）
{ config, lib, pkgs, ... }:

{
  home-manager.users.anscor.home.packages = with pkgs; [
    pi-coding-agent
  ];
}
