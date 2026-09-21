# xrdp.nix —— mstsc 直连
{ ... }: {
  services.xrdp = {
    enable = true;
    openFirewall = true;
  };
}
