{ lib, config, sUsers, aiUsers, ... }: {
  users.users =
    lib.genAttrs sUsers (user: {
      home = "/home/${user}";
      extraGroups = [ "wheel" ]; # Enable 'sudo' for the user.
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."shared/${user}_authkey".path;
      linger = true;
    })
    // lib.genAttrs aiUsers (user: {
      home = "/home/${user}";
      isNormalUser = true;
      # 刻意不设：
      #   extraGroups wheel  —— 否则 AI 可 sudo，等于读走 /run/secrets 与 journal
      #   hashedPasswordFile —— 不需要密码登录；进入身份用 `sudo -u <user> -i`
    });
}
