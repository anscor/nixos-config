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
  # 关于 npmDepsHash：
  # v0.9.2 时 tag 自带的 hash 是错的，需要用 .override 覆盖成上游事后修正的值。
  # v0.11.1 先直接用 tag 自带的 nix/npm-deps.hash（即不 override），由 CI 判定。
  #
  # 上游 nix/package.nix 为此保留了 npmDepsHash 参数，形如：
  #   inputs.paseo.packages."x86_64-linux".default.override {
  #     npmDepsHash = "sha256-...";
  #   }
  # 若 CI 报 "hash mismatch in fixed-output derivation"，把报错里的 got 值
  # 按上面的形式填回来即可；注意该文件在 tag 后有被上游 CI 自动修正过
  # （提交信息为 "fix: update lockfile signatures and Nix hash [skip ci]"），
  # 因此 tag 值未必与 package-lock.json 一致。
  paseoPackage = inputs.paseo.packages."x86_64-linux".default;
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