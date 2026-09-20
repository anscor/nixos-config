{ pkgs, ... }: {
  home-manager.sharedModules = [
    ({ ... }: {
      programs.direnv = {
        enable = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;

        nix-direnv.enable = true;
      };

      # programs.starship = {
      #   enable = true;
      #   enableFishIntegration = true;
      #   enableNushellIntegration = true;

      #   presets = [
      #     "nerd-font-symbols"
      #   ];
      # };
    })
  ];
}
