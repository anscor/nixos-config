{ ... }: {
  home-manager.sharedModules = [
    ({ ... }: {
      programs.git = {
        enable = true;

        settings = {
          user = {
            email = "xlyanscor@outlook.com";
            name = "anscor";
          };

          credential = {
            helper = "cache --timeout 3600";
          };
        };
      };

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
      };
    })
  ];
}
