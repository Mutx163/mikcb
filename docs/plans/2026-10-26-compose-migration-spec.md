# Compose 迁移 · 执行规格（doublecheck spec）

> 状态：已与用户对齐（2026-10-26）
> 上游计划：`docs/plans/2026-10-26-compose-migration-plan.md`
> 数据契约：`docs/plans/2026-10-26-data-contract.md`（Phase 0 冻结件）
> 读者：所有参与迁移的 Agent（含并行泳道）。开工前必读。

## Goal

把轻屿课表从 Flutter 原地迁移到 Jetpack Compose：数据一条不丢（盘上格式冻结、
双向兼容测试有牙齿）、不卸载重装、随时可回退；UI 迁移后与现版本外观一致
（用户 2026-10-26 加严：不接受「可感知差异」的说法，目标逐像素对齐）；
官方 Compose Miuix 已有的组件直接使用、不重复造轮子。

## 执行方式（用户 2026-10-26 授权）

允许使用智能体团队对**互不影响**的工作做并行分工（多页面重构、多业务族移植）以提效；
但**质量标准与目标本身不因并行而降低**：

- 每条泳道遵守同一份规格、同一套验收标准、同一套红绿/咬合探针纪律；
- **数据层（FlutterPrefsCodec / data-contract / storage）与构建红线
  （applicationId / 签名 / versionCode / 组件类名）只由 Lead 操作**，泳道不得触碰；
- 泳道产出一律「小补丁 + 路径限定提交」，不整文件覆盖别人的在途改动。

## Scope

范围内：Phase 0（数据契约 + golden 样本 + A→B/B→A 双向测试）；Phase 1（同包名
Compose 空壳 + 真机验证）；Phase 2（逻辑层 Dart→Kotlin ≈6.6 万行，按业务族分批，
每族带端口测试）；Phase 3（UI 层 ≈12.3 万行，Compose + 官方 Miuix，按页面分批，
每批真机截图对照）；Phase 4（原生能力对齐，替换 5 个与 Flutter 耦合的
MethodChannel）；Phase 5（删 Flutter 依赖与两个 fork）。

范围外：iOS/桌面；迁移期间换新数据格式（SQLite/DataStore 是回退窗口关闭后的独立优化）；
自动解密旧凭据；教务远端脚本仓库。

## Acceptance criteria

1) `docs/plans/2026-10-26-data-contract.md` 的 key 集合与真机 golden 样本完全一致；
2) A→B（Flutter 写→Kotlin 读）与 B→A（Kotlin 写→Flutter 读）双向测试存在且能红能绿
   （咬合探针：故意破坏一处编码必须红）；
3) Phase 1：`applicationId=com.mutx163.qingyu` 的最小 Compose 工程，真机覆盖安装后
   读出真实课表、写回一个 key 后 Flutter 版仍能读到；
4) Phase 3 每页有与现版本的同屏对照截图，差异逐条判定为「Miuix 官方组件语义下的
   等价实现」才可接受；
5) 官方 Miuix 已有的组件直接 import 使用；自绘实现须在评审中说明「官方没有对应物」。

## Failure modes（踩线即停）

1) 落盘格式被顺手改写 → 回退作废：禁止，双向测试必须保持绿；
2) 签名密钥 / applicationId 变动 → 只能卸载重装=数据全丢：任何构建配置改动先核对；
3) 组件类名 / 通知渠道 ID 改名 → 桌面小组件全灭、保活失效（§3.1 清单一个不许动）；
4) 只测 A→B 不测 B→A → 回退没有证据；
5) 「长得一样」滑成「差不多」→ 每页必须截图对照；
6) 重复造轮子：自绘官方 Miuix 已有的组件 → 评审打回；
7) 咬合探针缺失：双向测试从未见过红 → 测试无牙齿；
8) golden 样本缺失就动数据层 → 一律先等样本。

## Priorities（冲突时）

数据安全（格式冻结/签名/回退）> UI 与现版本一致性 > 直接复用官方 Miuix > 工程整洁度。
「用官方 Miuix」与「长得一模一样」冲突时：以现状外观为准，用 Miuix 的定制参数
（颜色/形状/尺寸）贴近，不造新轮子；确需自绘先确认官方没有对应物。
minSdk 抬不抬待用户拍板，拍板前模糊相关页面不动。

## Non-goals

不做 iOS/桌面；不做混合壳；迁移期不换数据格式；不自动解密凭据；
不承诺逐帧动画曲线一致（静态外观与转场类型必须对齐）。
