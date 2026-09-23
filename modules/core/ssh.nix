{
  config,
  lib,
  sUsers,
  ...
}: let
  # 私钥由 sops 落地到 /run/secrets，不进 ~/.ssh
  # （sops 会 chown secret 的父目录，交给它管 ~/.ssh 会破坏该目录）
  sshKeyPath = user: config.sops.secrets."users/${user}/ssh_github".path;

  # 系统级 extraConfig 对所有用户生效，root 复用主用户的那份 key
  githubClientConfig = ''
    Host github.com
      HostName github.com
      User git
      IdentityFile ${sshKeyPath (lib.head sUsers)}
      IdentitiesOnly yes
  '';
in {
  # GitHub host key 属系统级配置（home-manager 已不提供 programs.ssh.knownHosts）
  programs.ssh.knownHosts = {
    "github.com" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  programs.ssh.extraConfig = githubClientConfig;

  # 禁止 root 从 ssh 登录；root 需要远程操作时走普通用户 + sudo
  # （默认值是 prohibit-password，仍允许公钥直接登 root）
  services.openssh.settings.PermitRootLogin = "no";

  users.users = lib.genAttrs sUsers (_: {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEP4wRaJpuEFdmT6+/SpNjrBuqEbKTq9GkfoyttO1oHl anscor@AnscorPC"
    ];
  });
}
