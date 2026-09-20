{ ... }: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [
      {
        # You can update Home Manager without changing this value. See
        # the Home Manager release notes for a list of state version
        # changes in each release.
        home.stateVersion = "26.05";

        # Let Home Manager install and manage itself.
        programs.home-manager.enable = true;
      }
    ];
  };
}
