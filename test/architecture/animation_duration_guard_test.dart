import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

/// 架构守卫：动画时长必须走统一换算，不许裸写 `Duration(milliseconds: N)`。
///
/// ## 为什么需要它
///
/// 「通用 → 页面转场速度」（0.5×–2.5×）在界面上写的是「数值越大**动画**越快」，
/// 用户 2026-10-20 明确要求它「覆盖整个软件所有的动画」。但在 2026-10-20 之前，
/// 全仓 121 处时长里只有 16 处主动接了换算，其余 105 处裸写死 —— 调速度对它们
/// 完全无效，用户最先撞上的就是「日视图缩放没被改到」。
///
/// 那次整改把动画类全部改成 `N.scaledMs` 或 `bindController(...)`。但**靠人记**
/// 守不住：新写一个弹层、一个 AnimatedXxx，很容易又写成裸的
/// `const Duration(milliseconds: 200)`，而且这种漏改**没有任何测试会红**（时长
/// 只影响快慢，不影响正确性）—— 用户要很久以后才会发现「这个动画不跟设置」。
///
/// ## 判据
///
/// 不是「一个都不许有」：确实存在**逻辑时间**（等待、超时、防抖、轮询、冷却），
/// 它们跟着倍率缩放会让功能坏掉（扫码 2400ms 超时变成 1200ms、宏回放 15s 超时
/// 变成 7.5s）。所以用**逐文件计数棘轮**：每个文件允许的裸写法条数记在
/// [_allowedBareDurations] 里，新增即红、减少也必须同步（只降不升）。
///
/// 要新增一处逻辑时间，必须同时把该文件的配额 +1 并在提交信息里说明理由
/// （为什么它不能被缩放）。这和本仓其他棘轮（行数、单元数）是同一条纪律：
/// 增长可以是正当的，但必须被看见，不能静默发生。
void main() {
  test('动画时长走统一换算：裸 Duration(milliseconds:) 逐文件棘轮', () {
    final counts = _scanBareDurations();

    final unexpected = <String>[];
    for (final entry in counts.entries) {
      final allowed = _allowedBareDurations[entry.key] ?? 0;
      if (entry.value > allowed) {
        unexpected.add('${entry.key}: ${entry.value} 处（配额 $allowed）');
      }
    }

    expect(
      unexpected,
      isEmpty,
      reason:
          '这些文件新增了裸写的动画时长，不会跟随「页面转场速度」设置。\n'
          '改法：动画用 `N.scaledMs`（相对路径 import 到\n'
          'lib/ui/hyperos/hyperos_motion.dart）；长命 AnimationController 用\n'
          '`HyperosMotionPlatform.bindController(c, baseMs)`。\n'
          '如果这处确实是**逻辑时间**（等待/超时/防抖/冷却，缩放会坏功能），\n'
          '在 test/architecture/animation_duration_guard_test.dart 的\n'
          '_allowedBareDurations 里给该文件 +1，并在提交信息说明理由。\n'
          '明细：\n${unexpected.join('\n')}',
    );
  });

  test('棘不是空转：扫描器确实能认出裸写法，也放过已换算的写法', () {
    // 判别力自检：如果扫描器的正则写坏了（比如永远返回空），上一条会永远绿。
    expect(
      _countBareIn('AnimatedContainer(duration: Duration(milliseconds: 180), x)'),
      1,
      reason: '裸写法必须被认出',
    );
    expect(
      _countBareIn('AnimatedContainer(duration: 180.scaledMs, x)'),
      0,
      reason: '已换算写法不得误报',
    );
    expect(
      _countBareIn('controller.duration = HyperosMotionPlatform.scaledDuration(3)'),
      0,
      reason: '另一条换算入口不得误报',
    );
  });

  test('配额表只降不升：迁走之后必须同步下调', () {
    final counts = _scanBareDurations();
    final stale = <String>[];
    for (final entry in _allowedBareDurations.entries) {
      final actual = counts[entry.key] ?? 0;
      if (actual < entry.value) {
        stale.add('${entry.key}: 配额 ${entry.value} 实际 $actual');
      }
    }
    expect(
      stale,
      isEmpty,
      reason:
          '这些文件已经迁走了一部分裸写法，配额要跟着降下来（棘轮只降不升）。'
          '明细：\n${stale.join('\n')}',
    );
  });
}

/// 每个文件**允许**保留的裸 `Duration(milliseconds: N)` 条数。
///
/// 全部是**逻辑时间**：等一个真实动作完成（网络/磁盘/用户输入）的时间，
/// 与动画快慢无关，跟着倍率缩放会让超时提前触发或防抖失效。
/// 数字取 2026-10-20 整改完成后的实测值。
const Map<String, int> _allowedBareDurations = <String, int>{
  // ── 自动化回放器：全部是步骤等待与超时（含 15s 步骤超时）──
  'lib/widgets/warehouse_macro_replayer.dart': 11,

  // ── 设置页自动保存防抖：连续拖动时合并写盘 ──
  'lib/screens/live_settings_subpages.dart': 4,
  'lib/screens/settings/settings_appearance.dart': 1,
  'lib/screens/settings/settings_appearance_editor.dart': 1,
  'lib/screens/settings/settings_course_card.dart': 1,
  'lib/screens/settings/settings_general.dart': 1,
  'lib/screens/settings/settings_home_navigation.dart': 1,
  'lib/screens/settings/settings_timetable_page.dart': 1,
  'lib/screens/settings/settings_home_widget.dart': 3,

  // ── Future.delayed：让出/等下一页渲染完成，不是动画 ──
  'lib/main.dart': 1,
  'lib/screens/add_course_screen.dart': 1,
  'lib/screens/settings/settings_home_backdrop_flow.dart': 1,
  'lib/screens/settings/settings_live.dart': 3,
  'lib/screens/user_guide_screen.dart': 2,
  'lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart': 3,
  'lib/services/debug_deep_link_navigator.dart': 1,

  // ── Timer.periodic：轮询/演示节拍 ──
  'lib/screens/hyperos_showcase_screen.dart': 2,
  'lib/screens/miuix_showcase/feedback.dart': 1,
  'lib/services/app_log_service.dart': 1,
  'lib/services/app_update_service.dart': 2,
  'lib/services/qr_transfer/qr_transfer_session.dart': 1,
  'lib/services/support_creator_service.dart': 1,

  // ── 逻辑判据 / 预算窗口 ──
  'lib/controllers/day_view_transition_controller.dart': 1, // 长按判据
  'lib/screens/live_diagnostics_log_viewer_screen.dart': 2,
  'lib/screens/weather_city_picker_screen.dart': 1, // 搜索防抖
  'lib/utils/home_startup_visual_primer.dart': 1, // 预热预算
  // 性能探针的 CPU/RSS 采样周期。是**逻辑时间**：跟着「转场速度」倍率缩放会
  // 让采样在 2.5× 时变成每 100ms 读一次 /proc —— 诊断件反过来给自己加负载。
  'lib/utils/perf_probe.dart': 1,
  'lib/widgets/app_startup_splash.dart': 1, // 最短展示时长
  'lib/widgets/class_reminder_sheet.dart': 2, // 等弹层布局完成
  'lib/widgets/wallpaper_position_picker_sheet.dart': 1,
  'lib/widgets/home_top_menu_popup.dart': 1, // 菜单收起预算（宿主闸门）
  'lib/ui/hyperos/preview_bake_boundary.dart': 2, // 烘焙间隔/超时
  'lib/ui/hyperos/hyperos_overscroll.dart': 2, // 触觉冷却 + epoch
  'lib/ui/hyperos/hyperos_collapsible_top_app_bar.dart': 1, // 吸附冷却窗口
  'lib/ui/hyperos/hyperos_select.dart': 1, // 弹窗提交延迟
  'lib/ui/hyperos/hyperos_tooltip.dart': 1, // 悬停等待
  'lib/ui/hyperos/inspire/inspire_header_blur.dart': 1, // 延迟序列
  'lib/ui/hyperos/widgets/tiles.dart': 1, // 按下高亮延迟

  // ── 等一个动画播完（时序必须与那段动画同步，不能单独缩放）──
  'lib/ui/hyperos/hyperos_snackbar.dart': 1, // 等退场动画播完再拆宿主
  'lib/ui/hyperos/hyperos_sheet.dart': 1, // 动态算出的已换算值

  // ── 换算实现本体 + 文档注释里的写法示例 ──
  'lib/services/android_animation_scale_service.dart': 1,
  'lib/ui/hyperos/hyperos_motion.dart': 2,
  'lib/widgets/open_container.dart': 1,
};

/// 扫描 `lib/` 下每个文件里「裸写的毫秒时长」条数。
///
/// 「裸写」= `Duration(milliseconds: …)` 且**不是**换算入口的产物：
/// - 同一行出现 `scaledMs` / `scaledDuration` → 已换算，不算；
/// - `N.scaledMs` 形式根本不含 `Duration(milliseconds`，天然不算。
Map<String, int> _scanBareDurations() {
  final root = Directory(GuardSource.resolve('lib'));
  final result = <String, int>{};

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final rel = GuardSource.repoRelative(entity.path);
    var count = 0;
    for (final line in entity.readAsLinesSync()) {
      if (_countBareIn(line) > 0) {
        count += 1;
      }
    }
    if (count > 0) {
      result[rel] = count;
    }
  }
  return result;
}

/// 单行计数（也给判别力自检用）。
int _countBareIn(String line) {
  final pattern = RegExp(r'Duration\(\s*milliseconds\s*:');
  if (!pattern.hasMatch(line)) {
    return 0;
  }
  if (line.contains('scaledMs') || line.contains('scaledDuration')) {
    return 0;
  }
  return 1;
}
