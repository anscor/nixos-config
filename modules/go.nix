{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      sops-install-secrets = prev.sops-install-secrets.overrideAttrs (old: {
        GOPROXY = "https://goproxy.cn,direct";
        GOSUMDB = "off";
      });
    })
  ];
}
