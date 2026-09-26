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
    specialArgs = { inherit inputs sUsers paseoPackage; } // specialArgs;
    modules =
      (getCommonModules system)
      ++ modules
      ++ lib.map (name: ./modules/${name}) moduleNames;
  } // (removeAttrs attrs [ "system" "modules" "specialArgs" "moduleNames" ]);

  mkNixos = path: mkSystem nixpkgs.lib.nixosSystem ({ system = "x86_64-linux"; } // import path);

  # 单一定义，同时供 packages.paseo（CI 构建）与 services.paseo.package（目标机运行）
  # 使用。两处必须是同一个 derivation，否则目标机不会命中 CI 推入的缓存。
  #
  # 为什么需要 override npmDepsHash：
  # v0.9.2 tag 自带的 hash 是错的。上游在打 tag 之后才由它的 CI 自动修正该值，
  # 而那个 Nix workflow 只监听 main、不监听 tag，因此修复没进 tag。
  # 上游 nix/package.nix 专门为此暴露了 npmDepsHash 参数。
  # 下面的值与上游修正提交 ea7a7418 一致，也与 CI 实际算出的 got 值一致。
  paseoPackage = inputs.paseo.packages."x86_64-linux".default.override {
    npmDepsHash = "sha256-UXnB6q5tubKpTs+A5+u/NLSzc8ZK6rAsQs+kEphEKd8=";
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
}