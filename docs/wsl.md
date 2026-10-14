# WSL 主机（`hosts/wsl`）

在 Windows 的 WSL2 里运行 [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)，
并采用本仓库的配置。与实体机共享 `modules/core`（含 sops / ssh / home-manager）。

## 与实体机的差异

| 项目 | 实体机（tencent / aiagent） | wsl |
|---|---|---|
| `hosts/utils/vm.nix` | 引入（systemd-boot + EFI + NetworkManager） | **不引入** —— WSL 用 Windows 内核与引导 |
| 引导 | `boot.loader.systemd-boot` | `nixos-wsl` 关闭 initrd / kernel / grub 并覆盖 `installBootLoader`，故 `boot.loader.*` 全为 `false` 属正常 |
| 网络 | NetworkManager | `networking.dhcpcd.enable = false`，由 WSL / Windows 侧处理 |
| 代理 | 可选 `net/proxy.nix` | **不含** —— 其中写的是内网地址，WSL 上未必可达；国内取源码/包的做法见「[取包与取源码](#取包与取源码国内网络)」 |
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

## 取包与取源码（国内网络）

首次重建要拿两类东西，通路**完全不同**，混起来就会卡住：

| 拿什么 | 走哪条路 | 有没有镜像 |
|---|---|---|
| **包**（编译好的构建产物，几百 MB ~ GB） | `substituters` | 有：国内镜像站镜像了 `cache.nixos.org` |
| **源码**（flake 输入：nixpkgs / home-manager / nixos-wsl / sops-nix …） | `flake.lock` 里钉的 `github:` 引用，直连 `api.github.com` / `codeload.github.com` | **没有**（Nix 没有全局镜像开关） |

先定义三个变量，本文件后面各步都用它们（换终端要重新 `export`）：

```bash
export NIXPKGS=https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixpkgs-unstable/nixexprs.tar.xz
export SUBSTITUTERS="https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/"
export GH_MIRROR=https://ghfast.top/https://github.com
```

### 包：substituters

```bash
sudo nixos-rebuild switch --flake <仓库绝对路径>#wsl \
  --option experimental-features "nix-command flakes" \
  --option substituters "$SUBSTITUTERS"
```

两个坑：

- **`substituters` 是受限设置**：非 trusted-user 传的 `--option substituters` 会被**静默忽略**
  （日志里只有一行 `ignoring the client-specified setting 'substituters'`）。命令必须 `sudo`。
- 镜像站的 `nix-channels/store` 只镜像**channel 闭包**，不是 `cache.nixos.org` 的全量。
  本仓库的 nixpkgs 是 unstable 的某个 rev，与 channel 不完全一致 → **多数包会回退到列表末尾的
  `cache.nixos.org`**（慢，但通常可达）。所以列表里留一个 `cache.nixos.org` 是必要的。

重建成功后，本仓库的 `nix-settings.nix` 会把同样这份列表写进 `/etc/nix/nix.conf`，
之后不必再传 `--option`（`experimental-features` 同理）。

### 源码：三条路

`flake.lock` 把每个输入钉成 `github:<owner>/<repo>/<rev>`，Nix 直连 GitHub 取。国内通常不通，
而 CLI 层面**没有**「把所有 github 输入改道」的开关，只有下面三条路：

**路线一（推荐）：从已有这份 flake 的机器预置 store**

任何已经构建过本仓库的机器（例如实体机）store 里就有这些输入的源码。导出 → 送到目标机 →
导入；Nix 发现 store 里已有该路径就不再联网取：

```bash
# ① 在已有机器上（仓库目录内）
nix flake archive --json | grep -o '/nix/store/[a-z0-9]*-source' | sort -u > /tmp/inputs.txt
nix-store --export $(cat /tmp/inputs.txt) > inputs.nar     # 未压缩约 1 GB（大头是两份 nixpkgs）

# ② 用任意方式把 inputs.nar 送到目标机（scp / 共享目录 / 内网 HTTP 都行），然后
sudo nix-store --import < inputs.nar
```

**路线二：逐输入改道镜像**

每个 `flake.lock` 里的 `github` 输入对应一条 `--override-input`（嵌套输入写成 `父/子`，
如 `paseo/nixpkgs`）；`owner` / `repo` / `rev` 都能在 `flake.lock` 里直接搜到：

```bash
sudo -H nix-shell -I nixpkgs=$NIXPKGS --option substituters "$SUBSTITUTERS" -p git --run '
  nixos-rebuild switch --flake <仓库绝对路径>#wsl \
    --option experimental-features "nix-command flakes" \
    --option substituters "<SUBSTITUTERS 的值>" \
    --override-input nixpkgs "git+<GH_MIRROR 的值>/NixOS/nixpkgs.git?rev=<rev>" \
    --override-input nixos-wsl "git+<GH_MIRROR 的值>/nix-community/NixOS-WSL.git?rev=<rev>" \
    --override-input nixos-wsl/flake-compat "git+<GH_MIRROR 的值>/edolstra/flake-compat.git?rev=<rev>" \
    --override-input home-manager "git+<GH_MIRROR 的值>/nix-community/home-manager.git?rev=<rev>" \
    --override-input sops-nix "git+<GH_MIRROR 的值>/Mic92/sops-nix.git?rev=<rev>" \
    --override-input disko "git+<GH_MIRROR 的值>/nix-community/disko.git?rev=<rev>" \
    --override-input paseo "git+<GH_MIRROR 的值>/getpaseo/paseo.git?rev=<rev>" \
    --override-input paseo/nixpkgs "git+<GH_MIRROR 的值>/NixOS/nixpkgs.git?rev=<rev>"
'
```

三点说明：

- 必须套 `nix-shell -p git`：`git+https://` 抓取器要调用 `git` 二进制，而最小镜像里没有 git
  （否则报 `executing "git": No such file or directory`）。
- 镜像只是代理 GitHub 的字节，内容与 lock 里完全一致（`narHash` 可用 `nix flake prefetch --json` 核对）。
- `--run` 是单引号包裹的，里面的 `$NIXPKGS` / `$SUBSTITUTERS` 不会展开，所以模板里写成了
  `<… 的值>` 占位符 —— 填的时候直接写实际值。
- **`--override-input` 会改写 `flake.lock`**，重建成功后要还原：

```bash
nix-shell -I nixpkgs=$NIXPKGS -p git --run 'git -C <仓库绝对路径> checkout -- flake.lock'
```

**路线三：让 WSL 能直连 GitHub**（挂一个可用的代理），此时上面两条都不需要。
`.wslconfig` 的 `networkingMode=mirrored` + `autoProxy=true` 可让 WSL 继承 Windows 的代理设置。

---

## 磁盘布局（根盘 + 独立 `/home`）

与实体机 aiagent 一样是「一份 root + 一份 home」，但 WSL 只能自建其中一块：

> 本节用 `<安装目录>` 表示你放 VHD 的目录（**建议放数据盘**），
> `<发行版名>` 表示 `wsl -l` 里显示的名字（下文统一写作 `NixOS`）。

| 盘 | 谁创建 | 位置怎么定 | 大小 |
|---|---|---|---|
| 根 `/` | WSL 自己（`ext4.vhdx`，单个 ext4，**无 GPT、无 `/boot`**） | `wsl --install --from-file .\nixos.wsl --location <安装目录>`，或 `wsl --import <发行版名> <安装目录> .\nixos.wsl --version 2` | 默认上限 1 TB、按需增长；要限上限用安装时的 `--vhd-size`（新版本，`wsl --install --help` 确认）或事后扩容 |
| `/home` | 我们自建的 VHD | `<安装目录>\nixos-home.vhdx`，由 Windows 侧 `wsl --mount … --vhd --bare` 挂成块设备 | 创建时用 diskpart 的 `maximum=` 指定 |

`/home` 独立的好处：`wsl --unregister` 后重新导入根盘时，**home 数据不受影响**。

### 创建 home 盘（管理员 CMD / PowerShell）

```
diskpart
create vdisk file="<安装目录>\nixos-home.vhdx" maximum=<MB> type=expandable
exit
```

`maximum` 单位是 MB（1024 进制），例如 `204800` = 200 GiB；`type=expandable` 表示动态增长
（文件随用随长，上限即 `maximum`）。Windows Pro/Enterprise 装了 Hyper-V 模块也可以用
`New-VHD -Path <安装目录>\nixos-home.vhdx -SizeBytes <大小> -Dynamic`。

### 挂载与首次格式化

Windows 侧（**每次 WSL VM 重启后都要重做**，`wsl --mount` 不持久化；自动化见下）：

```powershell
wsl --mount <安装目录>\nixos-home.vhdx --vhd --bare
```

`--bare` 表示只挂上块设备、不自动 mount，留给 NixOS 侧按下面的声明去挂。

Linux 侧首次格式化。**不要按 `/dev/sdb` 之类的名字猜** —— WSL 自己就占了好几块盘
（根盘、内核模块盘、system distro），枚举顺序不保证，格错一块不可逆。先只读识别：

```bash
findmnt -no SOURCE,FSTYPE /                        # 正在用的根盘（绝不能格）
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,VENDOR,MODEL   # 虚拟盘显示 VENDOR=Msft / MODEL=Virtual Disk
sudo blkid                                         # 有签名的说明已有文件系统
```

要格的那块应同时满足：**无 `FSTYPE`、`blkid` 不列、未挂载、虚拟大小等于你设的 `maximum`**。
最可靠的确认是「先 `wsl --unmount` 卸掉所有 bare 挂载，再只挂 home 盘」，除根盘外新出现的
那块就是它。确认后格式化（最小镜像没有 `mkfs.ext4`，它属于 `e2fsprogs`）：

```bash
DEV=/dev/sdX        # ← 换成上面识别出来的那块

sudo wipefs "$DEV"                                  # 只列签名、不删；有输出就停下
findmnt "$DEV" && { echo "已挂载，停"; exit 1; }
[ -n "$(lsblk -ndo FSTYPE "$DEV")" ] && { echo "已有文件系统，停"; exit 1; }

sudo nix-shell -I nixpkgs=$NIXPKGS -p e2fsprogs --run "mkfs.ext4 -L nixos-home $DEV"
sudo blkid "$DEV"                                   # 期望 LABEL="nixos-home" TYPE="ext4"
```

挂上，并**把家目录建回来** —— 挂载会遮住根盘上的 `/home`，原来的家目录（连同 `~/.bashrc`、
已经克隆的仓库）会瞬间「消失」，`cd ~` 直接报 `No such file or directory`：

```bash
sudo mount /dev/disk/by-label/nixos-home /home
sudo mkdir -p "$HOME" && sudo chown "$USER:users" "$HOME" && sudo chmod 700 "$HOME"
findmnt /home && df -h /home
```

> **顺序很重要**：`mkfs` → `mount /home` → 再执行「安装步骤」里的 `git clone` 与首次
> `nixos-rebuild`。若重建时 `/home` 还没挂上，home-manager 的 activation 会把文件写进根盘，
> 之后被 VHD 一遮，看起来就像 dotfiles 全丢了。

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
参数 `--mount <安装目录>\nixos-home.vhdx --vhd --bare`。

若某次 `/home` 没挂上（例如 `wsl --shutdown` 之后直接开终端，没重跑 `wsl --mount`）：

```powershell
# Windows 侧先 attach
wsl --mount <安装目录>\nixos-home.vhdx --vhd --bare
```

```bash
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

先得到一个能跑的 NixOS，**此时与本仓库无关**：

1. 从 [releases](https://github.com/nix-community/NixOS-WSL/releases/latest) 下载 `nixos.wsl`
   （国内下载手段见「[取包与取源码](#取包与取源码国内网络)」）。
2. 双击安装，或（`--location` 决定根盘放哪，别落到系统盘）：

```powershell
wsl --install --from-file nixos.wsl --location <安装目录>
```

3. 进入系统：

```powershell
wsl -d NixOS
```

> WSL ≥ 2.4.4 之外也可用 `wsl --import <发行版名> <安装目录> nixos.wsl --version 2`。
>
> 首次进入后镜像会提示 `sudo nix-channel --update`。**走 `--flake` 不需要这一步** ——
> channel 是给非 flake 路径用的，而且默认地址（`nixos.org`）国内常拉不动。直接进第 2 步。

### 2. 生成该主机的 age 密钥

sops 采用「每机一钥」，密钥缺失时 activation 会**明确失败**
（`sops.age.generateKey = false`，见 `sops/default.nix`）。在 WSL 里：

最小镜像里既没有 `age`，也**没开 `nix-command` / `flakes`**，所以 `nix shell nixpkgs#age`
这种写法首次进入时用不了（报 `experimental Nix feature 'nix-command' is disabled`），
而且 `nixpkgs#` 会经 flake registry 去 GitHub 取 nixpkgs。改用 `nix-shell` + 国内地址：

```bash
sudo mkdir -p /var/lib/sops-nix

sudo nix-shell -I nixpkgs=$NIXPKGS --option substituters "$SUBSTITUTERS" \
  -p age --run 'age-keygen -o /tmp/wsl-age.txt'

sudo install -m 600 /tmp/wsl-age.txt /var/lib/sops-nix/keys.txt
sudo shred -u /tmp/wsl-age.txt        # 注意 sudo：文件是 root 建的

sudo grep 'public key' /var/lib/sops-nix/keys.txt    # 记下 age1... 公钥
sudo cat /var/lib/sops-nix/keys.txt                  # 备份到密码管理器（唯一不可恢复）
```

> `nix-shell` 用 `--run '<命令>'` 在非交互环境里执行（`--command` 是交互式版本）。

### 3. 在现有机器上授权该公钥

> 完整原理见 [`docs/sops.md` 第 5 节「新增一台机器」](sops.md)，此处只列要点。

1. 在 `sops/.sops.yaml` 的 `keys:` 段加 `- &wsl age1...`，
   并把 `*wsl` 加进 `secrets/shared/` 与 `secrets/users/anscor/` 两个
   `creation_rules` 的 age 列表（需要 WSL 专属秘密时再加 `secrets/hosts/wsl/` 规则）。
2. 在能解密这些文件的机器（如 `aiagent`）上补收件人：

```bash
cd <仓库>/sops
find secrets/shared secrets/users/anscor -type f -exec \
  sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/keys.txt sops updatekeys -y {} \;

# sudo 跑 sops 会把文件改成 root 属主，改回来
sudo chown "$USER:users" secrets/shared/* secrets/users/anscor/*

# 确认新公钥已进元数据（每个文件应输出 1）
grep -c '<新机器的 age 公钥>' secrets/shared/* secrets/users/anscor/*
```

3. 提交 `.sops.yaml` 与重新加密后的 secret。

> `updatekeys` 必须由**持有旧私钥且能解密目标文件**的机器执行；
> WSL 自己还没授权，不能由它来做。

### 4. 在 WSL 里切换到本仓库配置

前置：`/home` 已挂载、家目录存在（见「磁盘布局」末的注意事项）。

```bash
# 最小镜像没有 git，且 GitHub https 国内常不通 —— 走镜像克隆
sudo nix-shell -I nixpkgs=$NIXPKGS --option substituters "$SUBSTITUTERS" \
  -p git --run "git clone $GH_MIRROR/anscor/nixos-config.git $HOME/nixos-config"

sudo chown -R "$USER:users" "$HOME/nixos-config"    # 上面以 root 克隆，属主需改回
cd ~/nixos-config
cat .git/refs/heads/main                           # 记下 commit，便于与上游核对
```

首次重建见「[取包与取源码](#取包与取源码国内网络)」：包走 `substituters`，
**而源码（flake 输入）默认直连 GitHub，国内需要预置 store 或 `--override-input` 改道**。
首次还要加 `--option experimental-features "nix-command flakes"`（重建后由仓库配置接管）。
以后每次改动只需：

```bash
sudo nixos-rebuild switch --flake .#wsl
```

> 若报 `repository path '...' is not owned by current user`：仓库属主是克隆它的用户，
> 而重建以 root 执行，需要先按 [`docs/rebuild.md`](rebuild.md) 加一条 `safe.directory`。
> 最小镜像里没有 `git`，那条命令要写成
> `sudo -H nix-shell -I nixpkgs=$NIXPKGS -p git --run 'git config --global --add safe.directory <仓库绝对路径>'`。

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
| `keyfile not found`（`generateKey = false`） | `/var/lib/sops-nix/keys.txt` 缺失 | 从密码管理器恢复（见 `docs/sops.md`） |
| 引导 / `boot.loader` 相关报错 | 误引入了 `hosts/utils/vm.nix` | 从 `hosts/wsl/default.nix` 的 `modules` 里移除 |
| `mkfs.ext4: command not found` | 最小镜像没有 `e2fsprogs` | `nix-shell -I nixpkgs=$NIXPKGS -p e2fsprogs --run 'mkfs.ext4 …'` |
| `git: command not found` | 最小镜像没有 `git` | `nix-shell -I nixpkgs=$NIXPKGS -p git --run '<命令>'` |
| `experimental Nix feature 'nix-command' is disabled` | 镜像没开 `nix-command` / `flakes` | 用 `nix-shell`；`nixos-rebuild` 加 `--option experimental-features "nix-command flakes"` |
| `unable to download 'https://github.com/…': Timeout` / `Failed to open archive` | flake 输入（源码）直连 GitHub | 见「[取包与取源码](#取包与取源码国内网络)」：预置 store 或 `--override-input` 改道 |
| `executing "git": No such file or directory` | `git+https://` 抓取器要调用 `git` 二进制 | 把命令套进 `nix-shell -p git --run '…'` |
| `ignoring the client-specified setting 'substituters'` | `substituters` 是受限设置，非 trusted-user 的 `--option` 被忽略 | 命令前加 `sudo` |
| `cd ~` 报 `No such file or directory` | 刚把 home 盘挂到 `/home`，原家目录被遮住 | `sudo mkdir -p "$HOME" && sudo chown "$USER:users" "$HOME"` |
| 网络不通 | WSL 侧 DNS / `dhcpcd` 冲突 | 不要启用 `networking.dhcpcd`；检查 Windows 侧 `.wslconfig` |
| `Path '...' is not in the repository` | 新文件没 `git add` | flake 只可见被 git 跟踪的文件 |
| `repository path '...' is not owned by current user` | 仓库属主是克隆它的用户，而重建以 root 执行 | 按 [`docs/rebuild.md`](rebuild.md) 加一条 `safe.directory` |
| 想走代理 | 默认不含 `net/proxy.nix`（其中写的是内网地址，未必可达） | 在 `hosts/wsl/default.nix` 的 `moduleNames` 里加 `"net/proxy.nix"` 并换成 WSL 可达的地址；**引导期还没有本仓库配置，改不了** —— 先用「取包与取源码」里的镜像路线 |
