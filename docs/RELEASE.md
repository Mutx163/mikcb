# 发行教程

这份文档只写当前仓库实际在用的发布方法。

先记住 5 句话：

- 只 `git push origin main` 不会触发 GitHub Actions。
- 当前仓库只有在 `push tag` 时才会自动构建并创建 / 更新 GitHub Release。
- 三位数版本和四位数版本都可以是正式版，不是“四位数就一定是预发布”。
- 四位数版本可以先作为预发布发出，后面再原地转成正式版。
- 应用里比较版本时，`1.1.10-6+36` 会按 `1.1.10.6` 去比较。

## 更新日志写法规则（强制）

以后写 `docs/releases/v*.md` 时，必须按**用户视角**写，只写这三类：

1. **新增**
   - 新功能
   - 新入口
   - 新页面
   - 新能力

2. **优化**
   - 体验优化
   - 设计优化
   - 性能优化
   - 稳定性优化
   - 现有功能体验变好

3. **移除**
   - 删除功能
   - 下线入口
   - 去掉旧逻辑

### 严禁这样写

- 不要写“修复英语”
- 不要写“修复国际化”
- 不要写“修复某个新功能的小 bug”
- 不要写实现层、技术层、开发者视角描述

### 正确写法原则

如果这次版本的核心是**新增一个功能**，后面哪怕你修的是这个新功能里的 bug，更新日志里也优先写成：

- **新增：xxx 功能**
- **优化：xxx 功能体验**

而不是写成：

- **修复：xxx 功能 bug**

也就是说：

- 面向用户看起来是“第一次拥有这个能力” → 写 **新增**
- 面向用户看起来是“这个能力更顺、更稳、更好用” → 写 **优化**
- 面向用户看起来是“这个能力没了” → 写 **移除**

### 一个典型例子

如果这次主要工作是把国际化语言功能做出来，但过程中修了很多英文显示问题，最终更新日志应该写：

- 新增：英语与繁体中文等多语言界面支持
- 优化：多语言界面的文案与排版一致性

不要写：

- 修复：英语显示问题

### 总结

更新日志不是给开发者看的提交记录，而是给用户看的版本摘要。

默认优先级：

`新增 > 优化 > 移除 > 修复细节`

如果一个版本既有“新增功能”又有“为这个新功能补 bug”，更新日志默认归类到**新增 / 优化**，不要把重点写成“修复 bug”。

## 一、当前发布机制

当前 workflow 在 [.github/workflows/android-build.yml](D:/Users/34045/Desktop/cursor/flutter/mikcb/.github/workflows/android-build.yml) 里，触发条件是：

```yml
on:
  push:
    tags:
      - 'v*'
```

也就是说：

1. 先本地提交。
2. 再推送 `main`。
3. 再推送一个 `v*` tag。
4. Actions 才会开始跑。

workflow 还会做这些事：

- 读取 [pubspec.yaml](D:/Users/34045/Desktop/cursor/flutter/mikcb/pubspec.yaml) 的 `version:`
- 读取 `docs/releases/v版本号.md`
- 应用内更新检查会优先读取 `docs/releases/latest.json`，所以每次发版前后都要同步这个文件
- 用 tag 名覆盖 Android 最终产物的 `versionName`
- 创建或更新 GitHub Release

## 二、先分清两套版本

### 1. 包内版本

写在 [pubspec.yaml](D:/Users/34045/Desktop/cursor/flutter/mikcb/pubspec.yaml) 里。

例如：

```yaml
version: 1.1.10-6+36
```

含义：

- `1.1.10` 是基线版本
- `-6` 对应第四段版本号
- `+36` 是 build number / versionCode，必须递增

### 2. 对外版本

体现在 Git tag 和 GitHub Release 上。

例如：

- tag：`v1.1.10.6`
- release notes：`docs/releases/v1.1.10.6.md`

### 3. 这两者的关系

当前代码里，版本比较会把：

- `1.1.10-6+36`
- `1.1.10.6`

当成同一个数值版本。

这点在 [lib/services/app_update_service.dart](D:/Users/34045/Desktop/cursor/flutter/mikcb/lib/services/app_update_service.dart) 和 [test/services/app_update_service_test.dart](D:/Users/34045/Desktop/cursor/flutter/mikcb/test/services/app_update_service_test.dart) 里已经覆盖到了。

## 三、三位数和四位数的真实规则

### 1. 三位数版本

例子：

- `1.1.11`

这种通常用来表示一个新的正式基线版本。

### 2. 四位数版本

例子：

- `1.1.10.6`

这种通常表示某个基线版本下面的编号版本。

但要注意：

- 四位数版本不等于“只能预发布”
- 四位数版本也可以是正式版

### 3. 当前实际发行习惯

现在这套习惯更准确的说法是：

- 新的测试包，通常继续递增第四段，例如 `11105 -> 11106`
- 如果某个四位数测试版验证通过，可以直接把这个同版本号原地转成正式版
- 不需要再单独发一个三位数版本来“接管”它

也就是说：

- `11106` 可以先是预发布
- 后面也可以还是 `11106`，只是从预发布改成正式

## 四、什么时候算预发布，什么时候算正式

这里不要混淆“版本号”和值得不值得升级这两个概念。

### 1. GitHub 上是不是预发布

看的是 GitHub Release 的 `prerelease` 状态。

不是看：

- 是三位数还是四位数
- tag 名里有没有 `beta`

### 2. 应用里版本高低怎么比

看的是版本号数值。

例如当前代码会把：

- `1.1.10-6+36`
- `1.1.10.6`

视为同版本。

所以：

- 如果你已经安装了 `11106` 预发布
- 后面只是把 GitHub 上同一个 `11106` Release 原地转正式

应用不应该再把它判定成“更高的新版本”，因为版本号没变。

## 五、最短发布流程

### 1. 发布一个新的预发布测试版

假设目标是发布 `11107`：

1. 修改 [pubspec.yaml](D:/Users/34045/Desktop/cursor/flutter/mikcb/pubspec.yaml)

```yaml
version: 1.1.10-7+37
```

2. 新建 release notes 文件：

```text
docs/releases/v1.1.10.7.md
```

3. 提交：

```bash
git add pubspec.yaml docs/releases/v1.1.10.7.md
git commit -m "chore: cut v1.1.10.7 prerelease"
```

4. 打 tag：

```bash
git tag v1.1.10.7
```

5. 推送：

```bash
git push origin main
git push origin v1.1.10.7
```

6. 去 GitHub Actions 看 `Android Build` 是否启动。

### 2. 把已有四位数预发布原地转正式

假设 `v1.1.10.6` 已经发成预发布，现在你决定它直接转正式：

1. 不新增 `v1.1.10`
2. 不改成别的版本号
3. 直接保留 `v1.1.10.6`
4. 去 GitHub Release 页面编辑这个已有 Release
5. 把它从 `prerelease` 改成正式发布

这一步的关键是：

- 改的是 Release 状态
- 不是重新发一个三位数版本

### 3. 发布一个新的正式基线

假设目标是发布 `1.1.11`：

1. 修改 [pubspec.yaml](D:/Users/34045/Desktop/cursor/flutter/mikcb/pubspec.yaml)

```yaml
version: 1.1.11+37
```

2. 新建 release notes 文件：

```text
docs/releases/v1.1.11.md
```

3. 提交：

```bash
git add pubspec.yaml docs/releases/v1.1.11.md
git commit -m "chore: cut v1.1.11 release"
```

4. 打 tag：

```bash
git tag v1.1.11
```

5. 推送：

```bash
git push origin main
git push origin v1.1.11
```

## 六、推荐发布前检查

最少检查这几项：

1. `pubspec.yaml` 版本号是否改对
2. `docs/releases/` 文件名是否和 tag 完全一致
3. `build number` 是否比上一个版本大
4. 工作区是否干净：`git status`
5. 如果要验证预发布检测，新的测试包版本号必须严格高于当前已安装版本

如果要更稳一点，再做：

```bash
flutter analyze
flutter test
```

## 七、常见坑

### 1. 为什么 Actions 没跑

通常只有这几种原因：

- 只推了 `main`，没推 tag
- tag 不是 `v*`
- tag 还在本地，没 `git push origin vX.Y.Z`

### 2. 为什么 Release 说明没生效

workflow 读的是：

```text
docs/releases/v${VERSION_NAME}.md
```

所以：

- tag 是 `v1.1.10.6`
- 文件就必须叫 `docs/releases/v1.1.10.6.md`

少一个点、少一个数字、写成别的名字，都不会自动读取到。

### 3. 为什么预发布检测不到新版本

先检查这几件事：

1. 当前安装包版本是否真的低于新的测试版本
2. 应用内是否打开了“检测预发布版本”
3. 远端对应 Release 是否仍然是 `prerelease`

如果你只是把同一个 `11106` 从预发布改成正式：

- 这是渠道状态变化
- 不是版本号升级

所以应用不应该把它提示成“比当前更高的新版本”。

### 4. 为什么本地 commit 了还是没反应

因为本地 commit 不会触发 GitHub Actions。

一定要：

```bash
git push origin main
git push origin v你的版本号
```

## 八、最常用模板

### 新预发布模板

```bash
git add pubspec.yaml docs/releases/v1.1.10.X.md
git commit -m "chore: cut v1.1.10.X prerelease"
git tag v1.1.10.X
git push origin main
git push origin v1.1.10.X
```

`pubspec.yaml`：

```yaml
version: 1.1.10-X+递增编号
```

### 四位数预发布转正式模板

```text
GitHub Releases 页面
找到 v1.1.10.X
编辑 Release
取消 prerelease
保存
```

### 新正式基线模板

```bash
git add pubspec.yaml docs/releases/v1.1.11.md
git commit -m "chore: cut v1.1.11 release"
git tag v1.1.11
git push origin main
git push origin v1.1.11
```

`pubspec.yaml`：

```yaml
version: 1.1.11+递增编号
```
