{ config, lib, pkgs, sUsers, ... }:

let
  appimage = pkgs.fetchurl {
    url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
    hash = "sha256-ay4g5wAGNy6N37rkDqhkVkUgyHsH0BYLYA7JP3j9XMI=";
  };
  contents = pkgs.appimageTools.extract {
    pname = "wechat";
    version = "4.1.1.8";
    src = appimage;
  };
  wechat = pkgs.appimageTools.wrapAppImage {
    pname = "wechat";
    version = "4.1.1.8";
    meta = pkgs.wechat.meta;
    src = contents;
    extraInstallCommands = ''
      mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
      cp ${contents}/wechat.desktop $out/share/applications/
      cp ${contents}/wechat.png $out/share/icons/hicolor/256x256/apps/
      substituteInPlace $out/share/applications/wechat.desktop --replace-fail AppRun wechat
    '';
  };
  qq = pkgs.qq.overrideAttrs (old: {
    version = "3.2.32-2026-08-12";
    src = pkgs.fetchurl {
      url = "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/3f89efc5/QQ_3.2.32_260812_amd64_01.deb";
      hash = "sha256-0IXdiTlyJQYeufGUMI9ogSmBjtRFd36XpKChbhPXsOg=";
    };
  });
in
{
  home-manager.users = lib.genAttrs sUsers (user: {
    home.packages = [
      qq
      wechat
    ];
  });
}
