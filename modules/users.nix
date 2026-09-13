{ config, lib, pkgs, ... }:

{
  users.users.anscor = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."anscor_authkey".path;
    home = "/home/anscor";
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
