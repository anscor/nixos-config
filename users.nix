{ lib, config, sUsers, ... }: {
  users.users = lib.genAttrs sUsers (user: {
    home = "/home/${user}";
    extraGroups = [ "wheel" ]; # Enable 'sudo' for the user.
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."${user}_authkey".path;
  });
}
