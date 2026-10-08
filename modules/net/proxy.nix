{ lib, ... }: {
  # 局域网 HTTP 代理（Clash/mihomo 等，端口 7897 为常见默认值）。
  #
  # 生效范围只到两处，不是「所有进程」：
  #   - 登录会话：networking.proxy.envVars 落到 environment.sessionVariables
  #   - nix-daemon：nixos/modules/services/system/nix-daemon.nix 显式消费
  #     config.networking.proxy.envVars，所以 nix 拉取也会走代理
  # 其余 systemd 系统服务不读 /etc/profile，不会继承这些变量。
  #
  # 代理机不通时 nix 下载会失败（国内镜像仍可直连）——
  # 届时把 hosts/<host>/default.nix 的 moduleNames 里 "net/proxy.nix" 摘掉即可。
  networking.proxy.default = "http://192.168.31.70:7897";

  # 内网与 tailscale 直连，不发往代理。
  # 注意：CIDR 只有 curl ≥7.86、Go 等客户端认；只做域名后缀匹配的程序
  # 会静默忽略这些条目。若某程序按 IP 访问内网，需另外列字面 IP。
  networking.proxy.noProxy = lib.concatStringsSep "," [
    "127.0.0.1"
    "localhost"
    "::1"
    "192.168.0.0/16"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "100.64.0.0/10" # tailscale CGNAT
    ".local"
    ".lan"
    ".internal"
  ];
}
