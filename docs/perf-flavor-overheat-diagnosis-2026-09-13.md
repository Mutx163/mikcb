# 性能版（.profile）静止发热诊断报告

- 日期：2026-09-13 23:30–23:40
- 设备：Redmi 25079RPDCC（`turner`，120Hz 出图 / 最高 165Hz 档）
- 构建：`perfProfile`（`applicationIdSuffix .profile`，包名 `com.mutx163.qingyu.profile`）
- 现象：**打开后静止放置不动，机身持续发烫**
- 结论：**非渲染管线 / 非玻璃链路问题。是 `flutter_blackbox` 诊断浮层的悬浮球带一个永不停止的循环动画，导致静止时仍以 120fps 满速出帧。正式版（release）因 `kReleaseMode` 直接短路，不存在该浮层。**

---

## 一、实测数据（同一台机、同一份代码、同一时段）

| 场景 | 6 秒 CPU 时间 | 折算 CPU | SurfaceView 出帧 |
| --- | --- | --- | --- |
| 性能版，静止 | **10.24 s** | **≈205%** | **120.00 fps 持续**（连续 8 个采样周期都是 119.95~120.06） |
| 正式版，静止 | 1.02 s | ≈17% | 1.18~5.11 fps |
| 性能版，关掉浮层后，静止 | **0.07 s** | **≈1.2%** | 0.88 fps |

线程级拆分（性能版发热态，6 秒窗口）：

```
5.73 s  主线程 (.qingyu.profile)
2.55 s  DartWorker
1.34 s  1.raster
```

即 UI / Dart / 光栅化三线同时满载 —— 这是「每帧都在出图」的典型形态，而不是某个单点卡死。

**因果验证**：仅把浮层开关置 `false`（改 prefs 后强停重启，不改一行代码），CPU 从 205% 掉到 1.2%（**约 170 倍**），出帧从 120fps 掉到 <1fps。截图对照可见右下角蓝色悬浮球消失。

### 修复后的真机复测（2026-09-13 23:50–23:56，同一台机）

| 状态 | CPU | 出帧 |
| --- | --- | --- |
| 浮层默认关，静止（8 秒窗口） | 0.01 s ≈ **0.1%** | 0.37 fps |
| **浮层强制打开**，静止（8 秒窗口） | 0.02 s ≈ **0.25%** | 仅启动那一次 |
| 稳态连续 6 轮 × 6 秒 | 0.02~0.07 s ≈ **0.2~1.2%** | — |
| 同时段正式版（对照） | 0.02 s ≈ 0.3% | — |

第二行是关键：**浮层开着也不再烧** —— 因为 `none()` trigger 让悬浮球（连同那个
`repeat()` 动画）压根不再被构造。旧代码在同样状态下是 10.24 s / 120 fps。

> 一处需要如实记下的观察：修复后 app **刚启动的头一两分钟内**，仍会出现几段
> 主线程 + `io.worker` 型的高 CPU（实测 6 秒窗口 5.6~8.0 s），随后归于安静。
> 同期出帧只有 3~5 fps（不是 120 fps），且浮层当时是关闭的 —— 也就是说旧代码
> 同样会有，**与本次修复无关**，属于另一件事（启动预热 / 更新检查 / 服务启动类
> 的一次性后台活动），值得单独查但不影响本结论。

---

## 二、根因链

1. `lib/blackbox_adapters.dart:267`
   ```dart
   trigger: const BlackBoxTrigger.floatingButton(),
   ```
   悬浮球**常驻**（非按需呼出）。

2. `lib/ui/debug/blackbox_overlay_preferences.dart:15,26`
   ```dart
   bool _visible = true;
   ...
   _visible = savedVisible ?? legacyVisible ?? true;
   ```
   默认**可见**。且真机上 `shared_prefs/FlutterSharedPreferences.xml` 里**没有** `flutter.blackbox_overlay_visible` 键 → 走默认 `true`。

3. `lib/ui/debug/blackbox_host.dart:27` —— `visible == true` 时用 `BlackBoxOverlay(child: 整个 app)` 包住全局。

4. 上游 `flutter_blackbox-0.7.0/lib/src/overlay/blackbox_overlay.dart:955-961`
   ```dart
   _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
   if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
     _ctrl.repeat(reverse: true);   // 1.5s 一轮的缩放呼吸，永不停止
   }
   ```
   **这是出帧源**：`repeat()` 的 `AnimationController` 每帧都请求新帧 → 120fps 无限重绘（屏幕被要求以最高档出图）。

5. 叠加放大项（同一 overlay 内）：
   - `blackbox.dart:305` 启动 `FpsMonitor`（`addPersistentFrameCallback`，每帧统计）；
   - `blackbox_overlay.dart:981` 订阅 FPS 流，**每 250ms `setState`**；
   - 网络 / 崩溃流订阅同样会触发 `setState`。

6. **第二重功耗放大器**：`MainActivity.kt:261-274`
   ```kotlin
   transaction.setFrameRate(surfaceControl, peak,
       Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
       Surface.CHANGE_FRAME_RATE_ALWAYS)   // peak = 屏幕最高档
   ```
   本机实测该层 `requestedFrameRate: {165.00 Hz}`。它不产生帧，但把每次出图都钉在最高刷新率上，让上面那 120fps 的重绘以最大代价跑。

---

## 三、为什么正式版没事

`blackbox_host.dart:18` 首行 `if (kReleaseMode) return child;` ——
`prodRelease` 构建里浮层**根本不会被构造**，`repeat()` 动画不存在，所以静止时 <5fps / ≈17% CPU（正常常驻水平）。

**这也意味着这是「性能版 / 调试版专属」问题**，与玻璃档位、壁纸、渐变模糊等用户设置无关（实测设置未变，仅切换构建即复现 / 消失）。

---

## 四、附带的方法论失误（重要，避免重复踩）

`adb shell dumpsys gfxinfo <pkg>` **对 Flutter 应用无效**：Flutter 用独立 SurfaceView(BLAST) 直接提交 buffer，不经 HWUI 的 view 树，所以 gfxinfo 全程显示 `Total frames rendered: 3`（看着像"很安静"），而真实情况是 120fps。

**正确看法**：
```bash
adb logcat | grep BufferQueueProducer   # 看 queueBuffer: fps=...
adb shell dumpsys SurfaceFlinger | grep -A5 requestedFrameRate
```
CPU 用 `/proc/<pid>/stat` 的 `utime+stime`（$14+$15）做差；线程级用 `/proc/<pid>/task/*/stat`。

---

## 五、修复（2026-09-13 23:45 实施）

根因分两层，修法也分两层。

**1. 出帧源：去掉常驻悬浮球** — `lib/blackbox_adapters.dart`

```dart
trigger: const BlackBoxTrigger.floatingButton();   // 改前
trigger: const BlackBoxTrigger.none();             // 改后
```

上游 overlay 的 `if (trigger is FloatingButtonTrigger || _isHudPinned)`
（`blackbox_overlay.dart:221`）因此不再构造 `_DraggableFloatingButton`，
那句 `..repeat(reverse: true)` 不复存在 —— 这是唯一真正产生帧的东西。

**2. 默认状态：浮层默认关闭** — `lib/ui/debug/blackbox_overlay_preferences.dart`

`_visible` 默认 `true` → `false`（`load()` 的兜底默认值同步改）。浮层是调试工具
而不是日常 UI，默认不该给整棵树套一层 RepaintBoundary + 常驻 store 订阅。

**3. 补回入口** — 因为不再有悬浮球当入口：

- `lib/ui/debug/blackbox_host.dart` 新增 `openBlackBoxPanel()`：浮层关着时先启用、
  等两帧等 overlay 完成 `registerOverlayCallbacks`，再 `BlackBox.open()`
  （否则 `BlackBox.open()` 在未挂载时是静默 no-op）。
- `lib/screens/timetable_settings_screen.dart` 开发者选项区新增一行
  「打开调试面板」（l10n key `debugUiOverlayOpenPanelTitle`，6 语言已补、
  `l10n_untranslated.json` 为 `{}`）。
- 原有的「调试 UI 叠层」开关保留 —— 它现在只控制浮层是否挂载，默认关。

**4. 回归守卫** — `test/ui/debug/blackbox_host_test.dart` 新增
「defaults to hidden so the overlay never runs unless enabled」。

**验证**：`flutter analyze lib test` → No issues found；
`test/ui/debug` + `test/widgets/timetable_settings_screen_test.dart` → **12 passed**；
真机复测见 §一。

**有意未改**：`MainActivity.kt:261-274` 的 `CHANGE_FRAME_RATE_ALWAYS` 保持原样。
它是既有的高刷修复，且静止不再出帧后「钉住峰值刷新率」的代价已可忽略；
贸然改动会回退高刷效果，应作为独立议题评估。

---

## 六、需要复核的既有结论

2026-09-13 当天记录的多项"性能版真机实测"数字，若测量时浮层是开着的（默认就是开着），则**存在被该 120fps 背景噪声污染的可能**，建议在关掉浮层后复测关键项：

- `f9ba002b` 的「静止 92~100% CPU / 60fps 重绘」（若真为玻璃自激，关浮层后应仍能复现；若不复现则需重新归因）；
- 各处「玻璃链路静止零持续成本」类断言；
- 「高刷未生效 / 63fps vs 115fps」类对比（浮层持续出帧会改变高刷申请的实际表现）。

> 注：正式版（release）从无该浮层，所以在正式版上做的测量不受影响。
