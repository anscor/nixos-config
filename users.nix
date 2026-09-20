{ lib, pkgs, sUsers, config, ... }: let
  getUserConfig = user: {
    home = "/home/${user}";
    extraGroups = [ "wheel" ]; # Enable 'sudo' for the user.
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."anscor_authkey".path;
  };
in
  lib.mergeAttrsList (lib.map getUserConfig sUsers)
