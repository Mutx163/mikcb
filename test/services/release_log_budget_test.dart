import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/logging/app_debug_log.dart';

/// A5-26：正式包的日志白名单 + 频控。
///
/// 为什么需要这组测试：`appDebugLog` 的 release 分支在 `flutter test`（debug 构建）
/// 里**根本走不到** —— `kDebugMode` 恒为 true。旧白名单只有两个定位标签，
/// 于是「考试提醒失败线上零日志」这类问题永远没有自动化证据可抓。
/// 把判定逻辑提成 [releaseLogAllowed] 之后，白名单与频控这两条真正会出错的地方
/// 才有牙齿。
void main() {
  tearDown(() {
    // 频控状态是进程内单例，不还原会串到下一条用例。
    debugSetReleaseLogClock(null);
  });

  group('白名单', () {
    test('会静默失败的关键链路都在名单里', () {
      // 三类各挑一个代表标签：考试提醒、云同步、导入解析。
      for (final tag in <String>[
        'ExamReminder',
        'webdav_sync_coordinator',
        'WarehouseService',
        'WarehouseImportDebug',
      ]) {
        expect(
          releaseForensicTags,
          contains(tag),
          reason: '$tag 的失败在线上无其它落盘痕迹，被丢掉就等于静默失效',
        );
      }
    });

    test('旧的取证标签没有在白名单扩容时丢失', () {
      expect(releaseForensicTags, contains('LocationTimeApply'));
      expect(releaseForensicTags, contains('LocationTimeApplyUI'));
    });

    test('周期性成功路径的标签不在名单里（总量控制的第一道闸）', () {
      // 这三个是「每帧 / 每次刷新 / 每次下载」都打的成功路径，
      // 放进来只会冲掉整机 logcat 的历史窗口，不会带来任何诊断能力。
      for (final tag in <String>['MiuiLive', 'HomeWidget', 'BingWallpaper']) {
        expect(
          releaseForbiddenHighFrequencyTags,
          contains(tag),
          reason: '这条用例本身就是「别把高频标签加进白名单」的记录',
        );
        expect(
          releaseForensicTags,
          isNot(contains(tag)),
          reason: '$tag 是周期性成功路径，不能进 release 白名单',
        );
      }
    });

    test('不在白名单的标签一律拒绝', () {
      debugSetReleaseLogClock(() => DateTime(2026, 10, 27, 12));
      expect(releaseLogAllowed('SomeRandomTag'), isFalse);
      expect(releaseLogAllowed('MiuiLive'), isFalse);
    });

    test('白名单里每个标签在 lib/ 下都有真实调用点（清单不是荣誉榜）', () {
      // 白名单条目一旦失真（改了标签名、删了调用点），这份名单就会变成
      // 「以为有日志、其实一条都不会打」——那正是 A5-26 想根治的形态。
      //
      // ⚠️ 扫描时必须排除定义白名单的这个文件：它自己就写着这些字符串，
      // 不排除的话每条都「找得到调用点」，断言永远绿 —— 第一版真的这么错过
      // 一次（`SyncSnapshot` / `IcsImport` 两个没有调用点的标签照样通过），
      // 靠咬合探针才发现。
      const definitionFile = 'lib/logging/app_debug_log.dart';
      final sources = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.path.replaceAll(r'\', '/').endsWith(definitionFile)) {
          continue;
        }
        sources.add(entity.readAsStringSync());
      }
      final joined = sources.join('\n');

      final missing = <String>[];
      for (final tag in releaseForensicTags) {
        final mentioned =
            joined.contains("'$tag'") ||
            joined.contains('"$tag"');
        if (!mentioned) {
          missing.add(tag);
        }
      }
      expect(missing, isEmpty, reason: '白名单标签在 lib/ 下找不到调用点：$missing');
    });
  });

  group('频控', () {
    // ⚠️ 这里的上限是**人推出来的绝对数**，不是 `releaseLogBudgetPerTagPerWindow`
    // 的值：直接拿常数当期望值的话，把常数改成 1 亿测试照样绿（第一版就是
    // 这么写的，咬合探针「关掉频控」时全绿才发现）。每标签每分钟最多 60 行
    // 是「不会把整机 logcat 历史窗口冲掉」的口径上限，实现收紧不能放开到这里
    // 以上。
    const hardCeilingPerTagPerWindow = 60;

    test('容量常数落在合理区间（不是关掉的）', () {
      expect(releaseLogBudgetPerTagPerWindow, greaterThanOrEqualTo(5));
      expect(
        releaseLogBudgetPerTagPerWindow,
        lessThanOrEqualTo(hardCeilingPerTagPerWindow),
      );
      expect(releaseLogBudgetWindow.inSeconds, inInclusiveRange(10, 600));
    });

    test('窗口内放行上限条，超出即丢', () {
      var now = DateTime(2026, 10, 27, 12);
      debugSetReleaseLogClock(() => now);

      var allowed = 0;
      // 故意打 5000 次，与实现常数无关：无论常数被改成多少，
      // 一个窗口里真正放出去的行数都必须收敛在硬上限之内。
      for (var i = 0; i < 5000; i++) {
        if (releaseLogAllowed('ExamReminder')) {
          allowed++;
        }
      }
      expect(allowed, greaterThan(0));
      expect(
        allowed,
        lessThanOrEqualTo(hardCeilingPerTagPerWindow),
        reason: '单标签单窗口放行 $allowed 行，超过 logcat 总量控制的口径上限',
      );
      // 时间不前进，仍然是同一个窗口。
      now = now.add(const Duration(seconds: 59));
      expect(releaseLogAllowed('ExamReminder'), isFalse);
    });

    test('跨窗口恢复（不是永久封禁）', () {
      var now = DateTime(2026, 10, 27, 12);
      debugSetReleaseLogClock(() => now);

      for (var i = 0; i < 5000; i++) {
        releaseLogAllowed('ExamReminder');
      }
      expect(releaseLogAllowed('ExamReminder'), isFalse);

      now = now.add(releaseLogBudgetWindow);
      expect(
        releaseLogAllowed('ExamReminder'),
        isTrue,
        reason: '新窗口应重新有额度，否则一次刷屏会让该标签永久失声',
      );
    });

    test('频控按标签独立计数，一个标签刷屏不挤掉另一个', () {
      final now = DateTime(2026, 10, 27, 12);
      debugSetReleaseLogClock(() => now);

      for (var i = 0; i < 5000; i++) {
        releaseLogAllowed('ExamReminder');
      }
      expect(releaseLogAllowed('ExamReminder'), isFalse);
      expect(
        releaseLogAllowed('WarehouseService'),
        isTrue,
        reason: '考试提醒刷屏不该让导入解析的日志一起消失',
      );
    });
  });
}
