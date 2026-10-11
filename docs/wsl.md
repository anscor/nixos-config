# WSL 主机（`hosts/wsl`）

在 Windows 的 WSL2 里运行 [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)，
并采用本仓库的配置。与实体机共享 `modules/core`（含 sops / ssh / home-manager）。

## 与实体机的差异

| 项目 | 实体机（tencent / aiagent） | wsl |
|---|---|---|
| `hosts/utils/vm.nix` | 引入（systemd-boot + EFI + NetworkManager） | **不引入** —— WSL 用 Windows 内核与引导 |
| 引导 | `boot.loader.systemd-boot` | `nixos-wsl` 关闭 initrd / kernel / grub 并覆盖 `installBootLoader`，故 `boot.loader.*` 全为 `false` 属正常 |
| 网络 | NetworkManager | `networking.dhcpcd.enable = false`，由 WSL / Windows 侧处理 |
| 代理 | 可选 `net/proxy.nix` | **不含** —— 其 `192.168.31.70` 是内网地址，WSL 上未必可达 |
| 模块 | 各自挑选 | 仅 `modules/core` + home-manager + `modules/wsl`；不含 GUI / paseo / AI CLI |

平台模块 `modules/wsl/default.nix` 引入 `inputs.nixos-wsl.nixosModules.default`，
并设 `wsl.defaultUser = lib.head sUsers`（即 `anscor`，来自 `outputs.nix` 的 `sUsers`）。

相关文件：

```
flake.nix                      新增 nixos-wsl input（nixpkgs 跟随本仓库）
outputs.nix                    nixosConfigurations."wsl" = mkNixos ./hosts/wsl
modules/wsl/default.nix        引入 nixos-wsl 模块 + wsl.enable / wsl.defaultUser
hosts/wsl/default.nix          hostName = "wsl"、stateVersion，moduleNames = [ "wsl" ]
```

---

## 磁盘布局（根盘 + 独立 `/home`）

与实体机 aiagent 一样是「一份 root + 一份 home」，但 WSL 只能自建其中一块：

| 盘 | 谁创建 | 位置怎么定 | 大小 |
|---|---|---|---|
| 根 `/` | WSL 自己（`ext4.vhdx`，单个 ext4，**无 GPT、无 `/boot`**） | `wsl --install --from-file .\nixos.wsl --location E:\WSL\NixOS`，或 `wsl --import NixOS E:\WSL\NixOS .\nixos.wsl --version 2` | 默认上限 1 TB、按需增长；要限上限用安装时的 `--vhd-size`（新版本，`wsl --install --help` 确认）或事后扩容 |
| `/home` | 我们自建的 VHD | `E:\WSL\nixos-home.vhdx`，由 Windows 侧 `wsl --mount … --vhd --bare` 挂成块设备 | 创建时用 diskpart 的 `maximum=` 指定 |

`/home` 独立的好处：`wsl --unregister` 后重新导入根盘时，**home 数据不受影响**。

### 创建 home 盘（管理员 CMD / PowerShell）

```
diskpart
create vdisk file="E:\WSL\nixos-home.vhdx" maximum=204800 type=expandable
exit
```

`maximum` 单位是 MB（1024 进制），`204800` = 200 GiB；`type=expandable` 表示动态增长
（文件随用随长，上限即 `maximum`）。Windows Pro/Enterprise 装了 Hyper-V 模块也可以用
`New-VHD -Path E:\WSL\nixos-home.vhdx -SizeBytes 200GB -Dynamic`。

### 挂载与首次格式化

Windows 侧（**每次 WSL VM 重启后都要重做**，`wsl --mount` 不持久化；自动化见下）：

```powershell
wsl --mount E:\WSL\nixos-home.vhdx --vhd --bare
```

`--bare` 表示只挂上块设备、不自动 mount，留给 NixOS 侧按下面的声明去挂。
Linux 侧首次格式化：

```bash
lsblk -o NAME,SIZE,FSTYPE        # 新盘通常是 /dev/sdb，但枚举顺序不保证
sudo mkfs.ext4 -L nixos-home /dev/sdb
```

`hosts/wsl/default.nix` 里按 **label** 声明（不用 `/dev/sdX`）：

```nix
fileSystems."/home" = {
  device = "/dev/disk/by-label/nixos-home";
  fsType = "ext4";
  options = [ "defaults" "nofail" "x-systemd.device-timeout=10" ];
};
```

`nofail` + 较短的 `device-timeout`：盘没 attach 时不阻断启动。

**开机自动 attach**：任务计划程序新建任务 → 触发器「登录时」→ 操作 `wsl.exe`，
参数 `--mount E:\WSL\nixos-home.vhdx --vhd --bare`。

若某次 `/home` 没挂上（例如 `wsl --shutdown` 之后直接开终端，没重跑 `wsl --mount`）：

```bash
# Windows 侧先 attach
wsl --mount E:\WSL\nixos-home.vhdx --vhd --bare
# Linux 侧再补挂（systemd 不会自动重试已失败的 mount unit）
sudo systemctl start home.mount
```

### 顺带：关掉 swap 与换盘

`%UserProfile%\.wslconfig`：

```ini
[wsl2]
swap=0            # 官方语义：0 = 不建 swap 文件
memory=16GB       # 关掉 swap 后建议显式给足，否则 nix 构建会被 OOM kill

[experimental]
sparseVhd=true    # 之后新建的 VHD 自动 sparse，删文件后空间能还给 Windows
```

swap 默认是内存的 25%（盘在 `%Temp%\swap.vhdx`）；改完 `wsl --shutdown` 生效。
需要挂载额外的数据盘时：`wsl --mount <路径>.vhdx --vhd --bare` 会对**所有** WSL2 发行版可见。

---

## 安装步骤

### 0. Windows 侧前置

```powershell
wsl --install --no-distribution
wsl --version        # 需要 ≥ 2.4.4（双击 .wsl 安装依赖它）
```

### 1. 导入官方 NixOS-WSL 发行版

先得到一个能跑的 NixOS，**此时与本草稿仓库无关**：

1. 从 [releases](https://github.com/nix-community/NixOS-WSL/releases/latest) 下载 `nixos.wsl`。
2. 双击安装，或：

```powershell
wsl --install --from-file nixos.wsl
```

3. 进入系统：

```powershell
wsl -d NixOS
```

> WSL ≥ 2.4.4 之外也可用 `wsl --import NixOS $env:USERPROFILE\NixOS nixos.wsl --version 2`。
> 首次进入后按提示 `sudo nix-channel --update`，否则 `nixos-rebuild` 不可用。

### 2. 生成该主机的 age 密钥

sops 采用「每机一钥」，密钥缺失时 activation 会**明确失败**
（`sops.age.generateKey = false`，见 `sops/default.nix`）。在 WSL 里：

```bash
sudo mkdir -p /var/lib/sops-nix
nix shell nixpkgs#age -c age-keygen -o /tmp/wsl-age.txt
sudo install -m 600 /tmp/wsl-age.txt /var/lib/sops-nix/keys.txt
shred -u /tmp/wsl-age.txt

sudo grep 'public key' /var/lib/sops-nix/keys.txt    # 记下 age1... 公钥
sudo cat /var/lib/sops-nix/keys.txt                  # 备份到 Bitwarden（唯一不可恢复）
```

### 3. 在现有机器上授权该公钥

> 完整原理见 [`docs/sops.md` 第 5 节「新增一台机器」](sops.md)，此处只列要点。

1. 在 `sops/.sops.yaml` 的 `keys:` 段加 `- &wsl age1...`，
   并把 `*wsl` 加进 `secrets/shared/` 与 `secrets/users/anscor/` 两个
   `creation_rules` 的 age 列表（需要 WSL 专属秘密时再加 `secrets/hosts/wsl/` 规则）。
2. 在能解密这些文件的机器（如 `aiagent`）上补收件人：

```bash
cd /home/aiagent/nixos-config/sops
find secrets/shared secrets/users/anscor -type f -exec \
  sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops updatekeys -y {} \;
```

3. 提交 `.sops.yaml` 与重新加密后的 secret。

> `updatekeys` 必须由**持有旧私钥且能解密目标文件**的机器执行；
> WSL 自己还没授权，不能由它来做。

### 4. 在 WSL 里切换到本仓库配置

```bash
# 仓库是 public，先用 https 克隆（此时 WSL 还没有 GitHub SSH 私钥）
git clone https://github.com/anscor/nixos-config.git ~/nixos-config
cd ~/nixos-config

sudo nixos-rebuild switch --flake .#wsl
```

> 首次会拉取本仓库锁定的 `nixpkgs` 与 `nixos-wsl`，耗时较长。
> 之后每次改动都重复这一条 `nixos-rebuild switch --flake .#wsl`。
> 若报 `repository path '...' is not owned by current user`：WSL 上的仓库属于克隆它的用户，
> 而重建以 root 执行，需要先按 [`docs/rebuild.md`](rebuild.md) 加一条 `safe.directory`。

### 5. 验证

```bash
cat /etc/wsl.conf                    # 应有 [user] default=anscor
sudo passwd -S anscor                # P（密码哈希来自 sops 的 shared/anscor_authkey）
ls -l /run/secrets/users/anscor/ssh_github    # -r-------- anscor users
ssh -T git@github.com                # Hi anscor! You've successfully authenticated...
systemctl is-system-running          # running（degraded 时用 systemctl --failed 排查）
```

Windows 侧 `wsl --terminate NixOS` 后重进，默认用户才会切成 `anscor`。

---

## 故障排查

| 症状 | 原因 | 处理 |
|---|---|---|
| `Failed to get the data key required to decrypt` | 第 3 步没做，或公钥没进 `.sops.yaml` | 补 `updatekeys`（见第 3 步） |
| `keyfile not found`（`generateKey = false`） | `/var/lib/sops-nix/keys.txt` 缺失 | 从 Bitwarden 恢复（见 `docs/sops.md`） |
| 引导 / `boot.loader` 相关报错 | 误引入了 `hosts/utils/vm.nix` | 从 `hosts/wsl/default.nix` 的 `modules` 里移除 |
| 网络不通 | WSL 侧 DNS / `dhcpcd` 冲突 | 不要启用 `networking.dhcpcd`；检查 Windows 侧 `.wslconfig` |
| `Path '...' is not in the repository` | 新文件没 `git add` | flake 只可见被 git 跟踪的文件 |
| `repository path '...' is not owned by current user` | 仓库属主是克隆它的用户，而重建以 root 执行 | 按 [`docs/rebuild.md`](rebuild.md) 加一条 `safe.directory` |
| 需要走代理 | 默认不含 `net/proxy.nix` | 把 `192.168.31.70` 换成 WSL 可达的地址后，在 `hosts/wsl/default.nix` 的 `moduleNames` 里加 `"net/proxy.nix"` |
