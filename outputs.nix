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
    specialArgs = { inherit inputs sUsers; } // specialArgs;
    modules =
      (getCommonModules system)
      ++ modules
      ++ lib.map (name: ./modules/${name}) moduleNames;
  } // (removeAttrs attrs [ "system" "modules" "specialArgs" "moduleNames" ]);

  mkNixos = path: mkSystem nixpkgs.lib.nixosSystem ({ system = "x86_64-linux"; } // import path);
in {
  # 供 CI（.#paseo）与 NixOS 模块指向同一个 derivation。
  # 上游 nixosModules.paseo 内部用 lib.mkDefault 把 services.paseo.package
  # 指向 paseo 自己 flake 的 packages.<system>.default，与此处是同一 derivation，
  # 因此 CI 构建并推入 Cachix 的路径在目标机上必然命中。
  packages = {
    "x86_64-linux" = {
      paseo = inputs.paseo.packages."x86_64-linux".default;
    };
  };

  nixosConfigurations."tencent"   = mkNixos ./hosts/tencent;
  nixosConfigurations."aiagent"   = mkNixos ./hosts/aiagent;
}