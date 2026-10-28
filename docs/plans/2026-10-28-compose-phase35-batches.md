# Compose 迁移 · Phase 3.5 可并行批次表（供多会话领取）

> 状态：**生效中**（2026-10-28 建立）
> 上游：[Phase 3.5 接线与装配计划](2026-10-28-compose-phase35-wiring-plan.md) · [数据契约](2026-10-26-data-contract.md) · [Phase 3 页面台账](2026-10-26-compose-phase3-page-ledger.md)
> 用途：让**多个独立会话**（Cursor / Claude Code / DSH 子代理）同时干活而不互相撞车。

---

## 0. 先读这四份（10 分钟，别跳）

1. 仓库根 `AGENTS.md` —— 设备铁律 / 编译分工 / 测试策略 / Git 协作 / 进程清场；
2. 本文件 §1（领取规矩）与你要领的那一行；
3. [Phase 3.5 计划](2026-10-28-compose-phase35-wiring-plan.md) —— 分层的定义与验收门槛；
4. [数据契约](2026-10-26-data-contract.md) —— 只有碰数据的批次需要，但**写错就是用户数据丢失**。

---

## 1. 领取规矩（三步，别省）

1. `ls .agents/compose-phase3/claims/` —— **有文件的批次 = 有人在做，别碰**；
2. 挑一个**没有认领文件**的批次，新建 `.agents/compose-phase3/claims/<批次号>.md`，
   写上会话名、开始时间、写作用域。**文件创建是原子操作**：两个人同时抢只有一个能成功；
   文件已存在就换一个，**绝不删改别人的认领文件**；
3. 只在本批次给的**写作用域**里写文件。别人的在途改动（`git status` 里的 `M` / `??`）一律不碰。

**失联回收**：认领文件里写「最后更新」。超过 **24 小时**没更新，任何人可在文件末尾追加
`> [申请回收] <时间> <会话名> <理由>` 并知会 Lead；**严禁直接删除或覆盖**。

---

## 2. 批次表（每个会话只领一个）

| 批次 | 内容 | 规模 | 写作用域 | 依赖 |
|---|---|---|---|---|
| **P35-B1** | 二维码生成器（纯逻辑，解锁二维码发送页） | 中 | `main/.../share/qr/`、`test/.../share/qr/` | 无 |
| **P35-B2** | 地点时间匹配**编辑页**（Phase 3 遗留，Dart 约 760 行） | 大 | `main/.../pages/time_scheme/`、`composeP1/.../pages/time_scheme/`、`test/.../pages/time_scheme/` | 无 |
| **P35-B3** | 统计族骨架补齐：成就详情弹层 + 周视图 | 中 | `main/.../pages/statistics/`、`composeP1/.../pages/statistics/`、`test/.../pages/statistics/` | 无 |
| **P35-B4** | 网络图片加载层（Bing 壁纸 / 打赏二维码） | 中 | `main/.../platform/`、`main/.../app/imagecache/`、`test/.../app/imagecache/` | 无 |
| **P35-B5** | 相机扫码：帧预算/节流/结果去重 + 相机槽位契约（可测部分） | 中 | `main/.../share/camera/`、`test/.../share/camera/` | 无 |

**已经在跑、不要重复领的**（2026-10-28 11:30 状态；以 `ls .agents/compose-phase3/claims/` 为准）：

| 批次 | 谁 | 认领文件 | 写作用域 |
|---|---|---|---|
| P35-1a 课表数据层 | `cap-webdav` | `P35-timetable-store.md` | `main/.../app/`、`main/.../platform/`、`test/.../app/` |
| P35-1b 课表宿主层 | `gap-live` | `P35-timetable-host.md` | `composeP1/.../app/`、`main/.../app/TimetableHostLogic.kt` |
| P35-LAN2 局域网第二切片 | `cap-webview` | `GAP-lan.md` | `main/.../transfer/lan/`、`test/.../transfer/lan/` |

> ⚠️ **P35-1a 占着 `main/.../app/` 与 `main/.../platform/` 的顶层文件**。
> P35-B4 若要用这两处，**只能新建子目录** `app/imagecache/` 与 `platform/` 下的**新文件**，
> 文件名不许与 1a 的重名。有疑问先问 Lead。

---

## 3. 各批次的详细要求

### P35-B1 · 二维码生成器

**为什么**：`pages/transfer/QrTransferSendPage.kt` 的二维码是「宿主槽位」（必传参数），
全仓**没有**编码器，所以这一页的二维码位置永远空着——目录里因此标着「暂不可用：缺宿主槽位」。

**做什么**：在 Kotlin 侧实现二维码**编码**（Dart 侧用的是 pub `qr` 包，
参照物 `lib/services/qr_transfer/qr_transfer_codec.dart`，775 行，只读不许改）。

- 纯逻辑、**零新依赖**、JVM 可测；
- 必须能与 Dart 侧**逐位对拍**：同一个字符串 → 同样的模块矩阵。
  Dart 的 `qr` 包是标准 QR（版本 1–40，纠错等级 L/M/Q/H，模式自动选择）；
  先支持项目实际用到的组合（看 `qr_transfer_codec.dart` 用的是哪些版本与纠错等级），
  其余组合要么实现要么**明确列出未支持**；
- 交付 `main/.../share/qr/QrEncoder.kt`（名字可调，但要在认领文件里写明最终路径）。

**验收**：L0 全绿（`pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/transfer" -ExtraSources "<你的测试文件>"`，
因为 `share/` 是共享目录会被自动收录）；测试必须含**手推的期望矩阵**
（例如 `"A"` 在版本 1-L 下的定位图形与校验码），不是从实现里抄的；
咬合探针一次（改坏 → 红 → 还原 → 绿）。

### P35-B2 · 地点时间匹配编辑页

**为什么**：`l4-recon` 记「约 760 行编辑页留下一批未做」，页面上「编辑」点进去是空的。

**做什么**：照 Dart `lib/screens/location_time_match_screen.dart` 把编辑页补齐
（模型层 + 渲染层 + 文案逐字对拍 ARB）。**Dart 只读，不许改。**

**验收**：L0 全绿 + L1
（`pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin -x :app:compileFlutterBuildComposeUiDebug`）
`e:` 0 条落在你文件上 + 文案对拍 + 咬合探针。

### P35-B3 · 统计族骨架补齐

**为什么**：台账 §4.1 第 1/4/5 条：统计的六张分析卡只有读数行没有图（**另一条泳道已补**）、
成就徽章点不动、周视图只有门数与课时。

**做什么**（**先核实哪些还没做**，别重复劳动）：
1. 成就徽章的**详情弹层**（Dart `showAchievementDetailSheet`）；
2. 统计「周视图」（Dart `week_stats_view.dart`，490 行）。

**验收**：同 B2。

### P35-B4 · 网络图片加载层

**为什么**：台账 §4.3 第 5 条——Bing 壁纸画廊、打赏二维码图**都没有图片加载层**，
界面上是空白或一直转圈。

**做什么**：
- 纯逻辑部分（缓存键、并发去重、失败退避、尺寸选择）放 `main/.../app/imagecache/`（**纯 Kotlin，JVM 可测**）；
- Android 部分（真下载 + 解码 + 内存缓存）放 `main/.../platform/` 下的**新文件**；
- **不许加 gradle 依赖**（要 Coil 之类先问 Lead）；
- 至少打通一处调用点：Bing 壁纸画廊或打赏二维码（**只改那一处，别顺手改别的页**）。

**验收**：纯逻辑 L0 全绿 + 咬合探针 + `safe-gradle :app:compileProdDebugKotlin` 零 `e:`。

### P35-B5 · 相机扫码（可测部分）

**为什么**：台账 §4.3 第 1 条——全仓没有 CameraX / MLKit / 任何扫码依赖，
扫码页的相机是宿主槽位，扫不出。

**做什么（本批只做不需要新依赖的部分）**：
- 帧预算与节流（多久解一帧、丢帧策略）、同一码的**结果去重**（连续命中要合并成一次回调）、
  权限状态机、相机槽位的**契约定义**（宿主注入什么、页面要什么）；
- 放 `main/.../share/camera/`（纯逻辑）+ 测试；
- **同时产出一份「依赖需求清单」**：需要哪个库、多大、minSdk 影响、替代方案（
  例如 `zxing-core` + CameraX vs MLKit barcode）。**加依赖是 Lead 的事**，你不许改 `build.gradle`。

**验收**：纯逻辑 L0 全绿 + 咬合探针 + 依赖清单写进认领文件。

---

## 4. 全体共同纪律（违反会拖累所有人）

### 4.1 编译与验证（省资源）

| 级别 | 命令 | 谁能跑 |
|---|---|---|
| L0 模块单测 | `pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/<域>"` | 所有人，**最高频** |
| L1 编译验证 | `pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin -x :app:compileFlutterBuildComposeUiDebug` | 所有人，**每批交付一次** |
| L2 单测 | `pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:testProdDebugUnitTest` | 攒够再跑 |
| L3 出包 / L4 真机 | —— | **只有用户**，agent 禁止 |

- **禁止**裸跑 `./gradlew`（必须走 `safe-gradle.ps1`，它带全机互斥锁，排队是正常的）；
- **禁止** `flutter build *` / `assemble*` / `bundle*` / `adb install` / 任何真机操作
  （仓库设备铁律：未经用户明确允许不许碰真机）；
- L0 一次约 **800 MB 峰值内存**，**别在循环里刷**，也别同时开多个模块；
- **L0 绿 ≠ CI 绿**：L0 用完整 JDK，Gradle 单测用 AGP 裁剪过的 API 集。
  **测试里用了 `com.sun.*` / `sun.*` 的，L0 全绿也必须在 Gradle 任务里再验一次**
  （2026-10-28 真踩过：L0 156 例全绿、CI 直接编译失败）。安全区：`java.net.*` / `java.nio.*` /
  `java.util.*` / `javax.net.ssl.*` / `javax.xml.parsers.*`。

### 4.2 共享模型层：写盘即生效于全队

`scripts/test-kotlin-module.ps1` 会把 `app` / `core` / `sync` / `share` / `transfer` /
`statistics` / `theme` 等目录**无条件**收进每一次 L0；它们在 `main` 源集里，
Gradle 的 `:app:compileProdDebugKotlin` 也收。⇒ **在这些目录里留一行编译错误，
全队所有泳道的 L0 与 CI 单测一起红。**

**做法**：写完一段就跑一次自检，别攒到最后；一个文件要么不落盘，要么落成可编译的。

### 4.3 Git

- 提交走**路径限定**：`git add -- <你的路径>` 然后 `git commit -- <你的路径>`（新文件必须先 `add`）；
  **禁止** `git add .` / `-A` / `commit -am`；
- 只暂存自己负责的路径；暂存区已有别人的内容就**不要动**，也别清空；
- **禁止破坏性命令**：`reset --hard` / `checkout -- .` / `clean -fd` / `push --force`；
- 提交信息用中文说清「改了什么 + 为什么」；
- `pre-commit` 钩子偶尔卡死（持 `.git/index.lock` 挡住全仓提交）：先按 `AGENTS.md` 的判据
  采样两次 CPU 确认它真死了，再杀整条链（`dartaotruntime` → `dartvm` → `sh` → `git`）；
  **不要手删 `.git/index.lock`**；跳过钩子要 `--no-verify` 并**补跑**
  `flutter test --no-pub test/architecture/`。

### 4.4 认领文件是你的唯一凭据

不写认领文件就开工 = 抢活；写完不更新 = 别人无法判断进度。
交付时把**证据**写进去：命令原文 + 原始输出尾部 + 咬合探针的红/绿两次输出 + 诚实清单。

---

## 5. 交付模板（照抄进认领文件）

```markdown
# 认领：P35-B<x>
- 状态：进行中 / 已交付
- 会话：<你的名字>
- 开始 / 最后更新：<时间>
- 写作用域：<逐条列出>

## 交付
| 文件 | 行数 | 说明 |

## 证据
- L0：<命令> → <原始输出尾部>
- L1：<命令> → <e: 条数>
- 咬合探针：改坏了什么 → 红在哪 → 还原后是否逐字节一致

## 诚实清单（没做的 / 只到「编译过」的）
```

---

## 关联

- [Phase 3.5 接线与装配计划](2026-10-28-compose-phase35-wiring-plan.md)
- [数据契约](2026-10-26-data-contract.md) · [Phase 3 页面台账](2026-10-26-compose-phase3-page-ledger.md)
- [L4 真机对照清单](2026-10-27-compose-phase3-l4-checklist.md)
