{
  modules = [
    ./hardware-configuration.nix
    ./utils/vm.nix

    ({ ... }: {
      networking.hostName = "tencent";
      system.stateVersion = "26.05";
    })
  ];

  moduleNames = [
    "gui/linux-desktop/xfce4.nix"
    "gui/linux-desktop/xrdp.nix"
    "gui/tencent.nix"
  ];
}