{
  modules = [
    ({ ... }: {
      networking.hostName = "wsl";
      system.stateVersion = "26.05";

      # nixos-wsl 的 wsl-distro.nix 里写的是 mkDefault false，即 wheel 组免密 sudo。
      # 这里覆盖为 true：WSL 上会执行 AI 提交的配置（求值阶段以调用者身份跑、
      # 不进沙箱），若能免密提权，就等于把通往内网目标机的凭据直接交给 AI。
      security.sudo.wheelNeedsPassword = true;
    })
  ];

  # 注意：刻意不引入 ../utils/vm.nix。
  # 那份配置面向实体机/VM（systemd-boot + EFI + NetworkManager），
  # 而 NixOS-WSL 自己会关闭 initrd/kernel/grub 并覆盖 installBootLoader，
  # 两者同时出现会冲突。WSL 的网络与引导均由 nixos-wsl 模块接管。
  moduleNames = [
    "wsl"
  ];
}
