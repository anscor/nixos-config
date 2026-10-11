{ aiUsers, lib, ... }: {
  # 同 pi：只给 AI 专用用户装，管理员账号不装。
  home-manager.users = lib.genAttrs aiUsers (_: { ... }: {
    programs.opencode = {
      enable = true;
      context = ./AGENTS.md;
    };
  });
}
