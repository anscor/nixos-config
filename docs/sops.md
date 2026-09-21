# sops 密钥管理

本仓库用 [sops-nix](https://github.com/Mic92/sops-nix) + age 管理所有私密内容（密码哈希、
API token、SSH 私钥等）。加密文件可以安全地进 git（本仓库是 public）。

## 设计要点

| 项目 | 说明 |
|---|---|
| 加密工具 | sops + age |
| 收件人 | 每台机器一把 age 私钥，位于 `/var/lib/sops-nix/keys.txt`（root 0400） |
| 解密时机 | `nixos-rebuild switch` 的 activation 阶段，由 root 执行 |
| 落地位置 | `/run/secrets/<相对路径>`，用户级 secret 的 `owner` 为该用户 |
| 密码哈希 | 走 `/run/secrets-for-users/`，在创建用户之前解密 |
| 自动发现 | `modules/core/secrets.nix` 递归扫描 `sops/secrets/`，新增秘密**无需改 Nix** |

### 目录分层（按收件人划分，不是按内容类型）

```
sops/
├── .sops.yaml                             # creation_rules：按路径决定收件人
└── secrets/
    ├── shared/<name>                      # 所有机器都能解（如 anscor_authkey）
    ├── hosts/<hostname>/<name>            # 只有该主机能解（如 pi_web_token）
    └── users/<user>/<name>                # 属主为该用户（如 ssh_github）
```

落到运行时的路径与上面保持一致：

| 加密文件 | 落地路径 | owner |
|---|---|---|
| `secrets/shared/anscor_authkey` | `/run/secrets-for-users/anscor_authkey` | root |
| `secrets/hosts/aiagent/pi_web_token` | `/run/secrets/hosts/aiagent/pi_web_token` | root |
| `secrets/users/anscor/ssh_github` | `/run/secrets/users/anscor/ssh_github` | anscor |

> `*_authkey` 结尾的文件会被特殊处理：`neededForUsers = true`，并且 PAM 路径拍平为
> `/run/secrets-for-users/<去掉 shared/ 的名字>`，避免随目录分层漂移。

### 现状

```
sops/secrets/shared/anscor_authkey            2 收件人（tencent + aiagent）
sops/secrets/hosts/aiagent/pi_web_token       1 收件人（仅 aiagent）
sops/secrets/users/anscor/ssh_github          2 收件人（tencent + aiagent）
```

---

## ⚠️ 三个必须记住的坑

1. **新增文件必须 `git add`**
   flake 只能看到被 git 跟踪的文件。未跟踪时报错：
   ```
   error: Path 'xxx' is not in the repository ... To make it visible to Nix, run: git add "xxx"
   ```

2. **必须在 `sops/` 目录下运行 sops（或加 `--config`）**
   sops 从**当前工作目录**向上查找 `.sops.yaml`，不看目标文件在哪。
   ```
   ✗ cd 仓库根 && sops -e -i sops/secrets/shared/foo    # 找不到 config
   ✓ cd sops   && sops -e -i secrets/shared/foo
   ✓ cd 仓库根 && sops --config sops/.sops.yaml -e -i sops/secrets/shared/foo
   ```

3. **别让 sops 管 `~/.ssh` 下的文件**
   sops-nix 会 `chown` secret 的每一级父目录为 `root:keys 0751`。若把私钥
   `path` 设成 `/home/anscor/.ssh/id_ed25519`，`~/.ssh` 会变成 root 所有，之后
   `known_hosts`、`config` 都写不进去。
   → 正确做法：私钥留在 `/run/secrets/`，用 `identityFile` 指过去（见 ssh 部分）。

---

## 操作手册

所有命令默认从仓库根开始，除非注明 `cd sops`。

### 前置：让 sops 能读到 age 私钥

管理员的日常操作（加/改秘密）需要 age 私钥才能解密已有文件：

```bash
# 本机 age 私钥是 root 0400，用 sudo 读
export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt
# 或每次都写全：
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops ...
```

> 若你本地另有一份该密钥副本（如从 Bitwarden 恢复），可省掉 sudo：
> `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`

---

### 1. 新增一个 secret（最常用）

**加新机器专属的秘密**（只有某台机器能解）：

```bash
cd sops
mkdir -p secrets/hosts/aiagent

# 放入明文内容（多行文件如私钥、证书都可以）
cp ~/some-private-key secrets/hosts/aiagent/my_secret

# 原地加密（按路径自动选收件人，无需 --input-type）
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops -e -i secrets/hosts/aiagent/my_secret

# 修属主（sudo 跑 sops 后文件可能变 root）
sudo chown -R anscor:users secrets

cd ..
git add sops/secrets/hosts/aiagent/my_secret    # 必须
```

**加共享的秘密**（所有机器能解）：把路径换成 `secrets/shared/<name>`。
**加用户级秘密**（属主为该用户）：路径换成 `secrets/users/<user>/<name>`。

**Nix 侧不需要任何改动** —— `modules/core/secrets.nix` 会自动发现。

验证：

```bash
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt \
  sops -d sops/secrets/hosts/aiagent/my_secret     # 能解出内容
grep -o 'age1[a-z0-9]\{40,\}' sops/secrets/hosts/aiagent/my_secret | sort -u | wc -l
# 期望：1（hosts/aiagent/ 规则只有一个收件人）
```

### 2. 在多行秘密中写入敏感值

`format = "binary"` 的文件**没有键**，整体就是一个值。要写多行内容（如 SSH 私钥）：

```bash
cd sops
# 直接编辑会打开 $EDITOR，内容为明文
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops secrets/users/anscor/ssh_github
```

### 3. 修改已有 secret

```bash
cd sops
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops secrets/shared/anscor_authkey
# 编辑器里改完保存，sops 自动重新加密
```

生成新的密码哈希：

```bash
# mkpasswd 由 nixpkgs 的 mkpasswd 提供（已在 environment.corePackages 里）
# 会交互式提示输入密码
mkpasswd -m sha-512
# 输出形如 $6$xxx$yyy...，把整串贴进 sops 编辑器
```

### 4. 查看某个 secret 的内容

```bash
cd sops
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops -d secrets/shared/anscor_authkey
```

> `--extract '["key"]'` 只对**有键的 yaml/json** 文件有效；
> 本仓库的 secret 都是 `binary` 格式，直接 `sops -d` 即可。

### 5. 新增一台机器

```bash
# ① 在新机器上生成 age 密钥（/var/lib/sops-nix 是 root 所有，需 sudo）
sudo age-keygen -o /var/lib/sops-nix/keys.txt
sudo chmod 600 /var/lib/sops-nix/keys.txt
sudo grep 'public key' /var/lib/sops-nix/keys.txt   # 记下 age1... 公钥

# 该文件是唯一不可恢复的秘密，务必备份到 Bitwarden
sudo cat /var/lib/sops-nix/keys.txt
```

```bash
# ② 在【能解密目标文件的现有机器】上，把新公钥加入 .sops.yaml
cd /home/anscor/nixos-config/sops
$EDITOR .sops.yaml
#   在 keys: 段加一行：  - &newhost age1xxx...
#   在对应的 creation_rules 的 age 列表里加 *newhost
```

```bash
# ③ 给所有已有文件补上新收件人（需要能解密它们）
cd /home/anscor/nixos-config/sops
find secrets -type f -exec \
  sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops updatekeys -y {} \;
```

```bash
# ④ 提交
cd /home/anscor/nixos-config
git add sops/.sops.yaml sops/secrets
git commit -m "新增 <hostname> 的 age 收件人"
```

> **`updatekeys` 的前提**：执行它的机器必须能解密目标文件。所以给新机器授权，
> 必须由一台既持有旧私钥、又能读到目标文件的机器来做。

### 6. 新增一个用户

带 `*_authkey` 后缀的密码哈希文件必须放 `secrets/shared/` 下（因为每台机器都要创建该用户，
且 `users.nix` 读取的是 `shared/<user>_authkey`）：

```bash
# ① 生成密码哈希（会交互式提示输入密码）
mkpasswd -m sha-512

# ② 写入（注意：无尾随换行，与 binary 格式要求一致）
cd sops
printf '%s' '<上面生成的 $6$... 哈希>' | sudo tee secrets/shared/<user>_authkey >/dev/null
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt \
  sops -e -i secrets/shared/<user>_authkey
sudo chown anscor:users secrets/shared/<user>_authkey
cd .. && git add sops/secrets/shared/<user>_authkey
```

> 新增用户还需在 `outputs.nix` 的 `sUsers` 里加上该用户名（它会自动获得用户账号、
> home-manager 配置和 sops 的逐用户展开）。

### 7. 部署与验证

```bash
# 语法检查（两台机器都会 eval）
nix flake check --no-build

# 部署
sudo nixos-rebuild switch --flake .#aiagent
```

部署时 sops 会打印它做了什么：

```
adding secret: shared/anscor_authkey
removing secret: anscor_authkey
adding rendered secret: pi-web-ui-anscor.env
```

部署后验证：

```bash
# secret 是否落地、属主是否正确
sudo ls -l /run/secrets-for-users/anscor_authkey     # -r-------- root root
ls -l /run/secrets/users/anscor/ssh_github           # -r-------- anscor users

# 密码是否仍然有效（P=有效, L=锁定）
sudo passwd -S anscor

# 用户级服务是否读到 env
systemctl --user status pi-web-ui --no-pager | head -5
```

### 8. 迁移旧的单文件 secrets.yaml

旧结构把所有秘密放在 `sops/secrets/secrets.yaml`（yaml，多键）。迁移到分层结构：

```bash
cd /home/anscor/nixos-config/sops
export K=/var/lib/sops-nix/keys.txt
OLD=secrets/secrets.yaml

mkdir -p secrets/shared secrets/hosts/aiagent

# 用重定向写入（不要用 $(...) 包裹，会丢末尾换行；binary 格式要求字节精确）
sudo SOPS_AGE_KEY_FILE=$K sops -d --extract '["anscor_authkey"]' "$OLD" \
  | sudo tee secrets/shared/anscor_authkey >/dev/null
sudo SOPS_AGE_KEY_FILE=$K sops -d --extract '["pi_web_token"]' "$OLD" \
  | sudo tee secrets/hosts/aiagent/pi_web_token >/dev/null

# 加密
sudo SOPS_AGE_KEY_FILE=$K sops -e -i secrets/shared/anscor_authkey
sudo SOPS_AGE_KEY_FILE=$K sops -e -i secrets/hosts/aiagent/pi_web_token
sudo chown -R anscor:users secrets

# 往返校验（密码哈希错一个字节就无法登录）
for pair in "anscor_authkey:secrets/shared/anscor_authkey" \
            "pi_web_token:secrets/hosts/aiagent/pi_web_token"; do
  key="${pair%%:*}"; f="${pair#*:}"
  a=$(sudo SOPS_AGE_KEY_FILE=$K sops -d --extract "[\"$key\"]" "$OLD")
  b=$(sudo SOPS_AGE_KEY_FILE=$K sops -d "$f")
  [ "$a" = "$b" ] && echo "  ✓ $key" || echo "  ✗ $key 不一致！"
done

# 确认无误后删除旧文件
sudo rm "$OLD"
cd .. && git add -A sops/secrets
```

---

## 附：SSH 私钥的托管方式

GitHub 用的 SSH 私钥也纳入 sops 管理，落地路径**不是** `~/.ssh`（见坑 #3）：

```
sops/secrets/users/anscor/ssh_github          加密存储
        ↓ nixos-rebuild 解密，owner=anscor 0400
/run/secrets/users/anscor/ssh_github
        ↓ modules/core/ssh.nix 里 identityFile 指向它
git push / pull → git@github.com
```

`modules/core/ssh.nix` 的关键点：

```nix
# sops.secrets 只能在 NixOS 作用域求值，home-manager 内的 config 访问不到它
sshKeyPath = user: config.sops.secrets."users/${user}/ssh_github".path;
```

```nix
programs.ssh.settings."github.com" = {
  IdentityFile = sshKeyPath config.home.username;
  IdentitiesOnly = true;
};
```

替换/轮换 GitHub 私钥：

```bash
ssh-keygen -t ed25519 -C "anscor@aiagent" -f /tmp/k -N ''
cat /tmp/k.pub        # 加到 GitHub → Settings → SSH and GPG keys

cd /home/anscor/nixos-config/sops
cp /tmp/k secrets/users/anscor/ssh_github
sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops -e -i secrets/users/anscor/ssh_github
sudo chown anscor:users secrets/users/anscor/ssh_github
shred -u /tmp/k /tmp/k.pub

cd .. && git add sops/secrets/users/anscor/ssh_github
sudo nixos-rebuild switch --flake .#aiagent
ssh -T git@github.com     # 验证：Hi anscor! You've successfully authenticated...
```

---

## 附：故障排查

| 症状 | 原因 | 处理 |
|---|---|---|
| `no matching creation rules found` | 不在 `sops/` 目录下运行 | `cd sops` 或加 `--config sops/.sops.yaml` |
| `Path 'xxx' is not tracked by Git` | 新文件没 `git add` | `git add xxx` |
| `Failed to get the data key required to decrypt` | 缺 age 私钥 / 该文件不含本机收件人 | 确认 `SOPS_AGE_KEY_FILE`；检查 `.sops.yaml` 收件人 |
| `no master key was able to decrypt`（`updatekeys` 时） | 执行机解不开目标文件 | 换一台能解密的机器执行 |
| 部署后密码失效 | 密码哈希迁移出错 | 见第 8 节往返校验；保留一个 root 会话再改 |
| `keyfile not found` 且 `generateKey = false` | 新机器上没有 age 私钥 | 从 Bitwarden 恢复 `keys.txt`（这是**期望行为**，不会静默生成） |
| 服务读不到 secret（Permission denied） | 用户级 secret 但 `owner` 是 root | 路径放 `users/<user>/` 下（owner 自动为该用户） |

### 恢复 age 私钥（新机器 / 重装）

`/var/lib/sops-nix/keys.txt` 是所有秘密的根。它**不在** git 里，必须自己备份
（建议存 Bitwarden）。丢失后所有 sops 文件**永久无法解密**。

```bash
# 从 Bitwarden 取出后（内容形如：AGE-SECRET-KEY-1...）
sudo mkdir -p /var/lib/sops-nix
sudo install -m 600 /dev/stdin /var/lib/sops-nix/keys.txt
# 粘贴内容后按 Ctrl-D

# 验证能解密
cd sops && sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt \
  sops -d secrets/shared/anscor_authkey >/dev/null && echo "密钥可用 ✓"
```

验证密钥与 `.sops.yaml` 里的公钥匹配：

```bash
sudo grep 'public key' /var/lib/sops-nix/keys.txt
# 与 sops/.sops.yaml 里对应主机的 age1... 逐字符比对
```

---

## 附：`generateKey` 为什么是 false

`sops/default.nix`：

```nix
sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
sops.age.generateKey = false;
sops.age.sshKeyPaths = [ ];
```

- `generateKey = false`：密钥缺失时**明确失败**。若设为 `true`，新机器会自动生成一把
  无关的密钥，导致秘密解不开却"看起来部署成功"，是最难排查的故障模式。
- `sshKeyPaths = [ ]`：不把 sshd host key 当作 age identity（避免意外行为）。
