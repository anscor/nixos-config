# xrdp.nix —— mstsc 直连（快捷键留本机）+ 剪贴板图片自动转 PNG 落地
{ config, pkgs, lib, ... }:

let
  # 只读监听剪贴板：发现 image/bmp（xrdp 传来的图片格式）就转成 PNG
  # 存到 ~/clip/ 并弹通知。全程不接管剪贴板所有权，文字同步零影响。
  clipboard-image-drop = pkgs.writeShellScriptBin "clipboard-image-drop" ''
    export PATH="${pkgs.xclip}/bin:${pkgs.imagemagick}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:${pkgs.libnotify}/bin:$PATH"
    dir="$HOME/clip"
    mkdir -p "$dir"
    last=""
    while true; do
      targets=$(xclip -selection clipboard -o -t TARGETS 2>/dev/null || true)
      if printf '%s\n' "$targets" | grep -q '^image/bmp$'; then
        sha=$(xclip -selection clipboard -o -t image/bmp 2>/dev/null | sha256sum | cut -d' ' -f1)
        if [ -n "$sha" ] && [ "$sha" != "$last" ]; then
          out="$dir/$(date +%Y%m%d-%H%M%S).png"
          if xclip -selection clipboard -o -t image/bmp 2>/dev/null \
            | magick bmp:- png:"$out" && [ -s "$out" ]; then
            last="$sha"
            notify-send "剪贴板图片已保存" "$out" -i "$out" 2>/dev/null || true
          fi
        fi
      fi
      sleep 1
    done
  '';
in
{
  # ===== xrdp：Windows mstsc 直连（LAN 3389）=====
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "xfce4-session";
  services.xrdp.openFirewall = true;

  # ===== 剪贴板图片落地工具（每个图形会话自启一个，只读，互不干扰）=====
  environment.systemPackages = [ clipboard-image-drop ];
  environment.etc."xdg/autostart/clipboard-image-drop.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Clipboard image drop
    Exec=${clipboard-image-drop}/bin/clipboard-image-drop
    NoDisplay=true
  '';
}
