{
  config,
  ...
}: let
  # sops.secrets 只能在 NixOS 作用域求值；home-manager 内的 config 访问不到它
  sshKeyPath = user: config.sops.secrets."users/${user}/ssh_github".path;
in {
  # GitHub host key 属系统级配置（home-manager 已不提供 programs.ssh.knownHosts）
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  home-manager.sharedModules = [
    ({ config, ... }: {
      programs.ssh = {
        enable = true;
        # 显式关闭，避免依赖即将废弃的默认配置注入
        enableDefaultConfig = false;

        settings = {
          "github.com" = {
            HostName = "github.com";
            User = "git";
            # 私钥由 sops 落地到 /run/secrets，不放进 ~/.ssh
            # （sops 会 chown secret 的父目录，交给它管 ~/.ssh 会破坏该目录）
            IdentityFile = sshKeyPath config.home.username;
            IdentitiesOnly = true;
          };

          # 保持 ssh 常规默认行为（等价于旧的 enableDefaultConfig = true）
          "*" = {
            ForwardAgent = false;
            AddKeysToAgent = "no";
            Compression = false;
            ServerAliveInterval = 0;
            ServerAliveCountMax = 3;
            HashKnownHosts = false;
            UserKnownHostsFile = "~/.ssh/known_hosts";
            ControlMaster = "no";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "no";
          };
        };
      };
    })
  ];
}
