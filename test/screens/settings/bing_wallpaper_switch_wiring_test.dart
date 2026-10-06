import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「每天自动更换」那颗开关的**接线**护栏。
///
/// ## 为什么扫源码而不是渲染 widget
///
/// 这颗开关的真凶不是逻辑，是**它被挂在哪棵树上**：壁纸弹层的正文插在根覆盖层里、
/// 不在宿主的 widget 树下，宿主 `setState` 带不动它（见
/// `settings_appearance_editor.dart` 里那张 `ValueListenableBuilder` 上方的注释）。
/// 而自动换开关写的是 `BingWallpaperStore`、**不走草稿**，所以那条"草稿版本号"
/// 通知对它完全无感。
///
/// 后果长这样（2026-10-06 用户实报）：点下去开关**纹丝不动**，其实值已经写进台账了
/// —— 于是下载照跑、提示照弹，只是不亮。上一轮补的那句 `setState` 在这个宿主上就是
/// 空操作，**一次 widget 测试抓不到**（渲染出来的树是我们自己搭的，怎么搭都对）。
///
/// 而把开关行本身用 `ValueListenableBuilder` 订阅 `BingWallpaperStore.notifier`，
/// 就与"它被挂在哪棵树上"无关了：无论弹层里还是页面里，台账一变就重建。这条护栏
/// 盯的就是这个订阅还在不在 —— 谁哪天嫌"多余"把它删了，这里立刻红。
///
/// 扫源码是本仓已有的做法（见 `test/architecture/dependency_guards_test.dart`）。
/// mixin 源码（读一次即可，本文件所有断言都在它上面做）。
final String mixinSource = File(
  'lib/screens/settings/settings_home_backdrop_flow.dart',
).readAsStringSync();

void main() {

  /// `_buildBingWallpaperTile` 的方法体（从方法名到下一个同缩进的成员声明为止）。
  String tileBody() {
    final start = mixinSource.indexOf('Widget _buildBingWallpaperTile(');
    expect(start, greaterThanOrEqualTo(0), reason: '找不到 _buildBingWallpaperTile');
    // 从 `start` 往后找下一个顶层成员声明（两个空格缩进的非空行，且不含分号结尾的
    // 语句续行）—— 用下一个 `Widget ` / `void ` / `Future<` 成员起点做边界就够了。
    final tail = mixinSource.substring(start);
    final next = RegExp(
      r'\n  (?:Widget|void|Future<|bool|double|int|String|List<)[^\n]*\n',
    ).firstMatch(tail.substring(1));
    return next == null ? tail : tail.substring(0, next.start + 1);
  }

  group('自动换开关的重建来源', () {
    test('开关行订阅 BingWallpaperStore.notifier（不靠宿主 setState）', () {
      final body = tileBody();
      expect(
        body,
        contains('ValueListenableBuilder<int>'),
        reason: '开关行必须自己订阅通知 —— 宿主 setState 带不动覆盖层里的弹层正文',
      );
      expect(
        body,
        contains('valueListenable: BingWallpaperStore.notifier'),
        reason: '订阅的必须是台账那个 notifier（开关值就存在它后面）',
      );
    });

    test('开关的 value 仍然读台账，不是宿主草稿', () {
      expect(
        tileBody(),
        contains('value: BingWallpaperStore.instance.autoApplyEnabled'),
      );
    });

    test('_setBingAutoApply 先写台账再看结局，不把 null 当终局', () {
      final start = mixinSource.indexOf('Future<void> _setBingAutoApply(');
      expect(start, greaterThanOrEqualTo(0));
      final end = mixinSource.indexOf('/// 自动换的执行体', start);
      final body = mixinSource.substring(start, end);
      expect(
        body,
        contains('setAutoApplyEnabled(value)'),
        reason: '开关值必须落盘，否则重启后又回到未开启',
      );
      // ⚠️ 这条不是洁癖：用户点开关时亲眼看过「正在换成今天的壁纸」，若失败路径
      // 一声不吭，表现就回到「点了没反应」（2026-10-06）。
      expect(body, contains('_applyDailyBingWallpaper()'));
    });

    test('失败与「不是今天」两条结局都必须给用户出声', () {
      final body = _applyDailyBingWallpaperBody();
      expect(body, contains('BingAutoApplyOutcome.failed'));
      expect(body, contains('BingAutoApplyOutcome.alreadyApplied'));
      expect(body, contains('BingAutoApplyOutcome.appliedStale'));
      // 三种结局各自都要有话可说。
      expect(
        RegExp('showAppToast').allMatches(body).length,
        greaterThanOrEqualTo(3),
        reason: '三种结局都必须各弹一句，缺一个就退回成静默失败',
      );
    });

    test('自动换**直接落盘**，不推位置页（2026-10-06 用户口径）', () {
      final body = _applyDailyBingWallpaperBody();
      expect(
        body,
        contains('_applyBackdropChange('),
        reason: '直接写草稿就是「在默认状态下直接应用」',
      );
      // 这两条是把「自动」功能做成了半手动的那根刺：会弹一页要用户拖动取景再点
      // 「完成」，还会顺手把壁纸设置弹层收掉，看着像「点了没反应」。
      expect(body, isNot(contains('_openBackdropPositionEditor')));
      expect(body, isNot(contains('pushWallpaperPositionPickerPage')));
      // 不进「最近使用」：历史只有 10 条，自动换每天记一条会把用户自己挑的挤出去。
      expect(
        body,
        isNot(contains('WallpaperHistoryEntry(')),
        reason: '自动换补记历史会挤掉用户自己的图，还会连带删文件',
      );
    });
  });
}

/// [_applyDailyBingWallpaper] 的方法体（到下一个成员声明为止）。
///
/// 边界用后面那个成员的文档首行标记 —— 少一个成员就要改这里，所以别把标记写在
/// 方法体内的注释里。
String _applyDailyBingWallpaperBody() {
  final start = mixinSource.indexOf('Future<void> _applyDailyBingWallpaper()');
  expect(start, greaterThanOrEqualTo(0), reason: '找不到 _applyDailyBingWallpaper');
  final end = mixinSource.indexOf('/// 推图库页 → 点一张', start);
  expect(end, greaterThan(start), reason: '找不到 _applyDailyBingWallpaper 的下一个成员');
  return mixinSource.substring(start, end);
}