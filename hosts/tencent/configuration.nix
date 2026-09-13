{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
    ../../modules/desktop.nix
    ../../modules/gui-apps.nix
    ../../modules/xrdp.nix
  ];

  networking.hostName = "tencent";

  system.stateVersion = "26.05";
}
