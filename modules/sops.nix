{ config, lib, pkgs, ... }:

{
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
  sops.age.generateKey = true;
  sops.defaultSopsFile = ../secrets/secrets.yaml;

  # 按需声明，名字必须和 secrets.yaml 里的 key 一致
  sops.secrets."anscor_authkey" = {
    neededForUsers = true;
  };
}
