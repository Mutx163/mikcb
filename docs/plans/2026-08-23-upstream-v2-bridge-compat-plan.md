# 上游 shiguang_warehouse V2 升级分析与轻屿兼容方案

> 日期：2026-08-23
> 上游变更：XingHeYuZhuan/shiguang_warehouse 于 2026-08-23 完成「适配协议 v1 → v2」（PR #467 桥接接口升级 + PR #468 协议版本升级）
> 影响面：mikcb 教务导入桥接层（lib/screens/course_import_screen.dart）、Mutx163/qingyu_warehouse 同步管线

---

## 一、上游为什么要做这次升级（证据）

1. **根本动因：Kotlin Multiplatform 多平台化。**
   shiguangschedule v2.0.0（2026-08-16）发布说明明确列出：「迁移项目架构至 Kotlin Multiplatform (KMP)」「将 ui 迁移至 shared 模块以支持 KMP」「迁移数据库层至 KMP」「迁移 Git 实现至 KGIT」。App 不再只是 Android 应用，`AndroidBridge` 这种平台绑定命名在 iOS/桌面目标上是错误的。官方 wiki《适配更新日志》原话：「**移除平台特定标识，支持多平台**」。

2. **桥接命名规范化。**
   v1 时代各脚本写法不统一：有的裸用全局 `AndroidBridge.showToast(...)`，有的用 `window.AndroidBridgePromise.showSingleSelection(...)`。v2 统一为 `window.shiguangBridge` / `window.shiguangBridgePromise`，wiki 说明：「文档统一添加 `window.` 前缀，保证兼容性」。

3. **刻意做到接口零变化，降低迁移成本。**
   wiki 原话：「业务接口功能**完全不变**（showAlert、saveImportedCourses 等均保持一致）；仅对象名称变更，数据结构无需调整」。因此上游能用单个 PR（1fe584cc）批量改写约 150 个适配脚本，且此前预告「将通过迁移程序升级仓库里面的现有适配」。

4. **索引协议顺带正式化。**
   - `scripts/build_data.py`：`PROTOCOL_VERSION = 1 → 2`；
   - 索引改由固定孤立分支 **index-pb-release** 上的 `school_index.pb`（Protobuf）承载，软件只需拉取该文件 + `resources/**` 下所有 *.js；
   - 取消「仓库需保留 lighthouse 标签」的识别要求；
   - 与 KMP/KGIT 的仓库同步改造相呼应（git 同步 + 二进制索引，替代逐个 HTTP 拉 yaml）。

## 二、升级前后差异对照

| 维度 | v1（升级前） | v2（升级后） |
| --- | --- | --- |
| 同步桥对象 | `AndroidBridge` / `AndroidBridgePromise`（裸全局与 `window.` 混用） | `window.shiguangBridge` / `window.shiguangBridgePromise` |
| 方法与数据结构 | showToast / notifyTaskCompletion / showAlert / showPrompt / showSingleSelection / saveCourseConfig / savePresetTimeSlots / saveImportedCourses | **完全不变** |
| 索引载体 | main 分支 `index/root_index.yaml` + `resources/*/adapters.yaml`（YAML） | 孤立分支 index-pb-release 的 `school_index.pb`（`scripts/build_data.py` 编译，协议版本 2） |
| 仓库识别 | 要求保留 `lighthouse` 标签 | 已取消 |
| 配套 App | shiguangschedule < v2.0.0 | ≥ v2.0.0 |

## 三、兼容性矩阵（老用户到底受不受影响）

| 组合 | 结果 | 说明 |
| --- | --- | --- |
| 旧 App × 旧脚本(v1) | ✅ 正常 | 现状不变 |
| 新 App × 旧脚本(v1) | ✅ 正常（需做 A 层） | 新 App 同时注入两套桥名即可 |
| 新 App × 新脚本(v2) | ✅ 正常（需做 A 层） | 同上 |
| **旧 App × 新脚本(v2)** | ❌ **必坏** | 旧 App 只注入 `AndroidBridge`，v2 脚本调 `window.shiguangBridge.*` 直接 undefined 抛错，toast/选择弹窗/课表保存全部失效 |

**关键事实链**：旧版 mikcb 从我们自己的复刻仓库 Mutx163/qingyu_warehouse 拉取脚本（非直连上游）。qingyu_warehouse 配有 `sync-upstream.yml`（每天北京时间 09:00 自动同步上游 + `scripts/sync_upstream.py` 校验，退出码 3=兼容性拦截 / 4=警告需人工）。当前 main 上脚本仍是 v1（最后同步 2026-08-23 02:22 UTC，早于上游 08:13 的 v2 合并）——**下一次自动同步就会把 v2 脚本带进 main，届时所有旧版 App 的教务导入立即开始坏**。

结论：「同步升级后旧版还能不能用」完全取决于我们在 qingyu_warehouse 同步管线里做什么——什么都不做就会坏；加一层自动垫片（B 层）就能让旧版继续用，无需强制升级。

## 四、方案设计（三层）

### A 层：mikcb App 端「双桥注入」（改动最小，一次解决新旧脚本双向兼容）

位置：`lib/screens/course_import_screen.dart` `_executeImportScript()` 内 wrappedScript 注入段（约 L4263 起）。

做法：保持现有 QingyuBridge 实现体不变，在其后追加两个别名与一条幂等反向垫片：

```js
// 现有：window.AndroidBridge = {...}; window.AndroidBridgePromise = {...};
window.shiguangBridge = window.AndroidBridge;
window.shiguangBridgePromise = window.AndroidBridgePromise;
// 幂等反向垫片：防止个别脚本/环境只定义了一侧
window.AndroidBridge ||= window.shiguangBridge;
window.AndroidBridgePromise ||= window.shiguangBridgePromise;
```

要点：
- 本地调试脚本路径（debugScriptOverride）走同一个 wrappedScript 入口，天然一并覆盖；
- 方法集合 v1/v2 完全一致（官方承诺结构不变），无需新增任何方法实现；
- 验收：以上游 `GLOBAL_TOOLS/school.js`（组件测试脚本）在 WebView 手测 toast / confirm / singleSelection / saveCourseConfig / savePresetTimeSlots / saveImportedCourses 全链路。

### B 层：qingyu_warehouse 同步管线「自动兼容垫片」（保住存量旧版用户，本方案核心）

在 `scripts/sync_upstream.py` 写入每个同步来的 *.js 前，自动前置一段生成垫片：

```js
/* qingyu-compat-shim v2:auto-generated, do not edit */
(function () {
  if (typeof window === 'undefined') return;
  if (!window.shiguangBridge && window.AndroidBridge) window.shiguangBridge = window.AndroidBridge;
  if (!window.shiguangBridgePromise && window.AndroidBridgePromise) window.shiguangBridgePromise = window.AndroidBridgePromise;
})();
```

要点与坑：
- 垫片方向是「新名字 → 旧实现」，正好补上旧 App 缺失的一侧；对新 App（A 层已双侧注入）幂等无害；
- **垫片改变文件字节 → 索引里的 sha256 必须按垫片后的最终内容重算再写入**。mikcb 端 `lib/services/warehouse_repository_service.dart`（fetchAdapterScript，L126–140）对声明了 sha256 的脚本强制校验，不匹配直接拒载——这一步漏掉会让新 App 反而拉不到脚本；
- `tests/test_warehouse_upstream_compat.py` 增加用例：① 同步产物每个 *.js 头部含垫片标记；② adapters.yaml/pb 中 sha256 与垫片后内容一致；③ 检测到 `shiguangBridge` 调用却无垫片 ⇒ 同步报错（复用退出码 3 拦截机制，防止未来绕过）；
- 上线顺序：先 workflow_dispatch 手动触发验证，抽查若干脚本（如 resources/AHSZU/ahszu_01.js），再放行每日定时任务。

### C 层：索引策略（分阶段，当前不必急）

- **短期（现在起）**：继续使用 `index/root_index.yaml` + `resources/*/adapters.yaml`。依据：上游 yaml 仍是创作源格式（README 贡献流程未变，pb 只是 CI 编译产物），短期内不会消失；mikcb 解析链路（`lib/services/warehouse_repository_service.dart` fetchRootIndex/fetchAdaptersIndex）不动。
- **中期（可选增强）**：mikcb 新增 `school_index.pb` 解析（proto 模板在上游 `proto/school_index.proto`），优先 pb、失败回退 yaml——单文件拉取更快，且配合 sha256 抗镜像投毒。
- **监控项**：qingyu_warehouse CI 增加上游哨兵检查——若上游删除 `index/root_index.yaml` 或 build_data.py 不再产出 yaml 兼容结构，则告警转人工评估。

### D 层：发布与运营

- mikcb 双桥注入版本尽快发一个小版本，让增量用户天然双向免疫；
- 存量旧版用户由 B 层垫片兜底，**不强制升级、不改镜像地址**；
- 更新日志注明「教务适配协议 v2 已兼容」；持续关注上游 wiki《适配更新日志》是否新增 v2 方法。

## 五、实施清单

1. [mikcb] course_import_screen.dart wrappedScript 注入双桥 + 幂等反向垫片（A 层）
2. [mikcb] 补测试：注入文本含两组桥名断言；GLOBAL_TOOLS/school.js 真机手测六个桥方法
3. [qingyu_warehouse] sync_upstream.py 增加垫片步骤 + sha256 重算（B 层）
4. [qingyu_warehouse] test_warehouse_upstream_compat.py 增加垫片/sha256/拦截三类断言
5. [qingyu_warehouse] 手动触发 sync-upstream 并抽查产物
6. [mikcb] （可选后续）school_index.pb 解析支持（C 层中期）
7. [文档] RELEASE.md 记录本次协议兼容决策

## 六、风险与回滚

| 风险 | 缓解 |
| --- | --- |
| 上游未来给 v2 增加新桥方法（当前承诺结构不变） | App 端为白名单式实现，缺方法仅功能降级不崩溃；盯上游 wiki 变更即可跟进 |
| 个别脚本自定义了 `window.shiguangBridge` 与垫片冲突 | 垫片仅在「不存在时」赋值，天然避让；compat 测试加 grep 断言 |
| sha256 重算遗漏导致新 App 校验失败拒载 | compat 测试强制「垫片 ⇔ sha256 一致」校验（B 层第 3 条） |
| 上游彻底弃用 yaml 索引 | C 层哨兵检查提前告警；届时切 pb 解析（C 层中期项） |
| 回滚 | 垫片纯附加、可逆；App 端别名无破坏性；yaml 主链路未动，回滚即移除对应步骤 |

---

## 七、实施记录（2026-08-23）

### A 层 ✅ 已完成（mikcb commit ae06e41）
- 新增 `lib/services/warehouse_bridge_compat.dart`：`kWarehouseBridgeCompatShim` 常量（v1↔v2 双向别名，幂等）；
- `course_import_screen.dart` wrappedScript 在 v1 桥实现后插值垫片；
- `test/services/warehouse_bridge_compat_test.dart` 3 例单测锁定行为。

### B 层 ✅ 已完成并上线（qingyu_warehouse commits e31aa9c…5274d22，已推送 origin/main）
- `apply_v2_bridge_shim`：检测到 v2 桥调用的脚本自动前置幂等垫片；落盘后、post 校验前统一应用；
- 校验器方法白名单扩展到 `window.shiguangBridge*`，修复 v2 未实现方法漏判缺口；
- 新增 `--refresh-existing`（默认关闭，定时任务行为不变）与 `--quarantine-blocking` 隔离机制（`--no-quarantine` 恢复整批中止旧行为）;
- 过程中修复两个原有缺陷：预检暂存只写首个 asset_js_path（多适配器学校误报）、未兼容上游 asset_js_path 占位约定（幽灵脚本阻断）；
- 已执行一次全量刷新：**150 个脚本带垫片更新为上游 v2 版本**，仅 HUAT 因调用轻屿未实现的 showConfirmDialog 被隔离（保持本地旧版脚本）；GLOBAL_TOOLS/test.js 等占位按警告跳过。远端 raw 抽验通过。
- 单测 18/18 通过。

> 注：adapters.yaml 与 pb 索引实际均无 sha256 字段，方案中最危险的"重算"环节在本仓库不存在，天然消除该风险。

### C 层 ✅ 按计划维持现状
继续使用 root_index.yaml + adapters.yaml；pb 解析留作后续可选增强。

### 遗留事项
- HUAT：待轻屿实现 showConfirmDialog（或确认映射到 showAlert）后重新纳入刷新；
- 上游如新增桥接方法，校验器会以 unknown_bridge_method 阻断并隔离对应学校，届时在 App 端补实现即可。