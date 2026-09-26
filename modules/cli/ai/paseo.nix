{ inputs, paseoPackage, ... }: {
  imports = [ inputs.paseo.nixosModules.paseo ];

  services.paseo = {
    enable = true;

    # 指向 outputs.nix 中定义的那个 derivation（与 CI 构建的 .#paseo 同一个）。
    # 上游模块用 mkPackageOption（默认值 pkgs.paseo），flake 层用 mkDefault
    # 覆盖为上游包；这里再显式覆盖为带修正 npmDepsHash 的版本，
    # 否则目标机会走与 CI 不同的 derivation，导致缓存不命中而本地编译。
    package = paseoPackage;

    # 以 anscor 身份运行：agent 进程需要访问该用户的 profile（pi / opencode / git）。
    # group 必须一起改，否则模块会额外创建一个无用的 paseo 组。
    user = "anscor";
    group = "users";

    # 绑 0.0.0.0 且仅 IPv4：
    # 上游 bootstrap.ts 的 parseListenString() 把 "0.0.0.0:6767" 解析为
    # { type = "tcp"; host = "0.0.0.0"; port = 6767; }，随后显式调用
    # httpServer.listen(port, host)。Node 在显式传入 host 时只绑 IPv4，
    # 只有省略 host 参数时才双栈。因此 ens18 上的公网 IPv6 地址没有监听者。
    listenAddress = "0.0.0.0";
    port = 6767;

    # 不使用模块的全局开洞，改由本文件显式声明，便于与模块实现解耦
    openFirewall = false;

    # 锁 1：ExecStart 追加 --no-relay（CLI 层优先级最高）
    relay.enable = false;

    environment = {
      # 锁 2：环境变量层再钉一次，防止 config.json 被改后 relay 复活。
      # （上游 relay 默认值为开，且兼容期延续至 2027-01-31，见 config.ts:300）
      PASEO_RELAY_ENABLED = "false";

      # 上游默认 false，必须显式开启才有自托管 Web UI
      PASEO_WEB_UI_ENABLED = "true";

      # 刻意不设置以下项 —— 以 IP 访问时上游默认放行，无需配置：
      #   PASEO_HOSTNAMES        Host 头是纯 IP，hostnames.ts 中 net.isIP() 直接放行
      #   PASEO_TRUSTED_PROXIES  链路无反向代理，X-Forwarded-Proto 不参与
      #   PASEO_CORS_ORIGINS     无跨源访问
      #   PASEO_PASSWORD         决策：内网暂不设。注意上游语义是无密码即无条件放行
      #                          （auth.ts 中 isBearerTokenValid 在 password 为空时 return true）
    };

    settings = {
      version = 1;

      daemon = {
        # 锁 3：落盘可见，防手改
        relay.enabled = false;
        mcp = {
          enabled = true;
          injectIntoAgents = false;
        };
      };

      features.webUi.enabled = true;
      log.level = "info";
    };
  };

  networking.firewall.allowedTCPPorts = [ 6767 ];
}
