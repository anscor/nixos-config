{ aiUsers, lib, ... }: {
  # 只作用于 AI 专用用户（outputs.nix 的 aiUsers，由 hosts/aiagent 开启）。
  # 刻意不用 home-manager.sharedModules —— 否则管理员账号 anscor 家里也会装一套
  # pi 及其凭据文件，隔离就不彻底了。
  home-manager.users = lib.genAttrs aiUsers (_: { pkgs, lib, ... }: {
    programs.pi-coding-agent = {
      enable = true;

      context = ../AGENTS.md;

      extraPackages = [ pkgs.nodejs ];

      settings = {
        defaultProvider = "opencode";
        defaultModel = "big-pickle";

        showHardwareCursor =  true;
        enableInstallTelemetry = false;
        retry = {
          enabled = true;
          maxRetries = 3;
        };
        editorPaddingX = 1;
        theme = "terminal";
        packages = [
          "npm:pi-terminal-theme"
          "npm:pi-zentui"
          "npm:pi-web-access"
          "npm:pi-commandcode-provider"
          "npm:pi-clinepass-provider"
          "npm:@tintinweb/pi-tasks"
          "npm:@tintinweb/pi-subagents"
          "npm:@juicesharp/rpiv-ask-user-question"
          "npm:pi-loop-police"
          "npm:context-mode"
          "git:github.com/obra/superpowers"
        ];
      };
    };

    # 确保 ~/.pi/agent/auth.json 存在；不存在则用默认模板创建，避免敏感凭据进入仓库。
    # 另外：provider-* 包首次运行时会以默认 umask 022 在 ~/.pi/agent/ 下创建
    # provider-keys.json（含 API key），落成 0644；这里连同 auth.json 一起收紧到 0600。
    home.activation.createPiAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ ! -f "$HOME/.pi/agent/auth.json" ]]; then
        $DRY_RUN_CMD mkdir -p "$HOME/.pi/agent"
        $DRY_RUN_CMD install -m 600 /dev/null "$HOME/.pi/agent/auth.json"
        $DRY_RUN_CMD printf '%s' '{"opencode":{"type":"api_key","key":"public"}}' > "$HOME/.pi/agent/auth.json"
        echo "Created $HOME/.pi/agent/auth.json"
      fi

      # 运行时写入的凭据文件，存在就收紧权限
      for f in auth.json provider-keys.json commandcode-models.json models-store.json; do
        if [[ -f "$HOME/.pi/agent/$f" ]]; then
          $DRY_RUN_CMD chmod 600 "$HOME/.pi/agent/$f"
        fi
      done
    '';

    # disable auto format for pi-lens
    home.file.".pi-lens/config.json".text = ''
      {
        "format": {
          "enabled": false
        }
      }
    '';
  });
}
