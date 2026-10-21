{
  self,
  nixpkgs,
  home-manager,
  sops-nix,
  disko,
  ...
}@inputs: let
  lib = nixpkgs.lib;

  sUsers = [ "anscor" ];

  # AI 专用身份：按主机指定，默认没有。
  # 只有跑 AI 工具的主机通过 specialArgs 打开（见 hosts/aiagent/default.nix），
  # 避免 tencent / wsl 上凭空多出一个用户。
  aiUsers = [ ];

  getCommonModules = system: [
    ./nix-settings.nix
    ./users.nix
    ./sops
    
    ./modules/core

    ./modules/cli/security
    # ./modules/cli/shell
    # ./modules/cli/system/monitor.nix

    sops-nix.nixosModules.sops
  ] ++ lib.attrValues disko.nixosModules ++ [
    home-manager.nixosModules.home-manager

    ./modules/home-manager
    ./modules/home-manager/users.nix
  ];

  mkSystem = builder: {
    system,
    modules ? [],
    specialArgs ? {},
    moduleNames ? [],
    ...
  }@attrs:
  builder {
    inherit system;
    specialArgs = { inherit inputs sUsers aiUsers paseoPackage; } // specialArgs;
    modules =
      (getCommonModules system)
      ++ modules
      ++ lib.map (name: ./modules/${name}) moduleNames;
  } // (removeAttrs attrs [ "system" "modules" "specialArgs" "moduleNames" ]);

  mkNixos = path: mkSystem nixpkgs.lib.nixosSystem ({ system = "x86_64-linux"; } // import path);

  # 单一定义，同时供 packages.paseo（CI 构建）与 services.paseo.package（目标机运行）
  # 使用。两处必须是同一个 derivation，否则目标机不会命中 CI 推入的缓存。
  #
  # 关于 npmDepsHash：
  # v0.12.0 tag 自带的 nix/npm-deps.hash 依然是过期的（与 v0.9.2 / v0.11.1 同一个坑）。
  # 上游在打 tag 后由它自己的 CI 自动修正该值，而那条 workflow 不监听 tag，
  # 所以修复没进 tag。因此仍需用 .override 覆盖。
  #
  # 下面的值来自上游修正提交 9a0b95aa10（“fix: update lockfile signatures and
  # Nix hash”，tag 发布后 2 分钟）：
  #   sha256-ObBdUmNSW+vDjzA7EbCDfZrB0nYDmcWmWe+UCoTMh/M=
  # 已核对 9a0b95aa10 只改了 nix/npm-deps.hash，未动 package-lock.json
  # （该提交与 v0.12.0 tag 的 package-lock.json blob sha 同为 81248c6c，
  # 1523782 字节），故该值适用于 v0.12.0 的源码树。
  # tag 自带的过期值为 sha256-tSE4nb4E…。
  paseoPackage = inputs.paseo.packages."x86_64-linux".default.override {
    npmDepsHash = "sha256-ObBdUmNSW+vDjzA7EbCDfZrB0nYDmcWmWe+UCoTMh/M=";
  };
in {
  # 供 CI 构建（.#paseo）。
  packages = {
    "x86_64-linux" = {
      paseo = paseoPackage;
    };
  };

  nixosConfigurations."tencent"   = mkNixos ./hosts/tencent;
  nixosConfigurations."aiagent"   = mkNixos ./hosts/aiagent;
  nixosConfigurations."wsl"       = mkNixos ./hosts/wsl;
}