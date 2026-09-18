# sops-nix 机密管理：运行时配置 + 构建修复
{ config, lib, pkgs, ... }:

{
  # 构建期：sops-install-secrets 编译需拉 Go 模块，走国内代理
  nixpkgs.overlays = [
    (final: prev: {
      sops-install-secrets = prev.sops-install-secrets.overrideAttrs (old: {
        GOPROXY = "https://goproxy.cn,direct";
        GOSUMDB = "off";
      });
    })
  ];

  # 运行时
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
  sops.age.generateKey = true;
  sops.defaultSopsFile = ../secrets/secrets.yaml;

  # 按需声明，名字必须和 secrets.yaml 里的 key 一致
  sops.secrets."anscor_authkey" = {
    neededForUsers = true;
  };
}
