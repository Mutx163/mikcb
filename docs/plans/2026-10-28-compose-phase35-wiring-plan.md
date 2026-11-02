# Compose 迁移 · Phase 3.5 接线与装配（新增阶段）

> 状态：**生效中**（2026-10-28 建立）
> 上游：[迁移计划](2026-10-26-compose-migration-plan.md) · [数据契约](2026-10-26-data-contract.md) · [Phase 3 页面台账](2026-10-26-compose-phase3-page-ledger.md)
> 起因：用户实机反馈「好多页面是空壳、按钮点了没反应」。

> **2026-11-02 现状回填（只改状态与过期结论，保留 2026-10-28 的规划与理由）**
>
> | 本文当时的结论 | 现在 | 证据（2026-11-02 复核） |
> |---|---|---|
> | §0 表：正式包仍是 `MainActivity : FlutterActivity` | 正式包启动页已切到 Compose 壳 `PagesShellActivity`；回退方式写在 `main/AndroidManifest.xml:159-160`、`:191-193` 注释里 | `1158ee20` |
> | §2 L5：壳里「课表 tab 用真宿主；其余页仍走演示数据」 | 已过期：`b.*` 25 条与课程/统计/同步/导入导出等页面均已接真宿主，逐包状态见派工大表 §二 | 派工大表（2026-11-01 / 11-02 复核） |
> | §3 第 6 条：L1 = `:app:compileComposeUiDebugKotlin` | 变体已不存在；现行闸门是 `:app:compileDevDebugKotlin` / `:app:testDevDebugUnitTest` | 台账 §0 顶部「2026-10-29 变体清理」 |
>
> **接线期后续状态（不属于本文 2026-10-28 的范围）**：教务抓课写回已交付（`83e8426a`，剩余原生 confirm/prompt/单选/保存配置）；统计点课进课程编辑已交付（`58057a9c`）；Compose 壳通知权限与点击路由已交付（`bd1bbeb0`）；云备份恢复撤销 UI 已交付（`bc0a02c6`，恢复前差异预览仍无）；局域网撤销点/真实 `transferId` 与单节课提醒 `classReminders` 均为**工作区已实现、未提交**（2026-11-02）。

---

## 0. 为什么要有这个阶段（不是新需求，是原计划漏了一段）

原计划的阶段划分是：

| 阶段 | 内容 |
|---|---|
| Phase 3 | UI 层移植（页面 + 逻辑） |
| Phase 4 | 原生能力对齐（小组件 / 超级岛 / 保活 / 前台服务 / 通知） |
| Phase 5 | 收尾：删 Flutter |

**从「页面移植完」直接跳到「删 Flutter」，中间没有「把页面接上真实数据与导航」这一段。**
于是 Phase 3 交付的 78 屏全是「纯函数 + 数据入口」形态：

- 模型层只算「给定状态长什么样」，**不持有状态**；
- 渲染层只负责画，**点了之后写到哪由宿主决定**；
- 而宿主（数据层 / 装配 / 导航）**在仓库里不存在**。

可核实的证据（2026-10-28 实测）：

| 事实 | 数字 | 出处 |
|---|---|---|
| 壳分派层里的空回调 | **137 处**（78 个分支） | `composeUi/.../ShellPageIndex.kt` |
| 几乎完全惰性的分支 | 19 个（云同步 16 处、加考试 14 处、导出 10 处…） | 同上 |
| 数据端口有没有实现 | `TimetableCoursePort` 是接口，**全仓 0 个实现** | `main/.../course/TimetableCoursePort.kt` |
| 正式包用的什么 | ~~`MainActivity : FlutterActivity`（**仍是 Flutter**）~~（2026-10-28 当时事实；**已由 `1158ee20` 取代**，2026-11-02：正式包启动页 = `PagesShellActivity`，回退写在 `main/AndroidManifest.xml:159-160`） | `main/.../MainActivity.kt`、`main/AndroidManifest.xml:154-175` |
| 页面本身有没有死控件 | 设置族 167 个控件里 157 个写了 `action`；余 9 个是**故意只读**（禁用行 / 日志行 / 表头） | 配平扫描，见台账 §9.5 |

⇒ **页面没做坏，是页面还没被接上。**

---

## 1. 本阶段目标与做法

**目标**：把「画好的页面」接成「能用的 App」，按**域**竖切，每个域走完整链路：

```
盘上数据（冻结格式） → 存储层 → 仓储（持有状态 + 落盘 + 通知） → Compose 宿主 → 页面
                                                                    ↑            ↓
                                                                    └── 回调（增删改 / 导航）
```

**先做一条竖切，不要横着铺。** 选课表族：它是首页、最核心，且能一次验证
「读 → 显示 → 改 → 回写 → 再读」的全链。这一条走通，其余域照抄接法。

---

## 2. 分层与写作用域

| 层 | 落点 | 内容 | 谁写 |
|---|---|---|---|
| L1 存储抽象 | `main/.../app/KeyValueStore.kt` | 冻结格式的键值读写接口 + 内存实现（供 JVM 测试） | Lead（**已定稿，签名冻结**） |
| L1b 存储实现 | `main/.../platform/PrefsKeyValueStore.kt` | Android 实现：`FlutterSharedPreferences` + `flutter.` 前缀 + `FlutterPrefsCodec` | 泳道 |
| L2 领域存储 | `main/.../app/TimetableStore.kt` | 课表相关 key 的 JSON 编解码（`timetable_profiles` 等），损坏值留档自愈 | 泳道 |
| L3 仓储 | `main/.../app/TimetableRepository.kt` | 持有状态、实现 `TimetableCoursePort`、变更即落盘并通知 | 泳道 |
| L4 宿主 | `composeP1/.../app/TimetableHost.kt` | Compose：把仓储接到 `TimetableWeekPage` 等页面上 | 泳道 |
| L5 壳接线 | `composeUi/.../ShellPageIndex.kt` + `PagesShellActivity.kt` | 课表 tab 用真宿主；其余页仍走演示数据（**2026-11-02 已由后续接线批次取代**，见文首回填表与派工大表 §二） | **Lead 专属** |

**写作用域互斥**：L1/L2/L3 在 `main/.../app/`，L1b 在 `main/.../platform/`，
L4 在 `composeP1/.../app/`，L5 是 Lead 区。四层互不重叠；同一目录内按**文件**互斥。

> ⚠️ **`app/` 必须保持纯 Kotlin**（无 `android.*` / `androidx.compose.*` / miuix 导入）。
> `scripts/test-kotlin-module.ps1` 的纯 Kotlin 判定是**整目录**的：只要有一个 `.kt` 引了
> `android.*`，整个 `app/` 会被静默跳过，表现为「测试里 app 的符号全都 Unresolved」。
> **Android 胶水（Context、Activity、WebView 之类）一律放 `platform/`。**
> 2026-10-28 已把 `app` 加进该脚本的 `sharedModelDirs` 名单。
>
> ⚠️⚠️ **`app/` 不许 import 任何 `com.mutx163.qingyu.pages.<域>`。**（2026-10-28 补，已加机器守卫）
>
> 这是上一条的**推广形式**，也是同一天踩了**三次**的坑（`sync/`、`transfer/`、`app/`）。
> 推导很短：`app/` 在 `sharedModelDirs` 里 ⇒ **被每一次 L0 无条件收录**；
> 而 `pages/<域>` 只在 `-Module <那个域>` 时才收 ⇒ 一旦 `app/` 引用了它，
> **除那个域以外的所有模块的 L0 都会红，且报错文件是 `app/` 里那一个**——
> 别人看到的是「我的模块编译不过」，根本查不到源头。
> 最坏的一次红了 **2 小时 40 分**（`AddTaskFormReducer` 引用 `pages.task`），代价由所有泳道一起付。
>
> **规则要写不变量，不要写当时那个例子**：最初我只写了「不许 import `pages.settings.*`」
> （那是我踩坑时看到的实例），下一个人只记住例子，换成 `pages.task` 又踩一次。
>
> **怎么修**：把文件搬进它依赖的那个 `pages/<域>/` 目录（L0 源集**按目录**收集，
> 搬进去后只有那个模块会编它）。**包名可以保持不变**，这样不会打断引用方的 import。
>
> **机器守卫**：`test/.../app/AppLayerPurityTest.kt` 扫描 `main/.../app/**/*.kt`，
> 断言①无 `import com.mutx163.qingyu.pages.`、②无 Android/Compose/miuix 导入、
> ③扫描器必须真的扫到 ≥5 个文件（否则路径写错时守卫会静默变绿）。
> 探针已验证：塞一个 `import ...pages.task.X` 并跑 `-Module pages/task`（此时两边都在源集里、
> **编译得过**，正是守卫要防的场景）⇒ 守卫红并打印违规行；删除后复绿。

### 2.1 源集边界（2026-10-28 踩过两次，写死在这里）

| 目录 | 谁编译得到 | 能被谁引用 |
|---|---|---|
| `src/main/kotlin/...` | 所有变体（含 prod 单测） | 谁都能引 |
| `src/composeP1/kotlin/...` | **只有 compose 变体** | `src/composeUi/**`、`src/composeP1/**` 能引；**`src/test/` 引不到** |
| `src/test/kotlin/...` | **所有变体共享** | 只能引 `main` 里的东西 |
| `src/testComposeUi/kotlin/...` | 只有 compose 变体 | 能引 `composeP1` 里的东西 |

**判别顺序（照做就行）**：
1. 先问「这个文件有没有 `android.*` / `androidx.compose.*` / miuix 导入？」
   —— **没有就是纯逻辑，放 `main/`**；有才考虑 `composeP1/`。
2. 再问「有没有 `src/test/` 下的测试要引它？」
   —— 有的话，它**必须在 `main/`**；否则测试要挪到 `src/testComposeUi/`。

**两次实例（都是同一类错，代价都是全队 CI 红）**：
- 2026-10-27 `QingyuTextStylesTest` 放 `src/test/` 却引 `composeP1` 的 `buildQingyuTextStyles`
  → prod 单测编译失败，红了一整晚（`2cec8462` 修复）。
- 2026-10-28 `SettingsPageBridge.kt` 放 `composeP1/`（**纯 Kotlin，0 个 Compose import**）
  却引不到——`src/test/` 下的 `SettingsActionDispatcherTest` 要用它，11 条 Unresolved。
  已搬到 `main/`（包名不变，import 无需改）。

**禁止**：改 `pages/**` 的模型层与渲染层（那是 Phase 3 的交付物，本阶段只接线）、
改 `lib/**`（Dart 是参照物）、改 `build.gradle`（Lead 挂载）。

---

## 3. 第一条竖切（课表族）的验收门槛

1. **真数据**：壳里课表 tab 显示的是**壳自己存储里的**课表，不是演示数据；
2. **真写回**：点「加课」→ 落盘到 `timetable_profiles`（**冻结格式，v1 布局**）→ 首页立刻显示；
3. **真持久**：杀进程重开，课还在；
4. **JVM 测试**（L0）：
   - `KeyValueStore` 内存实现的语义（含 `List<String>` 4 个生产 key 的逐字节编码往返）；
   - `TimetableStore` 的读/写/损坏值留档自愈；
   - `TimetableRepository` 的 add / update / delete / 切换档案 / 变更通知；
   - 期望值必须**人推**，不许从实现里抄；
5. **咬合探针**：至少一次「改坏 → 红 → 还原 → 绿」；
6. **L1 编译**：`safe-gradle :app:compileComposeUiDebugKotlin -x :app:compileFlutterBuildComposeUiDebug` 绿，`e:` 0 条。

> **诚实边界**：本阶段只到「能编译 + JVM 单测 + 壳里肉眼可见」。
> 真机上读**正式版**的用户数据（覆盖安装）属 Phase 5 的验收，本阶段不做。

---

## 4. 冻结格式的三条硬约束（写错就是用户数据丢失）

1. 文件名 `FlutterSharedPreferences`，**所有 key 带 `flutter.` 前缀**（Kotlin 侧必须显式加）；
2. `List<String>` 必须走 `FlutterPrefsCodec`（`ObjectOutputStream` + `Base64.getMimeEncoder(76, "\n")`），
   **本仓 4 个生产 key 用它**：`courses`（legacy 只读）、`teacher_records`、`location_records`、
   `warehouse_recent_school_ids`；
3. 读到损坏值要**留档再删**（`{key}_corrupt_backup_{微秒时间戳}`），不许静默吞掉——
   与 Dart `storage_service.dart:557-576` 同口径。

细则见[数据契约](2026-10-26-data-contract.md) §1。

---

## 5. 后续（本阶段之后）

| 批次 | 内容 |
|---|---|
| 3.5-b | 第二个域竖切（建议设置族，因为它一份渲染层服务 20 页） |
| 3.5-c… | 其余域按同一套接法铺开（课表 → 设置 → 统计 → 导入导出 → 同步 → 诊断…） |
| Phase 4 | 原生能力对齐：相机 / 局域网 / WebDAV 接线 / 网络图片 / 通知与小组件换掉 Flutter 通道 |
| Phase 5 | 删 Flutter，换正式包（**回退窗口在此之前保持开启**） |

---

## 关联

- [迁移计划](2026-10-26-compose-migration-plan.md) · [数据契约](2026-10-26-data-contract.md)
- [Phase 3 页面台账](2026-10-26-compose-phase3-page-ledger.md) · [L4 真机清单](2026-10-27-compose-phase3-l4-checklist.md)
