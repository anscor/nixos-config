{
  inputs,
  pkgs,
  lib,
  ...
}: {
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
  # 缺失即明确失败：与「每机一把密钥」配套，绝不静默生成新钥
  # （静默生成会让秘密解不开，却看起来部署成功）
  sops.age.generateKey = false;
  # 不把 sshd host key 当作 age identity
  sops.age.sshKeyPaths = [ ];

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
}
