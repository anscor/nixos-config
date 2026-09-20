{ lib, sUsers, ... }: {
  home-manager.users = lib.genAttrs sUsers (user: { ... }: {
    home.username = user;
  });
}
