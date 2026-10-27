import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/logging/app_debug_log.dart';

/// `appDebugLog` 在正式包（release）里「谁配留下」的验收测试（2026-10-27）。
///
/// ## 为什么需要它
///
/// `appDebugLog` 在 `!kDebugMode` 时默认整条丢弃。这对每帧都打的高频探针是必须的，
/// 但它同时是一台**放大器**：任何挂在它上面的失败路径，在线上都变成「用户说没收到
/// 考试提醒 / 云同步没反应 / 恢复了一半」，而 logcat 里一个字都没有。
///
/// 2026-09-26 的审计把这条列为「静默失效的放大器」：`exam_reminder_service.dart:523`
/// 用的 tag 是 `ExamReminder`，不在当时的白名单（只有 LocationTimeApply 两个）里，
/// 于是「重建提醒失败」在正式包零痕迹 —— 而那条正是用户唯一能感知的失败。
///
/// 所以这里钉三件事：
/// 1. **关键链路的 tag 必须在名单里**（用真实源码里的 tag 字面量，不是抄一遍）；
/// 2. **高频 tag 必须不在名单里**（否则 release logcat 会被刷爆，等于没做取舍）；
/// 3. **频控真的会掐**（白名单只是第一道闸，没有频控的话一个循环就能刷满）。
void main() {
  group('release 日志白名单', () {
    test('考试提醒的 tag 在名单里（2026-09-26 审计点名的静默失效）', () {
      // 直接从源码里读真实 tag，避免测试与实现各写一份字面量后悄悄漂移。
      final source = File('lib/services/exam_reminder_service.dart').readAsStringSync();
      final tags = RegExp(r"appDebugLog\(\s*'([^']+)'")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();

      expect(tags, isNotEmpty, reason: '考试提醒服务里应当有 appDebugLog 调用');
      for (final tag in tags) {
        expect(
          releaseLogAllowed(tag),
          isTrue,
          reason: '考试提醒用 tag `$tag` 打失败日志，但它不在 release 白名单里 —— '
              '线上「这次没提醒」将没有任何痕迹',
        );
      }
    });

    test('云同步协调器的 tag 在名单里', () {
      expect(releaseLogAllowed('webdav_sync_coordinator'), isTrue);
    });

    test('高频 tag 不在名单里（否则 release logcat 被刷爆）', () {
      for (final tag in releaseForbiddenHighFrequencyTags) {
        expect(
          releaseLogAllowed(tag),
          isFalse,
          reason: '`$tag` 是高频成功路径，放进白名单会把 logcat 刷满',
        );
      }
    });

    test('两份名单不重叠（想加一个 tag 必须先改掉拒绝它的理由）', () {
      final overlap = releaseForensicTags.intersection(
        releaseForbiddenHighFrequencyTags,
      );
      expect(overlap, isEmpty, reason: '同一个 tag 不能既在名单里又在拒绝名单里');
    });

    test('白名单不是「什么都放行」——随机 tag 一律拒绝', () {
      for (final tag in ['SomeRandomTag', 'HomeWidget', 'MiuiLive', '']) {
        expect(releaseLogAllowed(tag), isFalse, reason: '`$tag` 不该被放行');
      }
    });
  });

  group('release 日志频控（白名单之外的第二个闸）', () {
    tearDown(() => debugSetReleaseLogClock(null));

    test('同一窗口内超出上限即丢弃', () {
      // 这条不推进时钟（全程同一个窗口），所以是 final；
      // 下面「跨窗口后配额恢复」那条才需要 var。
      final now = DateTime(2026, 10, 27, 10);
      debugSetReleaseLogClock(() => now);

      const tag = 'ExamReminder';
      var allowed = 0;
      for (var i = 0; i < releaseLogBudgetPerTagPerWindow * 3; i++) {
        if (releaseLogAllowed(tag)) allowed++;
      }

      expect(
        allowed,
        releaseLogBudgetPerTagPerWindow,
        reason: '一个窗口内最多放行 $releaseLogBudgetPerTagPerWindow 行',
      );
    });

    test('跨窗口后配额恢复', () {
      var now = DateTime(2026, 10, 27, 10);
      debugSetReleaseLogClock(() => now);

      const tag = 'ExamReminder';
      for (var i = 0; i < releaseLogBudgetPerTagPerWindow + 5; i++) {
        releaseLogAllowed(tag);
      }
      expect(releaseLogAllowed(tag), isFalse, reason: '窗口内应已用尽');

      now = now.add(releaseLogBudgetWindow + const Duration(seconds: 1));
      expect(releaseLogAllowed(tag), isTrue, reason: '跨窗口后配额应恢复');
    });

    test('配额按 tag 独立计数（一个 tag 刷满不影响另一个）', () {
      final now = DateTime(2026, 10, 27, 10);
      debugSetReleaseLogClock(() => now);

      for (var i = 0; i < releaseLogBudgetPerTagPerWindow + 3; i++) {
        releaseLogAllowed('ExamReminder');
      }
      expect(releaseLogAllowed('ExamReminder'), isFalse);
      expect(
        releaseLogAllowed('webdav_sync_coordinator'),
        isTrue,
        reason: '频控必须按标签独立，否则一条吵的链路会掐掉所有别的链路',
      );
    });
  });
}
