# 网站与国际化协作约定

这份文档用于明确两个长期约定：

1. 网站目录到底是哪一个
2. 应用多语言应该怎样继续扩展

---

## 1. 网站目录约定

### 当前正式网站目录

当前正式网站以 `docs/` 为准。

判断依据：

- `docs/CNAME` 已存在
- `docs/` 目录下有完整网站资源：
  - `index.html`
  - `script.js`
  - `styles.css`
  - `app-icon.png`
  - `favicon.svg`
  - `robots.txt`
  - `sitemap.xml`

### 后续规则

- 做 SEO、下载页、落地页、分享卡片、站点脚本时，**优先修改 `docs/`**
- `web/` 目前不是正式主站发布目录；除非后续明确切回 Flutter Web 或统一站点方案，否则不要把它当作唯一真源

### 对未来 AI / 维护者的要求

- 如果任务是“优化网站”或“做 SEO”，默认以 `docs/` 为主要目标
- 如果发现 `web/` 和 `docs/` 内容不一致，优先保证 `docs/` 正确

---

## 2. 国际化方案约定

### 当前方案

应用国际化已切到 Flutter 标准 `gen-l10n`。

关键文件：

- `l10n.yaml`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_en.arb`

### 中文是源语言

当前约定：

- **`lib/l10n/app_zh.arb` 是中文源文件**
- 新功能、新页面、新按钮、新提示文案，优先先补中文 key
- 英文和其他语言后续再跟进翻译

这样做的原因：

- 开发时不会被“多语言必须同时补齐”卡住
- 中文语义是当前产品的主表达
- 贡献者后续可以基于中文源文件做翻译适配

---

## 3. 新增文案时怎么做

### 步骤

1. 在 `lib/l10n/app_zh.arb` 中新增中文 key
2. 在其他语言 ARB 中补对应翻译
3. 运行：

```bash
flutter gen-l10n
```

4. 在 Dart 代码中通过：

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

并使用：

```dart
final l10n = AppLocalizations.of(context)!;
```

读取文案

---

## 4. 新增语言时怎么做

如果后续要支持更多国家 / 地区：

### 只需要做

1. 新增语言文件，例如：
   - `lib/l10n/app_ja.arb`
   - `lib/l10n/app_fr.arb`
   - `lib/l10n/app_ru.arb`
   - `lib/l10n/app_es.arb`
2. 翻译已有 key
3. 运行：

```bash
flutter gen-l10n
```

### 不需要做

- 不需要新增语言枚举
- 不需要修改语言设置架构
- 不需要改 `MaterialApp` 主链路

当前语言设置已经改成可扩展的 locale tag 方案，而不是写死语言枚举。

---

## 5. 对未来 AI / 贡献者的明确约束

### 网站相关

- 默认 `docs/` 是正式站点目录
- `web/` 不应被默认当成生产站点

### 国际化相关

- 默认 `app_zh.arb` 是中文源
- 新 key 先补中文
- 不要重新引入手写本地化壳
- 统一走 `gen-l10n`

---

## 6. 建议验证命令

### 网站

可至少检查：

- `docs/index.html`
- `docs/robots.txt`
- `docs/sitemap.xml`

### Flutter 国际化

优先使用 Windows Flutter 工具链：

```bash
flutter gen-l10n
flutter analyze
```

如果当前环境是 Windows Flutter：

```bash
cmd.exe /C "D:\Flutter\flutter\bin\flutter.bat" gen-l10n
cmd.exe /C "D:\Flutter\flutter\bin\flutter.bat" analyze
```

---

## 7. 当前状态备注

- 网站 SEO 已优先补到 `docs/`
- 国际化底座已完成
- 仍有部分页面文案在持续迁移中

这份文档的作用就是：避免未来再次混淆“网站目录到底是哪一个”和“多语言到底该怎么扩展”。
