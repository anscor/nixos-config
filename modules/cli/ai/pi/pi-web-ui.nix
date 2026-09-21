{ inputs, lib, config, sUsers, ... }: let
  port = 23366;

  # 与仓库其余模块一致：按 sUsers 逐用户展开（home-manager 会为每个用户各起一份 pi-web-ui）
  templateName = user: "pi-web-ui-${user}.env";
  renderedPath = user: "/run/secrets/rendered/${templateName user}";
in {
  networking.firewall.allowedTCPPorts = [ port ];

  # PI_WEB_TOKEN 必须设置：未设置时 pi-web-ui 对公网完全开放（可读写工作区、可跑 bash）。
  # 放在 sops 而非 Nix 字面量里，避免进入 world-readable 的 /nix/store 与 public 仓库。
  # 声明由 modules/core/secrets.nix 自动生成，详见 sops/secrets/hosts/aiagent/pi_web_token

  # 每个用户一份渲染文件，属主即该用户
  # （sops-install-secrets 的 createParentDirs 用 0751 建 /run/secrets[/rendered]，
  #  others 可穿越目录；文件本身 0400 由 owner 兜底可读性）
  sops.templates = lib.listToAttrs (map (user: {
    name = templateName user;
    value = {
      owner = user;
      mode = "0400";
      content = "PI_WEB_TOKEN=${config.sops.placeholder."hosts/aiagent/pi_web_token"}\n";
    };
  }) sUsers);

  home-manager.sharedModules = [
    inputs.pi-web-ui.homeManagerModules.default
    ({ pkgs, config, ... }: {
      home.packages = [ pkgs.nodejs ];

      services.pi-web-ui = {
        enable = true;
        host = "0.0.0.0";
        inherit port;
        allowOrigins = [
          "https://pi.anscor.top"
          "https://pi.anscor.top:23366"
        ];
      };

      # pi-web-ui 是用户级服务，用追加 section 挂 EnvironmentFile
      # （pi-web-ui 模块自身不暴露 environmentFile 选项）
      systemd.user.services.pi-web-ui.Service.EnvironmentFile =
        renderedPath config.home.username;
    })
  ];
}
