{
  modules = [
    ./hardware-configuration.nix
    ./disk.nix
    ../utils/vm.nix

    ({ ... }: {
      networking.hostName = "aiagent";
      system.stateVersion = "26.05";
    })
  ];

  moduleNames = [
    "cli/ai"
    "cli/ai/paseo.nix"
    "net/proxy.nix"
  ];

  # 这台主机是 AI 运行地：创建专用 AI 用户（不进 wheel、无密码、无 authorizedKeys，
  # 也读不到 journal）。其它主机不开，避免 tencent / wsl 上凭空多出该用户。
  specialArgs = { aiUsers = [ "aiagent" ]; };
}
