{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ../../modules/common.nix
    ../../modules/users.nix
  ];

  networking.hostName = "aiagent";

  system.stateVersion = "26.05";
}
