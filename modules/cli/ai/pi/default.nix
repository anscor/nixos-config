{ aiUsers, lib, ... }: {
  # 只作用于 AI 专用用户（outputs.nix 的 aiUsers，由 hosts/aiagent 开启）。
  # 刻意不用 home-manager.sharedModules —— 否则管理员账号 anscor 家里也会装一套
  # pi 及其凭据文件，隔离就不彻底了。
  home-manager.users = lib.genAttrs aiUsers (_: { pkgs, lib, ... }: let
    jsonFormat = pkgs.formats.json { };

    # Trilium 内置 MCP（TriliumNext ≥ 0.103，仅 HTTP transport + Bearer ETAPI token）。
    # 上游 home-manager 模块没有 mcpServers 选项，故直接生成 ~/.pi/agent/mcp.json。
    #
    # Authorization 用 pi 的 `!命令` 形式在连接时读取 sops 落地的 token 文件，
    # 而不是用 sessionVariables 导出环境变量 —— 后者会让每个 shell 的进程环境
    # 里都带明文 token（paseo spawn 的子进程亦然）。
    #
    # exposure = deferred：system prompt 的 mcp_servers 段只列一行 description，
    # 模型知道它存在，需要时用 tool_search 载入后直接调用，不占常驻 context。
    triliumMcp = {
      mcpServers.trilium = {
        url = "http://192.168.31.65:23632/mcp";
        headers.Authorization = "!printf 'Bearer %s' \"$(cat /run/secrets/users/aiagent/trilium_etapi_token)\"";
        exposure = "deferred";
        description = "Trilium 个人知识库：搜索、阅读、创建、整理笔记。适合调研取证、资料归档、方案整理，不限于编码任务。";
      };
    };
  in {
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

    # Trilium MCP（内容见上方 triliumMcp）。home.file 落地的是只读符号链接，
    # 因此在 /mcp 里改 exposure/enabled 会写失败 —— 与 ~/.pi-lens/config.json
    # 同样的声明式取舍：改配置请改本文件，不要在 TUI 里改。
    home.file.".pi/agent/mcp.json".source =
      jsonFormat.generate "pi-coding-agent-mcp.json" triliumMcp;

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
