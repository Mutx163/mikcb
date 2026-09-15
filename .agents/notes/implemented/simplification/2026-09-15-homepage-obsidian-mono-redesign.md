# Agent Note: 官网首页收敛到 obsidian-mono 极简（去霓虹 / 极光 / 渐变）

Status: implemented

## Problem

官网首页此前是「深色霓虹」风：三团彩色极光（`.aurora-a/b/c`，`blur(90px)` + 26s 无限漂移）、渐变裁字标题（`.grad-text` + `--grad`）、每张 bento 卡右上角一枚彩色标签（`.bento-tag` / `.tag-*`）、hero 区两张浮动毛玻璃卡（`.float-card` / `.fc-*`），以及每段标题上方一行小字 `.section-label`。

这套装饰与产品「系统原生质感」的定位不符：极光是常驻大半径模糊的合成层，渐变裁字会让标题在浅色端对比度不稳（`--grad` 的历史版本就因此被换过色），彩色标签则把视觉重心从文案挪到颜色上。改版要解决的是"表面减法"，不是换一套配色。

## Decision

- 设计令牌换成 obsidian-mono：`--bg #07090e`、`--card rgba(255,255,255,0.032)`、`--line rgba(255,255,255,0.075)`，圆角 24/18/12，缓动 `cubic-bezier(0.16,1,0.3,1)`，卡片内边距整体放大（bento 28/26 → 32/28），hover 位移从 -4px 收到 -2px。
- 背景只剩 `.sky`：一层 48px 微网格 + 顶部径向暗角；`.aurora` 三团及其 `@keyframes aurora-drift` 全部删除。
- 渐变文字退场：`--grad` 与 `.grad-text` 一并删除。两个消费者改为纯色 `var(--text)`——首页「已适配学校」的三个统计数字，和 `docs/404.html` 的「404」大字。
- 彩色标签、浮卡、`section-label` 小标题、hero 的「看看它能做什么」按钮从 `index.html` 移除，对应 CSS 与六语言词条同批删除。
- hero 小药丸从 `<p class="hero-eyebrow">` 改为 `<div class="hero-kicker">`（块级容器装 inline-flex 内容）；按钮主色改 `--cta-from #1e60ff` / `--cta-to #1545bf`（白字全段 ≥5.03:1）。
- `--text-faint` 的透明度是 0.5，不是更浅的值（见 Consequences）。

## 跨文件契约：`docs/home.css` 不是 index.html 专属

`docs/home.css` 被 `index.html` 与 `docs/404.html` 同时引入，两页都不引 `styles.css`。凡判断"某个类只有首页在用"，必须在两页都搜一遍——404 页用 `.sky` / `.sky-grid` / `.cta-btn` / `.global-nav`，改版前还用 `.aurora`。文件头注释已改成共用说明。

`home.css` 里的 `.section-label`（含 `.schools-group .section-label`）看起来是孤儿，实际由 `script.js` 的 `renderGroup()` 注入到首页 `#schools-list` 的 `.schools-group` 里：这是「脚本 → CSS」的跨文件引用，删 CSS 之前必须搜 `script.js`。

## Alternatives considered

- **保留极光，只调暗 / 调慢** — 极光是这套视觉里渲染成本最高的部分（640px 半径 `blur(90px)` 的常驻合成层 + 无限动画），调暗只改观感不改成本，与「系统原生质感」的定位也仍然冲突。
- **只换配色，保留渐变标题与彩色标签** — 改动最小、风险最低。但渐变裁字的对比度问题会继续留在标题上，彩色标签也继续抢注意力；本次目标是减法，不是换皮。
- **保留 `--grad`，只为统计数字与 404 大字服务** — 曾是最小改动选项。但那个渐变本身就是霓虹时代的产物，两处改纯色后视觉更统一，也顺带消掉「变量为 `none` 时 `background-clip:text` 变成全透明文字」这类易复发陷阱。
- **保留 hero 的浮卡作为截图亮点** — 它们复述的正是下方 bento 卡片里的功能（课前提醒 / WebDAV），移动端本来就被 `display:none` 隐藏。

## Consequences

- **收益**：首页不再有常驻无限动画（省合成与绘制）；视觉层级收回到文案与网格；令牌面收窄（`--grad` 消失），配色改动只走 token。
- **代价与已知上限**：
  - 首页少了「看看它能做什么」这一次要 CTA，靠顶部导航 `#features` 兜底；功能彩色标签消失后，「新增 / 独占」信息只留在 changelog 与卡片正文（超级岛卡仍写「需 HyperOS 3.0.300+」，未丢信息）。
  - 调色板只换到 token 层：`home.css` 里仍有约 30 处硬编码旧色（`#7ab4ff`、`#8ab8ff`、`#6ee7d8`、`rgba(52,130,255,…)`、`rgba(45,212,191,…)`），`--blue-soft` / `--teal-soft` 因此暂时没有 `var()` 消费者。清那批硬编码时改用这两个 token，别再写字面值。
  - `--text-faint` 曾被降到 0.44（≈4.1:1，低于 WCAG AA 的 4.5:1），已回到 0.5（≈5.0:1）；它全部用在 0.68~0.9rem 的次级小字上，再调浅前先算对比度。
- **触发重访的信号**：若首页要恢复渐变或彩色点缀，先确认「无色值 + `background-clip:text`」的组合不会把文字变成全透明。

## Verification

- `grep -rn "aurora\|grad-text\|bento-tag\|float-card" docs/home.css docs/index.html docs/404.html` 无输出。
- `grep -rn "var(--grad)" docs/` 无输出。
- 六语言词典键数一致（各 276 键）：`node -e "for(const n of ['en','ja','ko','zh-CN','zh-HK','zh-TW'])console.log(n,Object.keys(require('./docs/i18n/'+n+'.json')).length)"`。
- 首页三个统计数字（`#schools-stat-count|-generic|-total`）与 404 页大字可见：两处都是纯色 `var(--text)`，不再有 `background-clip: text`。
