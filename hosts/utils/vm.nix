{ lib, modulesPath, ... }:
{
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";
  
  services.openssh.enable = true;
  
  services.printing.enable = false; # 禁用打印支持
  hardware.bluetooth.enable = false; # 禁用蓝牙支持

  system.stateVersion = "26.05";
}