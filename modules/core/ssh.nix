{
  lib,
  sUsers,
  ...
}: let
  githubClientConfig = ''
    Host github.com
      HostName github.com
      User git
      IdentitiesOnly yes
      # %u = 本地用户名，因此每个用户自动用自己那把 key：
      #   anscor  → /run/secrets/users/anscor/ssh_github
      #   aiagent → /run/secrets/users/aiagent/ssh_github
      # 这样 AI 专用身份不会拿管理员的 key 去推。key 本身是 0400 <user>:users，
      # 别人即使知道路径也读不到。
      IdentityFile /run/secrets/users/%u/ssh_github
  '';
in {
  programs.ssh.knownHosts = {
    "github.com" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  programs.ssh.extraConfig = githubClientConfig;

  services.openssh.settings.PermitRootLogin = "no";

  # 只有管理用户收 authorizedKeys（部署私钥）；AI 专用身份刻意排除在外。
  users.users = lib.genAttrs sUsers (_: {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKxnAwOamDQ2ZFkhIvL1DCz0UnMb0bkZHhRV8sukZnp0"
    ];
  });
}
