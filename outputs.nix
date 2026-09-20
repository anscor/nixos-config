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
  nixosConfigurations."tencent"   = mkNixos ./hosts/tencent;
  nixosConfigurations."aiagent"   = mkNixos ./hosts/aiagent;
}