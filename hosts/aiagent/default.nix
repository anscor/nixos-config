{
  modules = [
    ./hardware-configuration.nix
    ./disk.nix

    ({ ... }: {
      networking.hostName = "aiagent";
      system.stateVersion = "26.05";
    })
  ];

  moduleNames = [
    "cli/ai"
    "cli/ai/pi/pi-web-ui.nix"
  ];
}
