# miuix 官方 Demo 与组件文档（只读参考，教科书）

> **这是一份 vendored 的第三方参考副本，不是本仓代码。**
> 只读。不要在 `docs/reference/miuix-demo/**` 里改任何东西——上游一升级，改动就丢。
> 要记录「我们该怎么用」，写在本目录的 `CHEATSHEET-*.md`（那几份是本仓的笔记）。

## 来源与版本

| 项 | 值 |
|---|---|
| 仓库 | https://github.com/compose-miuix-ui/miuix |
| 分支 | `main` |
| 快照 commit | `bb7bde3` |
| 取回日期 | 2026-10-27 |
| 许可 | Apache License 2.0，见同目录 [LICENSE](LICENSE) |
| 与我们依赖的对应关系 | 本仓 `android/app/build.gradle` 锁 `top.yukonga.miuix.kmp:*:0.9.4`；这份快照取自 main，**版本可能领先于 0.9.4**，用到新 API 前先确认本地依赖里有没有 |

## 为什么把它搬进来

老版 Flutter 的「小米观感」是自己仿的（`lib/ui/hyperos/`，51 件 26 132 行）。
迁到 Compose 后直接用了 miuix 本体，但**只用了静态外观，没用它的交互与特效配方**，
于是出现「用了正主反而更丑、点击没手感」。

官方 demo（`example/`）就是这些配方的唯一权威出处：它把每个组件**正确该怎么用、
该配哪些参数、该和什么组合**全写了一遍。这份副本的作用就是当教科书查。

## 目录结构

```
docs/reference/miuix-demo/
├── example/                     ← 官方 demo app（Kotlin Multiplatform，77 个 .kt）
│   ├── shared/src/commonMain/kotlin/
│   │   ├── App.kt / AppContent.kt / AppState.kt   ← 应用外壳：主题、导航、底栏、毛玻璃
│   │   ├── MainPage.kt / SettingsPage.kt / ...    ← 各展示页
│   │   ├── component/                             ← ★ 每个组件的用法范例（Section）
│   │   │   ├── CardSection.kt  SwitchSection.kt  ...
│   │   │   ├── animation/     ← 按压高亮、阻尼拖拽
│   │   │   ├── highlight/     ← 玻璃描边高亮 + 倾灯
│   │   │   ├── liquid/        ← 液态玻璃导航栏
│   │   │   └── effect/        ← 背景特效
│   │   ├── navigation/        ← miuix-nav 路由与转场（含自定义 AOSP 风格转场）
│   │   ├── ui/Theme.kt        ← 主题装配范例
│   │   └── utils/             ← 页面骨架工具（顶栏模糊、内边距、滚动修饰）
│   └── android|ios|desktop|macos|web/             ← 各平台宿主（参考价值低）
├── docs/components/*.md         ← ★ 官方逐组件文档（56 篇）
├── docs/zh_CN/**                ← ★ 上面那批文档的**中文版**（同样的 56 篇，中文读起来快得多）
├── docs/demo/src/commonMain/kotlin/*.kt  ← ★ 逐组件**可运行** demo（每组件一个文件，比 example 更聚焦）
├── docs/guide/*.md              ← 使用指南（`blur.md` 毛玻璃、`utils.md` 按压反馈，正是我们最缺的两块）
└── CHEATSHEET-*.md              ← 本仓精读笔记（见下）
```

### 搬进来时剔除了什么

- `example/android/src/release/generated/baselineProfiles/`（约 5 MB 的编译产物，无参考价值）
- 大于 100 KB 的图片/图标二进制（`.png` `.webp` `.icns` `.ico`）
- 各平台 App 图标与启动图（`example/*/resources/`、`Assets.xcassets/`、`mipmap/`、`drawable-v26/`）——教科书用不到
- 平台宿主目录里的原生工程细节（`ios/` `macos/` 的 Xcode 工程等），只留 Kotlin 侧

> 剩下的 3.3 MB 里，`docs/` 占 2.2 MB（中文文档 833 KB + 逐组件文档 668 KB + 逐组件 demo 358 KB + 指南 201 KB），
> 都是要读的东西，没再压。

## 精读笔记（本仓产出）

| 文件 | 内容 |
|---|---|
| [我们的差距与修法.md](我们的差距与修法.md) | **★ 先读这份。** Lead 的对照结论：我们漏了什么、为什么变丑、按性价比排序的修法 |
| [CHEATSHEET-官方文档.md](CHEATSHEET-官方文档.md) | 56 篇官方组件文档的逐组件速查：参数、默认值、正确用法 |
| [CHEATSHEET-Demo范例.md](CHEATSHEET-Demo范例.md) | 官方 demo 里每个组件的真实调用代码索引（文件:行号） |
| [CHEATSHEET-玻璃与手感.md](CHEATSHEET-玻璃与手感.md) | 我们最缺的三块：毛玻璃、按压反馈、液态玻璃与倾灯 |

## 怎么用这份教科书

1. **写任何一页之前**，先在 `docs/zh_CN/components/<组件>.md`（中文版，读得快）或
   `docs/components/<组件>.md` 看官方怎么描述；
2. 再看 `docs/demo/src/commonMain/kotlin/<组件>Demo.kt`（最聚焦）或
   `example/.../component/<X>Section.kt`（带分组上下文）里官方**实际怎么调**——
   文档和 demo 有出入时**以 demo 为准**（demo 是能跑起来的）；
3. 涉及毛玻璃 / 按压反馈 / 动效时，先读 `docs/guide/blur.md` 与 `docs/guide/utils.md`，
   再对照 [CHEATSHEET-玻璃与手感.md](CHEATSHEET-玻璃与手感.md) 确认没漏参数
   （**我们的主要缺陷就是漏了这一层**）；
4. 需要「整页该怎么搭」时看 `example/.../SettingsPage.kt`（设置页）与
   `example/.../MainPage.kt`（列表页）——这两个是最接近我们页面的骨架范例；
5. 动手前先读 [我们的差距与修法.md](我们的差距与修法.md)，避免重复踩已知的坑。
