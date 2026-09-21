{
  lib,
  config,
  sUsers,
  ...
}: let
  # sops/secrets/ 下的分层结构由本模块自动发现，无需逐个声明：
  #   shared/<name>            → 所有机器都能解
  #   hosts/<hostname>/<name>  → 只有该主机能解
  #   users/<user>/<name>      → 属主为该用户
  # 新增 secret 只需放好文件 + git add + 加密，Nix 侧零改动。
  root = ../../sops/secrets;
  host = config.networking.hostName;

  # 递归枚举，返回相对路径列表
  walk = dir: prefix:
    let
      entries = builtins.readDir dir;
    in
      lib.concatMap (
        name: let
          path = dir + "/${name}";
        in
          if entries.${name} == "directory"
          then walk path "${prefix}${name}/"
          else ["${prefix}${name}"]
      ) (builtins.attrNames entries);

  # 只接管本机相关的 secret：
  #   hosts/<其它主机>/ → 本机没有对应私钥，声明了会解密失败
  #   users/<其它用户>/ → 本机不存在该用户
  belongsHere = p:
    !(lib.hasPrefix "hosts/" p && !lib.hasPrefix "hosts/${host}/" p)
    && !(lib.hasPrefix "users/" p
      && !builtins.elem (lib.elemAt (lib.splitString "/" p) 1) sUsers);

  isLayered = p:
    lib.hasPrefix "shared/" p
    || lib.hasPrefix "hosts/" p
    || lib.hasPrefix "users/" p;

  mkSecret = p: let
    parts = lib.splitString "/" p;
    isAuthkey = lib.hasSuffix "_authkey" p;
  in {
    # 属性名保留层级，落到 /run/secrets/<相同相对路径>
    name = p;
    value = {
      # 私钥/证书等多行文件按整体加密，不做键值解析
      format = "binary";
      sopsFile = root + "/${p}";
      mode = "0400";
      # users/<user>/… 归该用户；shared/ 与 hosts/ 归 root
      owner =
        if lib.hasPrefix "users/" p
        then lib.elemAt parts 1
        else null;
      # 密码哈希必须在创建用户之前解密
      neededForUsers = isAuthkey;
      # 密码哈希的 PAM 路径保持扁平，不随目录分层漂移
      path = lib.mkIf isAuthkey "/run/secrets-for-users/${lib.removePrefix "shared/" p}";
    };
  };
in {
  sops.secrets = lib.listToAttrs (
    map mkSecret (builtins.filter (p: isLayered p && belongsHere p) (walk root ""))
  );
}
