{ ... }: {
  home-manager.sharedModules = [
    ({ pkgs, lib, ... }: {
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
            "npm:@tintinweb/pi-tasks"
            "npm:@tintinweb/pi-subagents"
            "npm:@juicesharp/rpiv-ask-user-question"
            "npm:pi-loop-police"
            "npm:context-mode"
            "git:github.com/obra/superpowers"
          ];
        };
      };

      # 确保 ~/.pi/agent/auth.json 存在；不存在则用默认模板创建，避免敏感凭据进入仓库
      home.activation.createPiAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [[ ! -f "$HOME/.pi/agent/auth.json" ]]; then
          $DRY_RUN_CMD mkdir -p "$HOME/.pi/agent"
          $DRY_RUN_CMD install -m 600 /dev/null "$HOME/.pi/agent/auth.json"
          $DRY_RUN_CMD printf '%s' '{"opencode":{"type":"api_key","key":"public"}}' > "$HOME/.pi/agent/auth.json"
          echo "Created $HOME/.pi/agent/auth.json"
        fi
      '';

      # disable auto format for pi-lens
      home.file.".pi-lens/config.json".text = ''
        {
          "format": {
            "enabled": false
          }
        }
      '';
    })
  ];
}
