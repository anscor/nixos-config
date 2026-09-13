{ config, lib, pkgs, ... }:

{
  # ===== 系统级 =====
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.displayManager.lightdm.greeters.gtk.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "anscor";
  services.displayManager.defaultSession = "xfce";

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-rime rime-data ];
  };

  environment.variables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
  };

  # ===== 用户级（个人桌面工具，按需加）=====
  # home-manager.users.anscor = {
  #   home.packages = with pkgs; [ ];
  # };
}

