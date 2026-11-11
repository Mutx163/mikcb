# 网站与国际化协作约定

这份文档写清两个长期约定：

1. 网站分别放在哪、各自负责什么；
2. 应用多语言在**去 Flutter 化之后**怎么继续扩展（旧 Dart 本地化链路已删除）。

---

## 1. 网站目录约定

仓库里有两个网站，职责不同，不要混用：

| 目录 | 是什么 | 怎么改 |
|---|---|---|
| `docs/` | **正式静态站**（下载页 / SEO / 公益页）。判据：`docs/CNAME`、`index.html`、`sitemap.xml`、`robots.txt` 都在这里 | 直接改 HTML/CSS/JS；改完自查 `docs/index.html`、`docs/sitemap.xml` 可达 |
| `site/` | **Next.js 用户文档站**（fumadocs-mdx，静态导出到 `site/out/`） | 改 `site/content/docs/**/*.mdx`；本地 `pnpm dev`，产物 `pnpm build` |

- 做 SEO、下载页、落地页、分享卡片、站点脚本 → **优先改 `docs/`**。
- 写使用文档（教程、功能说明、更新日志的正文）→ 改 `site/content/`。
- `site/next-env.d.ts`、`site/.next/`、`site/out/`、`site/.source/` 都是生成物，不要提交（`.gitignore` 已忽略）。
- `site/AGENTS.md` / `site/CLAUDE.md` 由 `next dev` 自动生成或注入，**不提交**（根 `.gitignore` 已忽略，`git status` 里不该出现）。

---

## 2. 国际化：唯一真源是 `i18n/*.arb`

| 项 | 值 |
|---|---|
| 文案源文件 | `i18n/app_zh.arb`（**简体中文是源语言**） |
| 其他语言 | `i18n/app_en.arb` / `app_ja.arb` / `app_ko.arb` / `app_zh_HK.arb` / `app_zh_TW.arb`（共 6 份） |
| 生成的 Kotlin 表 | `android/app/src/main/kotlin/com/mutx163/qingyu/app/ArbCatalog.kt`（**生成物，不要手改**） |
| 生成脚本 | `python tool/gen_compose_arb_catalog.py`；只校验最新：`... --check` |
| 运行时取值 | `com.mutx163.qingyu.app.ArbText.text` → `AppLocaleRuntime` → `ArbCatalog`，缺键回落中文原文 |
| 语言标签 | `AppLocaleRuntime.SUPPORTED_TAGS` = `en` / `ja` / `ko` / `zh` / `zh_HK` / `zh_TW` |

### 为什么生成而不是运行时读 JSON

首帧不付整份 JSON 解析成本；键缺失在编译期就能看见。Kotlin 单方法有 64KB 字节码上限，
脚本按每 300 键一个 `when` 分块拼接。

---

## 3. 新增 / 修改文案：固定步骤

1. **先改中文源** `i18n/app_zh.arb`：加键、写值。占位符用 `{name}`。
2. 同步补其余五份 ARB 的翻译；**缺键允许**（运行时会回落中文），但不要写错键名。
3. 重新生成 Kotlin 文案表：

   ```bash
   python tool/gen_compose_arb_catalog.py
   ```

4. 在 Kotlin 里用 `ArbText` 引用（不要直接拼屏幕文案）：

   ```kotlin
   val title = ArbText("settingsWeatherTitle", "天气")
   Text(text = title.text)   // 界面一律读 .text，不读 .zh
   ```

   - `.zh` 只给对拍测试与缺键兜底用；
   - 带参数的行用 `ArbText(...).filled("count", "3")` 或 `resolved`。

5. 跑对应域的 `*StringsParityTest`（54 个），它们直读 `i18n/app_zh.arb` 逐字对拍。
6. 提交前自查：

   ```bash
   python tool/gen_compose_arb_catalog.py --check   # 必须输出「ArbCatalog.kt 是最新的」
   pwsh -NoProfile -File scripts/test-kotlin-module.ps1 -Module "app"   # ArbCatalogTest / AppLocaleRuntimeTest
   ```

### 文案风格规则（人工核对，无自动门禁）

- 行内控件（右侧有开关 / 取值 / 箭头的行）标题 ≤ **11**、说明句 ≤ **17**（汉字 1、ASCII 0.55、占位符按 3 位数字）。
- 砍掉复述标题、导航说明、过程描述；只留「为什么 / 后果 / 前提」。
- **删一处渲染就顺手删键**：六份 ARB 同步删，再跑生成脚本。死键会让 `ArbCatalogTest` / 死键基线对不上。

---

## 4. 新增语言：改四处

1. 新增 `i18n/app_<tag>.arb`（如 `app_fr.arb`），照 `app_en.arb` 的结构翻译；
2. `tool/gen_compose_arb_catalog.py` 的 `LANGUAGES` 列表加一行 `("<tag>", "app_<tag>.arb")`；
3. `AppLocaleRuntime.SUPPORTED_TAGS` 加标签（顺序与语言选择列表一致）；
4. `SettingsGeneralPage` 里语言选项表同步加一项；重跑生成脚本。

**不要**重新引入手写本地化壳，也不要绕开 `ArbText` 直接查 `ArbCatalog`。

---

## 5. 运行机制（改语言怎么生效）

- 用户手选语言写入设置 → 壳在 `PagesShellActivity` 调 `AppLocaleRuntime.set(...)`；
- `ArbText.text` 每次取值读 `AppLocaleRuntime.revisionReader`，壳把它接到 snapshot state，
  所以所有读文案的 Composable 自动重组；返回栈不丢；
- 「跟随系统」只认**真实系统语言**（壳在 `attachBaseContext` 注入），不读被 App 自己改过的
  `Locale.getDefault()`。

---

## 6. 对未来 AI / 贡献者的明确约束

### 网站

- 默认 `docs/` 是正式站点目录；`site/` 是用户文档站。
- 生成物（`site/.next`、`site/out`、`site/.source`、`site/next-env.d.ts`、`site/AGENTS.md`）不提交。

### 国际化

- 默认 `i18n/app_zh.arb` 是中文源；新键先补中文。
- 不要手改 `ArbCatalog.kt`；改 ARB 后必须重跑生成脚本并 `--check`。
- 不要重新引入旧 Dart 本地化链路（已随去 Flutter 化删除）。
- 界面文案一律经 `ArbText.text`，不要硬编码中文或直接读 `.zh`。
