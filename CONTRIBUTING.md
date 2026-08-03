# 贡献指南

感谢考虑为轻屿课表（mikcb）贡献代码、文档或教务适配。

## 开始之前

1. 阅读 [README.md](./README.md) 了解项目定位
2. 阅读 [LICENSE](./LICENSE)（GPL-3.0-or-later）——贡献的代码将按相同协议分发
3. 行为准则见 [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
4. 安全问题见 [SECURITY.md](./SECURITY.md)，**不要**在公开 Issue 中报告漏洞

## 命名说明

| 名称 | 含义 |
|------|------|
| GitHub 仓库 `mikcb` | 对外仓库名 |
| pubspec `university_timetable` | 历史 Dart 包名，暂未更名 |
| Android 包名 `com.mutx163.qingyu` | 应用 ID |
| 产品名「轻屿课表」 | 用户可见名称 |

## 开发环境

**版本以 CI 与 [.fvmrc](./.fvmrc) 为准**（当前稳定 Flutter **3.44.8**；最低支持 Flutter **3.44.2** / Dart **3.12.2**）。

```bash
# 可选：fvm use 3.44.8
flutter pub get
flutter run -d android --flavor dev
```

### 发版前必跑（与 CI / Release 一致）

```bash
dart format .      # 含文件末尾换行；勿用脚本手改 .dart 格式
flutter analyze --no-fatal-infos  # error/warning 失败，info 仅记录
flutter test
```

AI / 协作者约定见 [.cursor/rules/dart-source-editing.mdc](./.cursor/rules/dart-source-editing.mdc)（Cursor 会自动注入）。

可选本地集成测试：

```bash
flutter test test_integration/
```

Android 签名：`android/key.properties` 与 keystore **不要提交**；CI 使用 Secrets。

## 贡献流程

1. Fork 本仓库
2. 从 `main` 创建分支（`feat/…`、`fix/…`、`docs/…`）
3. 小步提交，保持 diff 聚焦
4. 推送并在 GitHub 开 Pull Request（会自动套用 PR 模板）
5. 确保 CI 全绿

### 提交信息

推荐 Conventional Commits 风格，与现有历史一致：

- `feat:` 新功能
- `fix:` 修复
- `docs:` 文档
- `test:` 测试
- `chore:` 构建 / CI / 杂项

## 贡献方向

### 应用本体（本仓库）

- UI / HyperOS 体验
- 课表逻辑、提醒、导入、云同步
- 多语言（`lib/l10n/*.arb`）
- 文档与官网（`docs/`）

### 教务系统适配（独立仓库）

网页登录导入脚本在 **[qingyu_warehouse](https://github.com/Mutx163/qingyu_warehouse)** 维护。请在该仓库开 Issue / PR。

### 不要提交的内容

- API Key、签名文件、`key.properties`
- 仅本地 IDE / Agent 配置（已在 `.gitignore`）
- 与 PR 无关的大规模格式化

## Issue 指引

使用 GitHub Issue 模板：

- **Bug 报告**：复现步骤 + 版本 + 机型
- **功能建议**：用户场景优先
- **教务适配**：学校名称；代码请走 warehouse 仓库

## 发布

Maintainer 发版流程见 [docs/RELEASE.md](./docs/RELEASE.md)。外部贡献者通常不需要切 tag。

## 许可与第三方组件

- 源码：GPL-3.0-or-later
-  bundled SDK / 资源许可见 [docs/THIRD_PARTY_LICENSES.md](./docs/THIRD_PARTY_LICENSES.md)
- 隐私说明见 [docs/PRIVACY.md](./docs/PRIVACY.md)

## 获取帮助

- [GitHub Issues](https://github.com/Mutx163/mikcb/issues)
- [Releases / 更新日志](https://github.com/Mutx163/mikcb/releases)
