{ ... }: {
  home-manager.sharedModules = [
    ({ ... }: {
      programs.opencode = {
        enable = true;
        context = ./AGENTS.md;
      };
    })
  ];
}
