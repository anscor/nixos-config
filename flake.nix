{
  description = "Anscor's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, sops-nix, disko, ... }:
  let
    system = "x86_64-linux";
    hm = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    };
  in {
    nixosConfigurations = {
      tencent = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          sops-nix.nixosModules.sops

          ./hosts/tencent/configuration.nix

          home-manager.nixosModules.home-manager
          hm
        ];
      };

      aiagent = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./hosts/aiagent/configuration.nix
          home-manager.nixosModules.home-manager
          hm
        ];
      };
    };
  };
}
