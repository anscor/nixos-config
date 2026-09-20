{ lib, pkgs, sUsers, config, ... }: let
  getUserConfig = user: {
    users.users.${user} = {
      home = "/home/${user}";
      extraGroups = [ "wheel" ]; # Enable 'sudo' for the user.
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."${toString user}_authkey".path;
    };
  };
in
  lib.mergeAttrsList (lib.map getUserConfig sUsers)
