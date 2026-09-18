# 开发环境：direnv + nix-direnv 按项目加载（参考 nixos-and-flakes 多层结构）
# 语言环境全在项目层，全局只留日常工具：
#   - go/node：项目 flake.nix 的 devShell 声明，进目录自动有
#   - python：项目里 uv python pin + uv sync，解释器由 uv 缓存在
#     ~/.local/share/uv 全机按版本去重共享，.venv 落在项目内
{ config, lib, pkgs, ... }:

{
  home-manager.users.anscor = {
    # 全局：日常工具 + uv（python 项目引导器，~50MB）
    home.packages = with pkgs; [
      tmux fzf ripgrep fd jq btop unzip
      uv
    ];

    home.sessionVariables = {
      # uv 下载托管解释器走国内镜像（python-build-standalone）
      UV_PYTHON_INSTALL_MIRROR = "https://registry.npmmirror.com/-/binary/python-build-standalone";
    };

    # npm/pnpm 运行时装包走 npmmirror（agent 在项目里 npm install 时的流量大头）
    home.file.".npmrc".text = ''
      registry=https://registry.npmmirror.com
    '';

    # 进入含 .envrc 的目录自动激活该项目的 devShell
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true; # 缓存 devShell 激活结果，cd 进去不卡
    };

    # direnv 的 hook 要写进 shell 配置，这里让 HM 接管 bashrc
    # （机器上原有的 ~/.bashrc 会被 HM 管理，旧文件自动备份为 .backup）
    programs.bash.enable = true;
  };
}
