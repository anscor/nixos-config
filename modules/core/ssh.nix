{
  config,
  lib,
  sUsers,
  ...
}: let
  sshKeyPath = user: config.sops.secrets."users/${user}/ssh_github".path;

  githubClientConfig = ''
    Host github.com
      HostName github.com
      User git
      IdentityFile ${sshKeyPath (lib.head sUsers)}
      IdentitiesOnly yes
  '';
in {
  programs.ssh.knownHosts = {
    "github.com" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  programs.ssh.extraConfig = githubClientConfig;

  services.openssh.settings.PermitRootLogin = "no";

  users.users = lib.genAttrs sUsers (_: {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKxnAwOamDQ2ZFkhIvL1DCz0UnMb0bkZHhRV8sukZnp0"
    ];
  });
}
