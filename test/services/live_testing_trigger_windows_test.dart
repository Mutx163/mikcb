import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/live_testing_fixture_service.dart';
import 'package:university_timetable/services/live_testing_trigger.dart';

/// `buildCourseTestWindow` 是纯可推导逻辑：合成窗口、钟面跨度、暂停缓冲
/// 全部由输入唯一决定，期望值按注释规则人工推算（不从实现抄）。
///
/// 只验 Dart 侧可推导字段；原生实际起岛/收岛行为不在此层（integration_test
/// 职责）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final base = DateTime(2026, 3, 23, 10, 15);

  group('classic windows (sessionLength == null)', () {
    test('before-class: 3-minute lead + 3-minute course + 20s buffer', () {
      final window = buildCourseTestWindow(
        now: base,
        stage: LiveCourseTestStage.beforeClass,
      );

      expect(window.start, base.add(const Duration(minutes: 3)));
      expect(window.end, base.add(const Duration(minutes: 6)));
      expect(window.clockEnd, window.end);
      expect(window.suspendBuffer, const Duration(seconds: 20));
      expect(
        window.sessionEndFrom(base),
        base.add(const Duration(minutes: 6, seconds: 20)),
      );
    });

    test('during-class: anchored 1 minute in, ends 4 minutes later', () {
      final window = buildCourseTestWindow(
        now: base,
        stage: LiveCourseTestStage.duringClass,
      );

      expect(window.start, base.subtract(const Duration(minutes: 1)));
      expect(window.end, base.add(const Duration(minutes: 4)));
      expect(window.clockEnd, window.end);
      expect(window.suspendBuffer, const Duration(seconds: 20));
    });
  });

  group('quick preview windows (sessionLength = 30s)', () {
    const session = Duration(seconds: 30);

    test('before-class: 25s countdown + 5s tail, 5s buffer', () {
      final window = buildCourseTestWindow(
        now: base,
        stage: LiveCourseTestStage.beforeClass,
        sessionLength: session,
      );

      expect(window.start, base.add(const Duration(seconds: 25)));
      expect(window.end, base.add(const Duration(seconds: 30)));
      expect(window.suspendBuffer, const Duration(seconds: 5));
      // 整段倒计时锁在 beforeClass：start 之前的 25 秒都是倒计时窗口。
      expect(
        window.start.isBefore(window.end),
        isTrue,
      );
      // 摘除终点 = end + 5s（UI 按钮翻回「试弹」态的时刻）。
      expect(
        window.sessionEndFrom(base),
        base.add(const Duration(seconds: 35)),
      );
    });

    test('during-class: already started, ends after 30s', () {
      final window = buildCourseTestWindow(
        now: base,
        stage: LiveCourseTestStage.duringClass,
        sessionLength: session,
      );

      expect(window.start, base.subtract(const Duration(seconds: 2)));
      expect(window.end, base.add(const Duration(seconds: 30)));
      expect(window.suspendBuffer, const Duration(seconds: 5));
      expect(
        window.sessionEndFrom(base),
        base.add(const Duration(seconds: 35)),
      );
    });
  });

  group('display clock span (minute-precision clock face)', () {
    test('sub-minute windows get stretched to a 1-minute clock span', () {
      final window = buildCourseTestWindow(
        now: base,
        stage: LiveCourseTestStage.beforeClass,
        sessionLength: const Duration(seconds: 30),
      );

      // 窗口 30 秒（< 1 分钟）→ 显示钟面拉到 start + 1min，避免
      // 「10:16 - 10:16」的零时长观感；真实 end 不变。
      expect(
        window.clockEnd.difference(window.start),
        const Duration(minutes: 1),
      );
      expect(window.clockEnd, base.add(const Duration(seconds: 85)));
      expect(
        LiveTestingFixtureService.formatClock(window.start),
        '10:15',
      );
      expect(
        LiveTestingFixtureService.formatClock(window.clockEnd),
        '10:16',
      );
    });
    test('classic windows keep the real end as clock end', () {
      final window = buildCourseTestWindow(
        now: base,
        stage: LiveCourseTestStage.duringClass,
      );

      expect(window.clockEnd, window.end);
      expect(
        LiveTestingFixtureService.formatClock(window.clockEnd),
        '10:19',
      );
    });
  });

  group('global session slot (cross-page state)', () {
    test(
      'currentLiveCourseTestSession lazily clears an expired session',
      () {
        final past = DateTime(2026, 3, 23, 10, 15);
        activeLiveCourseTestSession = LiveCourseTestSession(
          stage: LiveCourseTestStage.beforeClass,
          courseName: '高数',
          sessionEnd: past,
        );

        // 已过期：读侧清槽并视为无会话（岛已被原生收尾）。
        expect(currentLiveCourseTestSession(), isNull);
        expect(activeLiveCourseTestSession, isNull);
      },
    );

    test('currentLiveCourseTestSession keeps an in-flight session', () {
      addTearDown(() => activeLiveCourseTestSession = null);
      final future = DateTime.now().add(const Duration(seconds: 30));
      final session = LiveCourseTestSession(
        stage: LiveCourseTestStage.duringClass,
        courseName: '大物',
        sessionEnd: future,
      );
      activeLiveCourseTestSession = session;

      expect(currentLiveCourseTestSession(), same(session));
      expect(activeLiveCourseTestSession, same(session));
    });
  });
}
