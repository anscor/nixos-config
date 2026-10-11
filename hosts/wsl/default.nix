{
  modules = [
    ({ ... }: {
      networking.hostName = "wsl";
      system.stateVersion = "26.05";

      # nixos-wsl 的 wsl-distro.nix 里写的是 mkDefault false，即 wheel 组免密 sudo。
      # 这里覆盖为 true：WSL 上会执行 AI 提交的配置（求值阶段以调用者身份跑、
      # 不进沙箱），若能免密提权，就等于把通往内网目标机的凭据直接交给 AI。
      security.sudo.wheelNeedsPassword = true;

      # 独立的 /home 盘，与实体机 aiagent（disko 两块盘）思路一致。
      # 差别：WSL 的根盘由 WSL 自己创建并管理（单个 ext4.vhdx，无 GPT、无 /boot），
      # 只有这块 home 盘是我们自建的 VHD —— 由 Windows 侧
      #   wsl --mount E:\WSL\nixos-home.vhdx --vhd --bare
      # 挂成块设备后，在 Linux 里 mkfs.ext4 -L nixos-home 并写进这里。
      #
      # 用 by-label 而非 /dev/sdX：WSL 里额外磁盘的枚举顺序不保证；
      # 用 nofail + 较短的 device-timeout：盘尚未 attach 时不阻断启动。
      fileSystems."/home" = {
        device = "/dev/disk/by-label/nixos-home";
        fsType = "ext4";
        options = [ "defaults" "nofail" "x-systemd.device-timeout=10" ];
      };
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
