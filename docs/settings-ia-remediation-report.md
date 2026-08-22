# 设置页 IA 评审整改报告（最终版）

> 生成：2026-07 · 执行者：ox-alpha（三代理科学讨论后的人工+代理协作实施）
> 本文件是「设置页专业评审 → 三方交叉质证 → 整改实施」全流程的**唯一总结交付物**。

---

## 一、评审方法与结论来源

1. **独立盲评**：三个学科视角的代理（信息架构 / 人因工程 / 平台规范工程）只拿事实基线、不带任何预设结论，独立读代码评审。
2. **交叉质证**：互发对方全文，逐条核对事实、表态同意/修正/反对，并强制自我证伪。过程中 3 个观点被提出者主动撤回、1 个被降级、主持人 1 次核验被代理推翻（HK 简体残留初判"仅孤例"实为段落级多处）。
3. **综合裁决**：按「证据强度 × 用户受损面 × 修复成本」合并定级。

最终共识：设置体系骨架健康（按作用对象分页、状态前置模式、按页恢复默认），债务集中于**「规范已立、代码未遵」且规范缺测试守门**。

## 二、整改清单与落地状态

### P0（已完成 ✅）

| # | 事项 | 落地 | 位置 |
|---|------|------|------|
| 1 | 外观「恢复默认」漏 3 字段（homeNavigationForm / glassDockLayout / glassDockInsetClearance，后者为滑块）违反 IA §5 | 补齐 copyWith + 测试断言（含跨 scope 保护） | `lib/screens/settings/settings_reset.dart` · `test/screens/settings_reset_test.dart` |
| 2 | IA §7 搜索索引"描述了不存在的能力" | 选择**诚实化改写**而非补建：降级为路线图 + 启动条件（埋点迷路信号或入口 >30）；见偏差说明 §五-1 | `.trellis/spec/flutter/settings-information-architecture.md` §7 |

### P1（已完成 ✅）

| # | 事项 | 落地 | 位置 |
|---|------|------|------|
| 3 | 云同步入口零状态（IA §6 点名） | 新增 `_CloudSyncEntryTile`：行尾显示 未开启/已开启/同步中/上次同步失败；缓存 Future 不在 build 发 I/O；前台恢复重读；ListenableBuilder 跟随同步动态 | `lib/screens/timetable_settings_screen.dart` |
| 4 | 时间模板未选择时首页行尾留白 | 双入口统一空态文案「未选择」 | 同上 · `settings_timetable_page.dart` |
| 5 | 恢复默认确认框谎报范围（四页共用「重置所有设置」） | 新增 4 条按 scope 枚举的确认文案（六语言） | `lib/l10n/*.arb` · `settings_reset.dart` `_confirmBody` |
| 6 | layout spec 正文以已删除的 Forui 组件为 canonical | 整篇降级 HISTORICAL 存根，有效契约（16 padding / SectionGap / w400）标注现居所 | `.trellis/spec/flutter/settings-screen-layout.md` |

### P2（已完成 ✅）

| # | 事项 | 落地 | 位置 |
|---|------|------|------|
| 7 | 「显示与外观」vs「外观与配色」一词两义 | 组标题改名「课表显示」（六语言同步） | `lib/l10n/*.arb` |
| 8 | 时间模板双入口图标不一（weeks vs schedule_rounded） | 统一为 `timer` 向量图标 + teal（语义更准且释放 weeks 给学期周数）；顺带把 `_openTimeSchemeQuickSwitcher` 改名 `_openTimeSchemeManagement` | 主文件 · `settings_timetable_page.dart` |
| 9 | 外观页第 1 组无标题裸组（同页自相矛盾） | 包进 `HyperosSettingsBlock`，新标题「主题与显示」 | `settings_appearance.dart` |
| 10 | 超级岛主页单一无名组混排偏好与诊断 | 拆「提醒 / 显示内容 / 维护与自检」三个带标签组 | `settings_live.dart` |

### P3（已完成 ✅）

| # | 事项 | 落地 | 位置 |
|---|------|------|------|
| 11 | 「诊断」副标题窄于页内实况 | 改为「日志 · 自检 · 内存」（六语言） | `app_*.arb` |
| 12 | live 子页 5 行彩色 badge 缺省退化单色 | 补 iconAccent：alarm橙/upcoming青/timelapse紫/shield绿/science橙（自检与诊断页同色，IA §4） | `settings_live.dart` |
| 13 | 节假日三地术语漂移 + HK 文件段落级简体混排 | TW/HK 统一「假日標記」；HK 全量简体独用字转繁体（约 2000 字符/900+ 行，三轮扫描归零，JSON 校验通过） | `app_zh_HK.arb` · `app_zh_TW.arb` |
| 14 | 'weeks' 字形双占 | 时间模板让出 weeks 改用 timer（见 #8） | 主文件 · `settings_timetable_page.dart` |
| 15 | 清除壁纸/恢复默认后文档目录积累孤儿图片文件 | `managed_image_storage.dart` 新增 `deleteManagedImage`（目录+前缀双保险防误删），接入清除按钮与课表页 reset 流程 | `lib/utils/managed_image_storage.dart` 等 |

### 规范修订（随整改同步，✅ 已落盘）

- **§1**：「诊断只此一处」→「唯一权威入口 + 允许上下文捷径（须同视觉 + 注释留痕）」；新增「上下文偏好例外条款」（如统计周报推送留在统计页）。
- **§3**：补「页面唯一组可省略标签」例外；补超限合并判据（优先合并同一心智模型相邻组，禁止硬塞）。
- **§5**：确认文案必须按 scope 枚举。
- **§6**：标注已实现项与实现要点；「新增入口行尾留白视为违规」。
- **§7**：诚实化路线图化（见 §五-1）。
- 注：`.trellis/` 在本仓库被 gitignore，规范修订仅落盘不进版本库（项目既有约定）。

## 三、验证结果

- `flutter gen-l10n` 通过；`flutter analyze` **零 error**（存量 info/warning 均在他人文件）。
- `flutter test test/screens/settings_reset_test.dart` → **4/4 通过**（含新增外观 scope 断言与跨 scope 保护）。
- `flutter test test/widgets/timetable_settings_screen_test.dart` → **3/3 通过**（live 分组改造保留 `settings-live-self-check` key 与「提醒时段」文案）。
- 两轮合计 7/7。app_zh_HK.arb 经 `ConvertFrom-Json` 校验（3289 键完整）。

## 四、提交记录（均只含本人文件，未触碰他人并行改动）

| commit | 内容 |
|--------|------|
| `e67d106` | 设置IA整改主体（17 文件：reset 补字段/确认文案、状态前置、命名分组统一） |
| `724a2a76` | 孤儿壁纸清理 + zh-HK 全面繁体化 |

## 五、偏差与决策记录（与三代理裁决的差异及理由）

1. **§7 选择"改写"而非"补建索引"**：裁决允许二选一（文档行动 P0）。建索引需配套 UI 与交互设计，且三方一致认为启动应以埋点数据为据——故先兑现"文档不得承诺不存在的能力"，索引进入带触发条件的路线图。
2. **双入口图标统一走"换行组件"而非"扩 facade API"**：丙提出根因在 `HyperosListTile.icon` 为 `IconData`（属实）。裁决给的两个选项中选择了零 API 面变更的方案——该行直接换用库内已有的 `_MiuixSettingsPreference`（支持向量 badge），效果等同且无回归面。`tiles.dart` 未动；若未来多处需要向量 leading，再评估扩 facade。
3. **通用页无名组豁免**：采纳丙的 §3 例外条款（页面唯一组可省略标签），因此通用页不加标题；外观页第 1 组非唯一组，不在豁免之列故加了标题。

## 六、遗留与后续建议（本次不做）

- 设置内搜索：待 §7 启动条件满足后立项（索引粒度页面+分组、keywords 用用户词汇、id 唯一性测试）。
- 「恢复默认」完成后可考虑轻量 undo（乙 P2 建议），需先解决跨页状态回滚的复杂度。
- 云同步状态目前轮询配置快照；若未来需要实时反映远端变化，可让 coordinator 在配置变更时主动 notify。
- l10n 键名失义类小项（`liveIslandLabel*` 被节假日行复用等）属代码健康债，可随下次触达相关文件顺手清理。
- 审计钩子：把 §3/§5/§6 的可测条款写成 Dart 断言或纳入 `hyperos_audit.py --strict` 管线（丙建议，涉及工具链改造，单独立项）。
