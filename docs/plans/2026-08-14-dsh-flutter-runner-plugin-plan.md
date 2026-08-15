# dsh-flutter-runner 插件整体方案（一站式 Flutter 调试工具）

> 在 DeepSeek Harness（DSH）Web UI 中复刻 VSCode/Cursor 的 Flutter 调试体验：
> **无线 ADB 连接管理（cursor-adb-connect）+ 一键编译安装到手机 + 实时日志（flutter run / logcat）+ 热重载**，全部收进一个插件。
> 日期：2026-08-14 · 状态：方案（未开工）· 作者：顾承安（研发负责人）

## 1. 背景与目标

### 1.1 用户诉求

用户是 Flutter Android 开发者，日常工作依赖两套工具：

1. **VSCode 调试运行**：点一下 Run/Debug → 编译 → 安装到手机 → 启动，实时查看日志；
2. **cursor-adb-connect（ADB Quick Connect）**：无线 ADB 连接管理——从剪贴板读取手机上的配对信息，一键 adb pair + adb connect 无线连上手机，持续监控连接状态，断开自动告警并可一键重连。

目标：把这两套能力**全部集合**进一个 DSH 插件，做成**一站式调试工具**，同时让 DSH agent 也能直接驱动整条链路。

### 1.2 功能矩阵（一站式）

| 模块 | 功能 | 来源 |
| --- | --- | --- |
| A. 无线连接 | 剪贴板解析配对/连接信息、一键 pair+connect、最近连接历史、一键重连、断开、状态轮询监控、断线告警 | cursor-adb-connect（完整移植） |
| B. 设备管理 | 设备列表（USB/无线/模拟器/桌面）、刷新 | 新开发（flutter devices --machine） |
| C. 构建安装 | 一键 build apk（debug/profile/release）→ install → 启动，进度可视化 | 新开发 |
| D. 运行与日志 | flutter run 流式日志（xterm.js）、关键字过滤、只看本 App logcat | 新开发 |
| E. 热重载 | PTY 注入 r/R 键，对话中「热重载」也可触发 | 新开发 |
| F. Agent 工具 | flutter_devices / flutter_build_install / flutter_run / flutter_stop / flutter_logs / adb_connect / adb_disconnect / adb_status | 新开发（对齐 dsh-ssh） |

### 1.3 非目标（V1）

- 不做 iOS；不做断点调试/DAP（V2 考虑）；不做模拟器创建管理。

## 2. 可行性分析（已实测验证）

### 2.1 DSH 现有能力

| 能力 | 包 | 说明 |
| --- | --- | --- |
| 命令执行 | dsh-bash-local / dsh-pwsh-local | agent 可直接跑 flutter/adb 命令（已装） |
| 后台任务 | dsh-jobs | 长耗时构建任务挂后台 |
| PTY 终端 | dsh-terminal / node-pty | 承载 flutter run 交互（热重载按键） |
| HTTP 路由 | dsh-host-webserver | 插件注册 /api 路由 + WebSocket upgrade |
| 工具注册 | dsh-tools | defineTool + ctx.tools.register |
| 设置页 | dsh-settings | installSettingsSection 挂插件配置 |
| 通知 | dsh-client-ui-slots / 系统通知 | 断线告警可复用 |

**实测（2026-08-14 本机）：**

- flutter 3.44.4 可用，检测到真机 25060RK16C（android-arm64, Android 16 API 36）；
- adb **不在 PATH**（cursor-adb-connect 的探测逻辑正好解决：ANDROID_HOME → %LOCALAPPDATA%\Android\Sdk\platform-tools → PATH）；
- 全家桶源码完整存在于 ~/.dsh/profiles/web/node_modules/@linxin666/（dsh-ssh 双面结构模板）；
- **cursor-adb-connect 源码在本机 D:\Users\34045\Desktop\cursor\cursor-adb-connect\**（extension.js 14.7KB，正则/探测/轮询逻辑可直接移植）。

### 2.2 生态现状

dsh-ssh（双面结构模板，WebSocket 终端）、DSH-better-sidebar（VSCode 式侧边栏）、dsh-mobile-control（ADB 操控）、dsh-doctor（flutter doctor 诊断）——**没有现成的 Flutter 一键构建+日志插件，也没有无线 ADB 连接管理插件，本方案是生态空白点的完整覆盖。**

## 3. 插件设计：dsh-flutter-runner（一站式）

### 3.1 整体架构（双面插件）

```
┌─────────────────────── DSH Web UI（浏览器）──────────────────────┐
│  client 面（dsh.client 注入）                                     │
│  FlutterPanel（侧边栏入口 + 中心面板，Tab 式）                    │
│  ├─ ConnectionTab  无线 ADB：粘贴配对信息→一键连接/最近连接/断开  │
│  │                 状态徽标（已连接 serial / 未连接）+ 断线告警   │
│  ├─ DeviceTab      设备列表（flutter devices，USB+无线+模拟器）   │
│  ├─ BuildTab       一键构建安装（模式选择 + 进度条 + 步骤日志）   │
│  └─ LogTab         运行日志流（xterm.js + 过滤 + logcat 子开关）  │
│  └─ 热重载按钮（r / R）                                          │
│  SshApi-style fetch → /api/dsh-flutter/*                          │
└───────────────┬──────────────────────────────────────────────────┘
                │ HTTP / WebSocket（任务进度 + 日志流 + 连接状态）
┌───────────────┼──────────────────────────────────────────────────┐
│  host 面（exports "."）                                           │
│  apply(ctx, config)                                               │
│  ├─ AdbManager（移植 cursor-adb-connect 全部逻辑）                │
│  │   ├─ findAdbPath()    3 级探测 + 设置覆盖                      │
│  │   ├─ parseClipboard() 原样移植（pair/connect/裸 ip:port 正则） │
│  │   ├─ pair()/connect()/disconnect()/devices()                   │
│  │   ├─ 轮询监控（间隔可配，默认 10s，0=关）→ 断线事件推送        │
│  │   └─ 最近连接历史（≤8 条，存 ~/.dsh/dsh-flutter.json）         │
│  ├─ FlutterEngine（进程管理）                                     │
│  │   ├─ devices()    flutter devices --machine (JSON)             │
│  │   ├─ build()      flutter build apk [--debug|--profile|--release] │
│  │   ├─ install()    flutter install -d <id>                      │
│  │   ├─ run()        flutter run -d <id>（PTY，r/R 热重载）       │
│  │   └─ logcat()     adb logcat -v time（按包名/进程过滤）        │
│  ├─ routes.ts:   /api/dsh-flutter/* REST + /ws/flutter WebSocket   │
│  ├─ tools.ts:    8 个 agent 工具（见 3.3）                         │
│  ├─ systemPrompt.section: 向 agent 宣告能力与限制                  │
│  └─ settings:    ~/.dsh/dsh-flutter.json（adb 路径/默认设备/      │
│                  轮询间隔/构建模式/日志保留行数/最近连接）          │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 目录结构（参照 dsh-ssh + cursor-adb-connect）

```
packages/dsh-flutter-runner/
├── package.json          # dsh.bundle.patch → cordis.patch.yml；dsh.client.inject/platform
├── cordis.patch.yml      # - insert: - id: flutter-runner, name: @<scope>/dsh-flutter-runner
├── tsconfig.build.json
├── README.md             # 使用说明 + 安全须知
├── src/
│   ├── index.ts          # host 入口：name / inject / apply()
│   ├── engine.ts         # FlutterEngine：spawn 进程管理、输出流解析
│   ├── adb.ts            # AdbManager：移植 cursor-adb-connect（findAdbPath/parseClipboard/pair/connect/disconnect/轮询/历史）
│   ├── protocol.ts       # host↔client 共享类型（DeviceInfo/TaskState/LogLine/ConnectionState/RecentTarget）
│   ├── routes.ts         # /api/dsh-flutter/* 路由 + /ws/flutter WebSocket
│   ├── store.ts          # 配置持久化（~/.dsh/dsh-flutter.json，权限 0600）
│   ├── tools.ts          # agent 工具（defineTool × 8）
│   └── client/
│       ├── index.ts      # 浏览器入口：apply(ctx) → locale + mount
│       ├── api.ts        # 客户端 API 封装（fetch / WebSocket）
│       ├── locales.ts    # zh/en 文案
│       ├── mount.tsx     # DOM 挂载（失败只降级不炸 GUI）
│       ├── sidebar-entry.ts
│       └── panel/
│           ├── FlutterPanel.tsx     # Tab 容器
│           ├── ConnectionTab.tsx    # 无线 ADB（剪贴板粘贴框/一键连接/最近列表/断开/状态徽标/断线告警）
│           ├── DeviceTab.tsx        # 设备列表 + 刷新 + 选择默认设备
│           ├── BuildTab.tsx         # 构建安装流程（模式/进度/取消）
│           └── LogTab.tsx           # xterm 日志 + 过滤 + logcat 开关 + 热重载按钮
└── test/                 # vitest（adb 解析/engine mock）
```

### 3.3 关键技术点

#### (1) 无线 ADB 连接（cursor-adb-connect 完整移植）
- **findAdbPath()**：原样移植 3 级探测（ANDROID_HOME/ANDROID_SDK_ROOT → %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe → PATH），新增设置项可手填覆盖；
- **parseClipboard()**：原样移植三组正则（adb pair <ip:port> <code> / adb connect <ip:port> / 裸 ip:port），支持多行剪贴板同时含 pair+connect；
- **连接流程**：pair（可选）→ connect → adb devices 验证真实 serial → 推送连接状态；
- **轮询监控**：adb devices 间隔轮询（设置可配，默认 10s，0=关闭），检测到断开 → WebSocket 推断线事件 → client 弹告警（复用 slots/通知）+ 一键重连；
- **最近连接历史**：≤8 条（ipPort + lastConnectedAt），存 ~/.dsh/dsh-flutter.json，UI 显示相对时间（刚刚/N 分钟前/N 天前）；
- **断开**：adb disconnect（仅无线），状态复位。

#### (2) 设备枚举
flutter devices --machine JSON 解析，与 adb devices 合并标注连接方式（USB/无线/模拟器）。GUI 与 agent 工具共用同一解析。

#### (3) 构建安装流水线
步骤状态机 idle → building → built → installing → installed → launching；WebSocket 事件 {type: task, state, line} 推进度；child_process spawn + AbortController 取消；超时 kill 进程树（Windows taskkill /T）。

#### (4) 运行与日志流
- flutter run -d <id> 走 node-pty：流式 stdout/stderr + 注入 r/R（热重载）、q（退出）——**agent 对话中可直接说「热重载」**；
- 日志行带时间戳 + 来源标记（build/run/logcat），xterm.js 渲染 + 关键字过滤（error/exception/PlatformException）；
- logcat 子开关：「只看本 App」（adb logcat -v time --pid=$(adb shell pidof <包名>)）；
- WebSocket 断线自动重连 + 日志缓冲重放；会话结束/刷新清理进程。

#### (5) Agent 工具（对齐 dsh-ssh tools.ts 写法）

| 工具 | 功能 | 触发词 |
| --- | --- | --- |
| adb_connect | 从剪贴板或参数配对+无线连接设备 | 无线连接、配对、连手机 |
| adb_disconnect | 断开所有无线连接 | 断开 |
| adb_status | 查询连接状态（设备列表 + 最近连接） | 设备状态、连上了吗 |
| flutter_devices | 列出已连接设备（含 USB/无线/模拟器） | 设备、跑在哪 |
| flutter_build_install | 按模式构建并安装到指定设备 | 构建、安装、部署到手机 |
| flutter_run | 启动 app 并持续输出日志（后台） | 跑起来、运行、看日志 |
| flutter_stop | 停止当前运行实例 | 停掉、退出 |
| flutter_logs | 拉取最近 N 行日志（run 缓冲 / logcat） | 日志、报错 |

工具在 ctx.systemPrompt.section 宣告（含「无线连接/构建消耗真实资源，先确认再操作」）。

#### (6) 配置与安全
- ~/.dsh/dsh-flutter.json：adb 路径、默认设备、轮询间隔、构建模式、日志保留行数、最近连接历史；
- 设置页 installSettingsSection（schemastery schema），修改即时生效；
- flutter/adb 执行属 shell 类操作，受 DSH 权限策略约束（当前 danger-full-access）；
- 长驻进程（run/轮询）在插件卸载/会话结束时清理。

### 3.4 安装与分发

```bash
# 开发期：本地 link 安装
dsh plugin --profile web add link:<仓库>/packages/dsh-flutter-runner
# 发布后：npm 安装
dsh plugin --profile web add @<scope>/dsh-flutter-runner
# 或并入 linxin666 全家桶（向其 dsh-web-ui 仓库提 PR）
```

发布规范：dsh.bundle.patch 声明；README 写清能力/限制；GitHub 加 dsh-plugin topic；npm files 含 lib/ + src/ + cordis.patch.yml。

## 4. 开发里程碑

| 里程碑 | 内容 | 验收标准 | 预估 |
| --- | --- | --- | --- |
| M0 脚手架 | pnpm 工程 + tsdown 双面空壳 + cordis.patch.yml + link 安装 | dsh web 无报错，侧边栏出现空面板 | 0.5 天 |
| M1 ADB 无线连接 | 移植 cursor-adb-connect：adb.ts + ConnectionTab + adb_* 工具 | 粘贴手机配对信息一键连上 25060RK16C；断线告警+重连；历史持久化 | 1 天 |
| M2 host 引擎 | 设备枚举 + build/install/run 进程管理 + 日志缓冲 | CLI 直测 engine：完成一次 debug 构建安装 | 1 天 |
| M3 路由与流 | /api/dsh-flutter/* + WebSocket（任务进度 + 日志流 + 连接状态） | curl 验证 REST；console 验证 ws 三路消息 | 0.5 天 |
| M4 agent 工具 | 8 个工具 + prompt 段 | 对话中说「无线连接手机」「构建安装到手机」agent 闭环 | 0.5 天 |
| M5 client UI | Device/Build/Log Tab + 热重载按钮 + 断线告警 UI | 真机全流程：无线连接 → 点按钮 → 装到手机 → 日志滚动 → 热重载 | 1 天 |
| M6 打磨发布 | 设置页、logcat 过滤、错误处理、README、npm 发布 | 无孤儿进程；断线重连；可卸载重装 | 0.5 天 |

总计约 **5 个工作日**（单人）。

## 5. 风险与对策

| 风险 | 对策 |
| --- | --- |
| DSH 开发者预览期 API 破坏性变更 | 锁定 peerDependencies（0.1.0-rc.6 系）；升级前 typecheck + 冒烟 |
| flutter run / 轮询长驻进程 | PTY + 进程树 kill + 插件卸载钩子清理 |
| Windows 环境差异（adb 不在 PATH） | 移植 3 级探测 + 设置手填 |
| 无线连接不稳定（断线） | 轮询监控 + 告警 + 一键重连 + 历史 |
| 多设备/模拟器切换 | 设备下拉 + 记忆上次选择 |
| WebSocket 断线 | 自动重连 + 缓冲重放 |
| 构建时间长 | 后台任务 + 进度事件 + 可取消 |
| 剪贴板解析误判 | 沿用 cursor-adb-connect 正则（已实战验证），失败给出明确提示 |
| 安全（命令执行权限） | 沿用 DSH 权限策略；prompt 段明示消耗与确认 |

## 6. 参考实现（本机可直接阅读）

| 参考 | 位置 | 借鉴点 |
| --- | --- | --- |
| **cursor-adb-connect** | D:\Users\34045\Desktop\cursor\cursor-adb-connect\extension.js | **ADB 全套逻辑原样移植**（findAdbPath/parseClipboard/pair/connect/轮询/历史/断线处理） |
| dsh-ssh | ~/.dsh/profiles/web/node_modules/@linxin666/dsh-ssh/src/ | 双面结构、engine/routes/tools、侧边栏挂载、WebSocket 终端、settings |
| dsh-ssh client/panel/TerminalTab.tsx | 同上 | xterm.js 接入与 ws 协议 |
| dsh-client-ui-task-board | node_modules/@linxin666/dsh-client-ui-task-board/ | 纯 client 插件挂载 |
| 官方能力接缝 | D:\Users\34045\AppData\Local\Programs\DeepSeek Harness\resources\host\node_modules\@deepseek-ai\dsh-{shell,terminal,subprocess,jobs,tools,host-webserver,settings} | 服务定义与用法 |
| 官方开发指南 | github.com/deepseek-ai/deepseek-harness/blob/master/docs/development.md | Host/Client 双聚合、构建约定 |

## 7. 后续扩展（V2）

- DAP 断点调试（对接 dart debug adapter）；
- iOS/桌面目标支持；
- dart-mcp-server 联动（热重载 + analyze 一键）；
- 构建产物管理（APK 归档/分享）；
- 并入 linxin666 全家桶统一维护。

## 8. 决策清单（待确认）

1. 独立仓库 or 并入 dsh-web-ui 全家桶？
2. npm scope 用什么？（需 npm 账号；或先本地 link 自用）
3. 无线 ADB 的轮询间隔默认值？（沿用 10s，还是更快 5s）
4. V1 是否含 logcat tab？（含则多 0.5 天）
5. 断线告警形式：面板内 toast 还是系统通知（dsh-session-notification 风格）？
