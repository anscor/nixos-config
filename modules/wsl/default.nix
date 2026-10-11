{ inputs, lib, sUsers, ... }: {
  # NixOS-WSL 平台模块。仅被 hosts/wsl 通过 moduleNames = [ "wsl" ] 选中，
  # 其它主机不会加载（wsl.enable 关闭时该模块几乎全部 config 处于 mkIf 之下）。
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  wsl = {
    enable = true;

    # 登录 WSL 时的默认用户。取自 outputs.nix 的 sUsers，
    # 与 users.nix / ssh.nix 用 lib.head sUsers 取主用户的写法保持一致，
    # 避免用户名在本仓库里出现第二处硬编码。
    defaultUser = lib.head sUsers;
  };
}
