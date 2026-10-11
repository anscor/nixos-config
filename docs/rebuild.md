# 重建与仓库属主

本仓库的克隆**不属于 root**（在 `aiagent` 主机上属于 `aiagent`，在 WSL 上属于克隆它的那个
用户），而 `nixos-rebuild` 必须由 root 执行。两者身份不一致时，git 的所有权保护会直接中断
重建。本文记录成因、一次性修复、验证方式与备选方案。

## 症状

```console
$ cd /home/aiagent/nixos-config && sudo nixos-rebuild switch --flake .#aiagent
error:
       … while fetching the input 'git+file:///home/aiagent/nixos-config'

       error: opening Git repository "/home/aiagent/nixos-config":
              repository path '/home/aiagent/nixos-config' is not owned by current user
              (libgit2 error code = 7)
```

以仓库属主身份执行同样的求值（`nix eval`、`git`）一切正常 —— 这正说明问题只出在
「执行身份 ≠ 仓库属主」上。

## 成因

1. `nixos-rebuild` 需要 root：activation 阶段要写 `/run/secrets`、切换 generation。
2. Nix 对 `--flake <目录>` 求值时发现它是 git 工作树，于是走 **git fetcher**：按索引与
   `.gitignore` 决定哪些文件进 store，底层调用 **libgit2**。
3. git 自 2.35 起（CVE-2022-24765）拒绝操作「属主不是当前用户」的仓库，防止有人往共享目录里
   放一份带 hook 的 `.git`，借他人身份执行代码；libgit2 实现了同一套检查。
4. 而仓库**刻意**不属于 root：AI 相关改动以 `aiagent` 身份提交、paseo 也以该身份运行
   （见 `modules/cli/ai/paseo.nix` 与 `users.nix` 的身份隔离设计）。

## 修复（每台机器做一次）

```bash
# 换成你的仓库实际路径
sudo -H git config --global --add safe.directory /home/aiagent/nixos-config
```

`-H` 不能省：libgit2 读的是**用户级**配置 `$HOME/.gitconfig`，而 `sudo` 默认可能保留调用者
的 `HOME`，那样会写进 `/home/anscor/.gitconfig`，root 执行时读不到。

之后重建统一用这个形式（保持 HOME 一致）：

```bash
sudo -H nixos-rebuild switch --flake /home/aiagent/nixos-config#aiagent

# 或先进 root shell —— HOME 自然是 /root
sudo -i
cd /home/aiagent/nixos-config && nixos-rebuild switch --flake .#aiagent
```

## 验证

```bash
sudo -H nix flake metadata /home/aiagent/nixos-config   # 秒级，不必跑完整重建
```

能打印 flake 的 inputs 与 locked 版本即已生效；否则会复现上面的 libgit2 报错。

## 为什么不能写进 Nix 配置

在 `nix-2.34.8` / `libgit2-1.9.7` 上逐项验证过（对二进制做 `grep -a` 字符串检查）：

| 途径 | 结果 |
|---|---|
| `environment.etc."gitconfig"`（系统级 `/etc/gitconfig`） | ❌ libgit2 里没有该路径，它不读系统配置 |
| `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_n`（git CLI 的环境变量注入） | ❌ libgit2 未实现 |
| `GIT_CONFIG_GLOBAL` 指向自定义文件 | ✅ 可用，但要多维护一个文件，不如直接写 `$HOME/.gitconfig` |
| 用户级 `$HOME/.gitconfig` | ✅ 本方案 |

所以这一步只能在机器上手工做一次：**换机或重装后必须重做**，否则重建会以上面的报错中断。

## 备选：绕开 git fetcher

```bash
sudo nixos-rebuild switch --flake path:/home/aiagent/nixos-config#aiagent
```

`path:` 前缀让 Nix 走纯文件系统拷贝，不经过 libgit2，因而没有所有权检查。代价是 `.git`
与 `.gitignore` 命中的内容（例如被忽略的 `docs/superpowers/`）也会一起进 store，拷贝更大；
日常仍推荐上面的 `safe.directory`。

## 影响范围与撤销

`safe.directory` 是**按路径的白名单**，不是关闭检查：

- 只对列出的这一个路径生效，其它仓库不受影响；
- 只对写了这条配置的用户（root）生效；
- 不改仓库属主，也不给 `aiagent` 任何额外权限或 sudo 能力。

```bash
# 查看现有白名单
sudo -H git config --global --get-all safe.directory

# 撤销
sudo -H git config --global --unset safe.directory
```
