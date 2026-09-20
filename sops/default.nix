{ inputs, pkgs, lib, ... }:
{
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
  sops.age.generateKey = true;
  sops.defaultSopsFile = ./secrets/secrets.yaml;

  # 国内直连 proxy.golang.org 不稳定，改用 goproxy.cn 拉取 Go 依赖
  sops.package = (inputs.sops-nix.packages.${pkgs.stdenv.hostPlatform.system}.sops-install-secrets).overrideAttrs (final: prev: {
    passthru = prev.passthru // {
      overrideModAttrs = lib.composeExtensions prev.passthru.overrideModAttrs (finalMod: prevMod: {
        preBuild = (prevMod.preBuild or "") + ''
          export GOPROXY=https://goproxy.cn,direct
        '';
      });
    };
  });

  sops.secrets."anscor_authkey" = {
    neededForUsers = true;
  };
}
