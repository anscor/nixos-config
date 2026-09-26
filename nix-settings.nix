{ ... }: {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      # "https://mirror.nju.edu.cn/nix-channels/store"
      # "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
      # paseo 自建缓存：由 GitHub Actions 构建并推送
      # （见 .github/workflows/paseo-cache.yml），目标机由此替换而非本地编译。
      # 注意：Cachix 无境内镜像，拉取为直连，首次可能偏慢。
      "https://anscor-nixos-config.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      # 必须与上面的 substituter 主机名前缀逐字一致，否则路径不被信任，
      # 表现为静默不从缓存拉取而回退到本地编译。
      "anscor-nixos-config.cachix.org-1:oCBh5DqQc2l3skBpd0hIUuemvgVLzcA4kvJbA6Iaidw="
    ];
    trusted-users = [ "root" "anscor" ];
  };
  nixpkgs.config.allowUnfree = true;
}
