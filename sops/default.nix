{ ... }:
{
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
  sops.age.generateKey = true;
  sops.defaultSopsFile = ./secrets/secrets.yaml;

  sops.secrets."anscor_authkey" = {
    neededForUsers = true;
  };
}
