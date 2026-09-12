# WSL × Windows 双系统开发规范（mikcb）

> 建立日期：2026-09-12 ｜ 依据：微软 WSL 官方文档《跨 Windows 和 Linux 文件系统工作》+ 本机实测
> 适用：Windows 侧 Cursor、WSL 侧各 Agent（DSH / WorkBuddy 等）
>
> 本文是**仓库内可版本化的**规范正文。`AGENTS.md` 里同名章节是它的"常驻摘要"（`AGENTS.md` 被 `.gitignore` 有意排除，仅本地生效），两者冲突时以本文为准。

---

## 0. 一句话现状

本仓源码（1160 个受控文件）与**全部机器态产物**（合计 12 GB，其中 `build/` 8.6 G、`.dart_tool/` 1.7 G）都在 `/mnt/c/cursor/mikcb`（9p 挂载），Windows 与 WSL 每天在同一个目录上互写。微软文档开篇第一条就是「避免跨文件系统使用文件」，我们**没有执行这一条**，代价是三类实测可复现的事故（第 1、2 节）。

---

## 1. ⛔ 最高优先级：`.dart_tool/package_config.json` 是双系统共用的单向开关

### 1.1 机理

该文件用**绝对路径**记录每个包的 `rootUri`：

| 谁生成 | rootUri 形态 | 在对方系统里 |
|---|---|---|
| Windows 侧 `flutter pub get` | `file:///D:/Cache/Pub/hosted/pub.dev/...` | Linux 会把 `file:///D:/...` 当字面路径 `/D:/...`，不存在 |
| WSL 侧 pub | `file:///home/mutx/.pub-cache/...` | Windows 侧同样找不到 |

两个系统共用一份工作区 = 共用这一个文件，**后跑的覆盖先跑的**，没有合并机制。

### 1.2 实测触发条件（2026-09-12，隔离副本对照实验）

| WSL 侧调用 | `package_config.json` | 后果 |
|---|---|---|
| `/opt/flutter/bin/flutter analyze --no-pub` | md5 不变 ✅ | Windows 侧不受影响 |
| `/opt/flutter/bin/flutter analyze`（缺 `--no-pub`，隐式触发 pub get） | **被改写** → `/home/mutx/.pub-cache` ⛔ | Windows 侧 Cursor 全项目 import 报「系统找不到指定的路径」 |
| `/opt/flutter/bin/dart analyze` | md5 不变 ✅ | dart 本就不做 pub，但见 1.4 |

### 1.3 WSL 侧硬规则

1. 静态分析一律 `/opt/flutter/bin/flutter analyze --no-pub [路径]`。
2. **禁止裸 `flutter`**：PATH 上的 `flutter` 是 `/mnt/d/Flutter/flutter/bin/flutter`（Windows wrapper，CRLF shebang），在 WSL 下必然 `/usr/bin/env: 'bash\r': No such file or directory`。
3. **禁止 `pub get` / 改依赖**：依赖变更交 Windows 侧 Cursor 执行。
4. 收尾自检（非 0 = 已被 WSL 踩坏，须在 Windows 侧重跑 `flutter pub get`）：

   ```bash
   grep -c '/opt/flutter\|/home/mutx/.pub-cache' .dart_tool/package_config.json
   ```

### 1.4 两个容易误判的现象

- **`dart analyze` 没有 `--no-pub` 选项**（`Could not find an option named "--no-pub"`，exit 64）。别给 dart 加 flutter 的旗标。
- **即使 `package_config` 仍是 Windows 格式（未被动过），WSL 侧 `dart analyze` 也一定报满** `Target of URI doesn't exist: 'dart:ui' / 'package:flutter/material.dart'`。所以在本共享工作区里，**WSL 侧可用的是 `flutter analyze`（用 FLUTTER_ROOT 内 SDK 解析），`dart analyze` 天然不可用**。看到一屏 `uri_does_not_exist` 先看本节，别改代码，更别为它跑 `pub get`。

### 1.5 成本上限（别把 WSL 当全仓门禁）

实测 WSL 侧整仓 `flutter analyze --no-pub`：**918 秒（≈15 分钟）、42182 条 issue、exit 1**，其中大半是假警报（从 pub 缓存解析不到 → `uri_does_not_exist`；`tool/*.dart` 依赖未在 pubspec 直接声明的包，如 `table_parser`）。

**正确用法**：`flutter analyze --no-pub <本次改动的文件/目录>` 做快速单点验证；全仓 analyze 与整批测试由 Windows 侧 Cursor / CI 执行。

---

## 2. 跨文件系统：性能与协作边界（2026-09-12 实测）

### 2.1 性能

400 个 dart 文件的合成仓：

| 操作 | 9p（`/mnt/c`） | ext4（WSL 原生） | 倍数 |
|---|---|---|---|
| `git status` | 0.352 s | 0.004 s | ~88× |
| 删 + `git checkout` 400 文件 | 3.530 s | 0.016 s | ~220× |

> 注意：微软文档里「`\\wsl$` 直存性能更高」那句**不要拿来论证搬迁收益**——较新 WSL 对 9p 做了元数据缓存，裸 `git status`/小文件写已接近原生。真正贵的是**跨边界 × 大量小文件 × 被两个系统同时打开**。

### 2.2 协作边界（两条硬事实）

- **文件事件不跨 9p 边界**：Windows 进程写入 `/mnt/c/...` 的文件，WSL 侧 `inotify` **收不到任何事件**（WSL 自己写的能收到）。→ **不要设计文件监听/事件驱动的双系统协作**；改动后以 `git status` + 文件 mtime 为事实来源。
- **`C:\cursor\mikcb` 大小写不敏感**：`fsutil file queryCaseSensitiveInfo` 显示「已禁用区分大小写」，仓内 `touch .CaseA` 与 `.casea` **指向同一 inode**。Linux 侧不要依赖文件名大小写区分。

### 2.3 磁盘占用定性（12 GB 的来源）

| 目录 | 体积 | 定性 | 建议 |
|---|---|---|---|
| `build/` | 8.6 G | 谁构建归谁的机器态 | 可外置/软链到各系统本地 |
| `.dart_tool/` | 1.7 G | 双系统互踩的载体 | **优先外置**，可根治第 1 节 |
| `site/` | 628 M | 生成产物 | 按其生成流程归位 |
| `android/` | 187 M | 源码 + 本机构建态混合 | 源码保留 |
| `.omx/` | 122 M | 会话/工具态 | 不入库、可清理 |
| `.git` | 53 M | — | 保留 |

**不建议整体搬迁**（Windows 侧 Cursor 是源码真源、需资源管理器可见）。把 `build/`、`.dart_tool/` 外置是收益最大、风险最小的一步——**但属于用户决策，动手前先确认**。

---

## 3. 工具箱（本规范随附的两个脚本）

### 3.1 `scripts/wsl-env.sh` —— WSL 侧环境补齐 + 诊断

解决「DSH/无头 Agent 的 bash 是非交互 shell，**不加载 `~/.profile`**，于是代理/PATH/PUB_CACHE 全空」的问题。

```bash
source scripts/wsl-env.sh          # 修好当前 shell：PATH（/opt 优先）、PUB_CACHE、ANDROID_HOME、代理
bash   scripts/wsl-env.sh --doctor # 只诊断：工具链解析、版本、.fvmrc、package_config 健康度、adb、代理
bash   scripts/wsl-env.sh -- <cmd> # 用修好的环境跑一条命令

WSL_ENV_SKIP_PROXY=1 source scripts/wsl-env.sh   # 跑 flutter test 前必须这样（见下）
```

> **`flutter test` 与代理**：会话环境若带 `http_proxy`，`flutter_tester` 的本机 WebSocket 会被拦，报 `Unable to connect to flutter_tester process: Invalid WebSocket upgrade request`（连官方模板用例也失败，与代码无关）。跑测试前用 `WSL_ENV_SKIP_PROXY=1` 或先 `unset` 各 `*_proxy`。

### 3.2 `scripts/sync-main.sh` —— 双远端推送（bash 版）

逻辑与 `scripts/sync-main.ps1` **完全一致**（WSL 里没有 pwsh，Windows 侧仍用 PS1；改其一时请同步另一个）。固化三条铁律：先拉取（fetch 只指 GitHub）→ 不经 origin 别名显式 URL 推 GitHub → cnb 用 `--force-with-lease` 钉住当前 tip 推镜像 → 校验三端一致。

```bash
bash scripts/sync-main.sh --dry-run   # 只做检查/彩排，不推送
bash scripts/sync-main.sh             # 完整四步
```

> 起因见 PS1 头注释：2026-09-07 曾因 `origin` 双 push URL + `git pull --rebase` 静默丢过本地提交。

### 3.3 交互 shell 的 PATH（已落地）

`~/.bashrc` 与 `~/.profile` **末尾**各有一份：

```bash
export PATH="/opt/flutter/bin:/opt/android-sdk/platform-tools:$PATH"
```

两处都要：`~/.profile` 中途会执行 `PATH="$HOME/bin:$PATH"`，而 `~/bin/adb` 是指向 Windows 侧 `adb.exe` 的软链，只在 bashrc 里加会被它顶回最前。原始文件备份为 `~/.bashrc.bak-*`、`~/.profile.bak-*`。

---

## 4. 职责分工（工具链）

| | Windows 侧 Cursor | WSL 侧 Agent |
|---|---|---|
| 源码真源 / 资源管理器 | ✅ | — |
| 编译 / 构建 / 出包（`flutter build`、release 产物） | ✅ 主责 | 不主动跑 |
| 全仓 `flutter analyze` / 整批测试 | ✅ | ❌（15 分钟 + 假警报） |
| 单点 `flutter analyze --no-pub <文件>` | 可用 | ✅ 主责 |
| 单文件 `flutter test --timeout` | 可用 | ✅（须 `WSL_ENV_SKIP_PROXY=1`） |
| `pub get` / 改依赖 | ✅ **唯一允许** | ❌ 禁止 |
| git / 脚本（bash 版） | PS1 | SH |
| adb 物理设备 | ✅ | 默认不接（实测 `adb devices` 为空） |

工具链版本：`/opt/flutter`（WSL）= 3.44.8 / Dart 3.12.2，`D:\Flutter\flutter`（Windows）= 3.44.8，`.fvmrc` = 3.44.8 —— **三处一致，勿漂移**。

---

## 5. adb 说明

- PATH 上有三份：`~/bin/adb`（软链→Windows `adb.exe`）、`/mnt/d/Cache/Android/Sdk/...`（死条目）、`/opt/android-sdk/platform-tools/adb`（WSL 原生 37.0.1，**应当用这个**）。
- WSL 侧实测 `adb devices` 为空。不要为了"找设备"去起 Windows 侧 adb server（会在两个系统各起一个 server，端口 5037 互相抢占）。
- 用 `android_*` 工具前先确认 serial，不凭记忆操作未识别的设备。

---

## 6. 待用户决策 / 未做的事项

1. **`build/`、`.dart_tool/` 外置或软链到各系统本地**（收益最大，可根治第 1 节）——需用户确认后执行。
2. **worktree 清理**：`git worktree list` 有 3 个 `prunable` 登记（`C:/cursor/...`，WSL 下路径不成立），会误导后续 Agent；4 个仍在磁盘上的（`mikcb_card_opacity`、`mikcb_homepull`、`mikcb_merge_136`、`mikcb_merge_148`）**不要动**。清理需与知情者核对后 `git worktree prune`。
3. **Windows → WSL 方向自动化**：目前没有任何固化入口（全仓仅 `.workbuddy/memory/2026-09-11.md` 记载 WorkBuddy 调 `wsl.exe` 被安全策略拦，但 `\\wsl.localhost\Ubuntu-24.04\...` UNC 可读写、**不能执行** Linux 程序）。若要做，需用户确认走哪条路。
4. **`WSLENV` 未使用**：当前为空。若确实需要跨系统传环境变量，可在此固化（`/p` 路径转换、`/l` 列表、`/u` 仅 Win32→WSL、`/w` 仅 WSL→Win32）。

---

## 7. 速查

| 症状 | 真因 | 处置 |
|---|---|---|
| Windows 侧 import 全红「系统找不到指定的路径」 | `package_config.json` 被 WSL 侧改写 | Windows 侧重跑 `flutter pub get` |
| WSL 侧一屏 `uri_does_not_exist`（含 `dart:ui`） | `package_config` 指向 `D:/...`，或误用了 `dart analyze` | 改用 `flutter analyze --no-pub <文件>` |
| `/usr/bin/env: 'bash\r'` | 用了 `/mnt/d` 的 Windows flutter | `source scripts/wsl-env.sh` 或写全 `/opt/flutter/bin/flutter` |
| `Unable to connect to flutter_tester process` | 代理拦了本机 WebSocket | `WSL_ENV_SKIP_PROXY=1` 后跑测试 |
| `%PROGRAMFILES(X86)% environment variable not found` | Windows 侧 Agent 环境被剥空 | `scripts/with-win-env.ps1`（见 AGENTS.md） |
| WSL 侧看不到 Windows 刚改的文件事件 | inotify 不跨 9p | 用 `git status` / mtime 判断 |
