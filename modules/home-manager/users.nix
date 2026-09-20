{ lib, sLib, sUsers, ... }: let
  getUserConfig = user: {
    home-manager.users.${user} = { ... }: {
      home.username = user;
    };
  };
in
  lib.mergeAttrsList (lib.map getUserConfig sUsers)
