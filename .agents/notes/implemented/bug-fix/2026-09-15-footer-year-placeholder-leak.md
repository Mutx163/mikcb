# Agent Note: 页脚 {year} 占位符在 i18n 目录加载失败时外泄成字面量

Status: implemented

## Problem

`docs/index.html` 的页脚写的是 `Copyright © {year} 轻屿课表`，年份靠脚本替换。而 `i18n.js` 的 bootstrap 在 `fetch('./i18n/<locale>.json')` 失败时只 `console.warn` 然后 `return`，后面的 `applyDocument()` 一律不执行——于是「以 `file://` 直接打开页面」（`fetch` 被浏览器拦）或「`i18n/*.json` 404 / CDN 缺文件」时，页面上出现字面量 `Copyright © {year} 轻屿课表`。

同一个坑对任何「HTML 里写 `{var}` 占位符、等 i18n 启动后才替换」的文案都成立。

`script.js` 里那段兜底（`if (footerCopyEl && !footerCopyEl.getAttribute("data-i18n"))`）在首页永远不会触发：首页页脚恰恰带 `data-i18n="footer.copy"`，判断为假直接跳过。所以它救不了这个场景——这是「谁负责填页脚年份」这条隐性契约没写下来的代价。

## Decision

`i18n.js` 增加 `applyFooterYearFromMarkup()`：只把页脚那段 HTML 原文里的 `{year}` 换成当前年份，其余文案保持原样；bootstrap 的 `catch` 分支在 `return` 前调用它。正常路径不变——目录加载成功时仍由 `applyDocument()` 用当前语言的 `footer.copy` 文案覆盖（含 `{year}` 插值）。

年份的唯一来源仍是 `new Date().getFullYear()`；`{year}` 占位符继续留在 HTML 里承担降级形态，不在标记里写死年份。

## Alternatives considered

- **在 `index.html` 里把 `{year}` 换成写死的年份** — 最省事。但年份会过期，等于把「误导性的错误年份」长期留给无 JS / 加载失败的环境，比占位符更糟。
- **去掉 `script.js` 兜底里的 `!data-i18n` 判断** — 能顺带覆盖「`i18n.js` 整个没加载」的极端情况。但首页正常路径下会与 `i18n.js` 重复写同一段文本，且 `script.js` 的 `t()` 在 I18n 未就绪时退回中文，非中文用户可能闪一下中文，得不偿失。
- **改由服务端渲染年份** — 站点是纯静态托管（GitHub Pages / CNB），没有服务端。
- **不做，只在文档里写「别用 file:// 打开」** — 本地预览是常规操作，`i18n/*.json` 缺失同样会触发，是会复发的坑。

## Consequences

- **收益**：无论 i18n 目录能否加载，页脚都不再露出 `{year}`；「HTML 占位符 + JS 替换」这一类文案有了兜底先例可循。
- **代价与已知上限**：兜底只在 `i18n.js` 成功执行时生效；JS 全禁用或 `i18n.js` 自身 404 时仍会露出 `{year}`。若之后新增其它 `{var}` 占位符，需要在同一个 `catch` 分支里补对应的替换，或者把占位符替换集中成一张表。

## Verification

- 以 `file://` 打开（或断网模拟）`docs/index.html`：页脚显示「Copyright © 2026 轻屿课表」，控制台有 `[i18n] failed to load catalogs` 警告。
- 正常 http 访问：页脚随语言切换，年份为当前年。
- `grep -rn "{year}" docs/*.html` 只命中 `index.html` 页脚一处（其余页面的页脚本来就不带年份）。
