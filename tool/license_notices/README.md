# 开源许可清单（NOTICES）重生成

APK 里的 `assets/licenses/NOTICES.gz` 是开源许可页的数据源。
去 Flutter 化之后 `flutter_assets/NOTICES.Z` 不再生成，这份快照必须自己维护——
不重生成，许可页会一直显示一堆早已不存在的 Dart 包，同时**漏掉所有真正打进包的
AndroidX / Compose / Kotlin / miuix / okhttp / 友盟 / ML Kit 依赖**。

## 现状（2026-11-10 已重生成）

- 快照重生成前 1,494,850 B（gzip 128,519 B）、1658 条，名字全是 Flutter 时代：
  `flutter_miuix` / `flutter_blackbox` / `university_timetable` / `skia` / `angle` / `icu` …，
  androidx / Compose / 友盟 / ML Kit 一条没有。
- 2026-11-10 用本脚本重生成：**234 条、2,067,198 B（gzip 38,837 B）**，
  SHA-256 `41de0ee219f29cfc6ed46f1058336495de85d33341c943ea5c63be1415a977bb`，
  守卫钉值已同步更新（`FlutterAssetsDecouplingGuardTest` 的 `binaryPins`）。
- App 解析器要求固定格式，见 `OpenSourceLicensesModel.kt` 的 `parseFlutterNotices`：
  条目间 **一整行恰好 80 个 `-`**，条目内「名字行 + 空行 + 正文」。

## 跑法（安静窗口，一条命令）

```powershell
cd C:\cursor\mikcb

# 1) 先试写（默认就是试写，不会动 assets）
python tool/license_notices/generate_notices.py --report .tmp/notices-report.md

# 2) 确认报告里没有未解析项后真写
python tool/license_notices/generate_notices.py --write --report .tmp/notices-report.md

# 3) 校验产物可被 App 解析
python tool/license_notices/generate_notices.py --verify
```

第 1 步会通过 `scripts/safe-gradle.ps1` 跑 `:app:dependencies --configuration
prodReleaseRuntimeClasspath`（只解析依赖，不编译、不占编译任务）。也可以自己存好输出再喂：

```powershell
pwsh -File scripts/safe-gradle.ps1 :app:dependencies --configuration prodReleaseRuntimeClasspath --console=plain > .tmp/deps.txt
python tool/license_notices/generate_notices.py --from-deps .tmp/deps.txt --dry-run
```

## 写完还必须做的一件事

`android/app/src/test/kotlin/com/mutx163/qingyu/pages/about/FlutterAssetsDecouplingGuardTest.kt`
把这份文件的 SHA-256 钉死了（`licenses/NOTICES.gz` 那一行）。重生成后必须同步更新钉值，
否则 L2 会红：

```powershell
(Get-FileHash android/app/src/main/assets/licenses/NOTICES.gz -Algorithm SHA256).Hash.ToLower()
```

## 许可正文从哪来

`templates/` 里的 Apache-2.0 / MIT / BSD 文本由 `--harvest`（默认取当前 assets 里那份旧快照）
**原样摘出**，不是手抄。缺模板时脚本会拒绝生成，避免打出「只有许可名、正文空着」的半成品。

## 归属判定顺序

1. 构件内自带的 `META-INF/LICENSE` / `LICENSE` / `COPYING` 正文；
2. 构件内嵌的 `META-INF/maven/**/pom.xml` 的 `<licenses>`（空容器构件只有这一份元数据）；
3. 构件 MANIFEST 的 `Bundle-License` 头（Guava 系 / jspecify / error_prone 都带）；
4. 本地 Gradle 缓存里的 POM `<licenses>`；
5. 本地没有 POM 时联网补取（Google Maven → Maven Central → 阿里云，缓存在 `.tmp/pom-cache/`）；
   POM 不写 `<licenses>` 但文件头声明了 Apache-2.0 的，按 `pom-*-header` 记；
6. 已知 group 的确定归属（androidx.* / org.jetbrains* / okhttp / okio / miuix → Apache-2.0）；
7. 空占位构件（不含 class，只用于依赖图占位）如实写明，不当作第三方代码；
8. 闭源商业 SDK（友盟、ML Kit、GMS）→ 写「闭源组件 + 条款链接」；
9. 都不中 → **未解析**，正文如实说明并写进报告，绝不静默吞。

判定来源会打印成 `artifact=… manifest=… pom=… pom-remote=… group=… proprietary=… unresolved=…`
的统计，报告另列未解析坐标与工程内模块，便于逐条复核。

### 2026-11-10 首次重生成的实际结果

- `prodReleaseRuntimeClasspath` 共 **234 条**，gzip **38,837 B**（旧文件 128,519 B）。
- 覆盖：androidx **124**（以 `androidx.` 开头的坐标；另有 14 条 `org.jetbrains.androidx.*`
  多平台移植，按「含 androidx 字样」口径才是 138）、Compose 71、miuix 12、友盟 4、
  ML Kit 6、OkHttp、Kotlin 18、本应用 GPL 1。
- 来源分布：`artifact=2 artifact-pom=3 manifest=3 pom=146 pom-remote=66 pom-remote-header=1
  pom-remote-short=10 placeholder=1 group=1 self=1 unresolved=0`。
- `pom-remote-short` 的 10 条是 Google 的闭源条款（ML Kit ToS / Android SDK License），
  正文写「条款名 + 官方条款链接」，不冒充开源许可。

## 联网说明

默认会联网补取缺失的 POM；`--offline` 可完全离线（只用本地缓存与构件自带证据）。
补取的 POM 缓存在 `.tmp/pom-cache/`，不进版本库。

## 已知边界

- 工程内模块（`android/third_party/miuix-ui`）不在 Maven 缓存：归属写在
  `DEFAULT_PROJECT_LICENSES`（上游 compose-miuix-ui/miuix 为 Apache-2.0）。
- 友盟 / ML Kit 是闭源 SDK，许可页只能写「闭源 + 条款链接」，这是如实描述，不是缺失。
- 发版前若新增依赖，重跑一次即可；**建议把 `--verify` 加进发版自检**。
