{ lib, sUsers, aiUsers, ... }: {
  home-manager.users = lib.genAttrs (sUsers ++ aiUsers) (user: { ... }: {
    home.username = user;
  });
}
