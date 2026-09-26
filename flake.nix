{
  description = "Anscor's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
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

    pi-web-ui = {
      url = "github:Sion10032/pi-web-ui-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # paseo：自托管 AI coding agent 总控台。
    # 刻意不写 inputs.nixpkgs.follows —— 上游 nix/package.nix 的 npmDepsHash
    # 是按它自身锁定的 nixpkgs rev 算出来的，跟随本仓库的 nixpkgs 可能导致
    # hash 不匹配，从而在目标机上触发本地重建，使缓存方案失效。
    paseo = {
      url = "github:getpaseo/paseo/v0.9.2";
    };
  };
  
  outputs = inputs: import ./outputs.nix inputs;
}
