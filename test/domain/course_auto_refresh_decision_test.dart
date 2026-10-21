import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/course_auto_refresh_decision.dart';

/// 「课表自动更新」什么时候该跑。
///
/// ## 期望值从哪来
///
/// 全部由人按用户口径推出来的，不是从实现里抄的。用户 2026-10-21 的原话是
/// 「每次打开软件更新，或者隔一天自动更新，或者隔多少小时，可自定义时间」，
/// 于是三种时机各自照着那句话写用例，外加三条用户没直说但必须成立的边界：
///
/// 1. 同一天反复切前台**不能**反复抓（否则一天能抓十几次）；
/// 2. 失败之后**不能**每次切回来就重试（对教务是反复登录、对用户是反复打扰）；
/// 3. 跨零点那一档不能漏（0:00～7:29 之间不能因为「今天还没到点」而整天不跑）。
void main() {
  group('每次打开', () {
    // mode 不写：everyLaunch 就是默认值，写出来属于冗余实参。
    const schedule = CourseAutoRefreshSchedule(enabled: true);

    test('从没成功过 → 立刻跑', () {
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 9),
          lastSuccess: null,
          lastAttempt: null,
        ),
        CourseAutoRefreshDecision.run,
      );
    });

    test('20 分钟前刚成功 → 跳过（切前后台的冷却）', () {
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 9, 20),
          lastSuccess: DateTime(2026, 10, 21, 9),
          lastAttempt: DateTime(2026, 10, 21, 9),
        ),
        CourseAutoRefreshDecision.wait,
      );
    });

    test('冷却期边界：刚好满 30 分钟就该跑', () {
      expect(kCourseAutoRefreshLaunchCooldown, const Duration(minutes: 30));
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 9, 30),
          lastSuccess: DateTime(2026, 10, 21, 9),
          lastAttempt: DateTime(2026, 10, 21, 9),
        ),
        CourseAutoRefreshDecision.run,
      );
    });

    test('功能关着时永远不跑', () {
      expect(
        decideCourseAutoRefresh(
          schedule: const CourseAutoRefreshSchedule(),
          now: DateTime(2026, 10, 21, 9),
          lastSuccess: null,
          lastAttempt: null,
        ),
        CourseAutoRefreshDecision.disabled,
      );
    });
  });

  group('每隔 N 小时', () {
    test('隔一天（48 小时）没到点就等、到了就跑', () {
      const schedule = CourseAutoRefreshSchedule(
        enabled: true,
        mode: CourseAutoRefreshMode.intervalHours,
        intervalHours: 48,
      );
      final last = DateTime(2026, 10, 19, 10);
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 9),
          lastSuccess: last,
          lastAttempt: last,
        ),
        CourseAutoRefreshDecision.wait,
        reason: '47 小时，还差一小时',
      );
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 10),
          lastSuccess: last,
          lastAttempt: last,
        ),
        CourseAutoRefreshDecision.run,
        reason: '整 48 小时，到点',
      );
    });

    test('从没成功过 → 立刻跑，不必等满一个间隔', () {
      expect(
        decideCourseAutoRefresh(
          schedule: const CourseAutoRefreshSchedule(
            enabled: true,
            mode: CourseAutoRefreshMode.intervalHours,
            intervalHours: 168,
          ),
          now: DateTime(2026, 10, 21, 9),
          lastSuccess: null,
          lastAttempt: null,
        ),
        CourseAutoRefreshDecision.run,
      );
    });
  });

  group('每天定时', () {
    const schedule = CourseAutoRefreshSchedule(
      enabled: true,
      mode: CourseAutoRefreshMode.dailyAt,
    );

    test('过了今天的点、今天还没抓过 → 跑', () {
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 8),
          lastSuccess: DateTime(2026, 10, 20, 8),
          lastAttempt: DateTime(2026, 10, 20, 8),
        ),
        CourseAutoRefreshDecision.run,
      );
    });

    test('今天已经抓过 → 不再抓', () {
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 20),
          lastSuccess: DateTime(2026, 10, 21, 7, 45),
          lastAttempt: DateTime(2026, 10, 21, 7, 45),
        ),
        CourseAutoRefreshDecision.wait,
      );
    });

    test('凌晨 0:00～7:29：还没到今天的点，但最近一档是昨天，昨天没跑就该跑', () {
      // 这条是「跨零点漏一整天」那个坑的钉子：若拿「今天的 7:30」去比，
      // 05:00 时刻的判据会变成「今天这一档还没到 → 上次成功在其后 → 跳过」，
      // 而昨天整天其实都没抓过。
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 5),
          lastSuccess: DateTime(2026, 10, 19, 7, 40),
          lastAttempt: DateTime(2026, 10, 19, 7, 40),
        ),
        CourseAutoRefreshDecision.run,
      );
    });

    test('凌晨那一档已经抓过（昨天 7:45 抓的）→ 等到今天的点再说', () {
      expect(
        decideCourseAutoRefresh(
          schedule: schedule,
          now: DateTime(2026, 10, 21, 5),
          lastSuccess: DateTime(2026, 10, 20, 7, 45),
          lastAttempt: DateTime(2026, 10, 20, 7, 45),
        ),
        CourseAutoRefreshDecision.wait,
      );
    });
  });

  group('失败冷却', () {
    test('10 分钟前刚失败过 → 不重试', () {
      expect(
        decideCourseAutoRefresh(
          schedule: const CourseAutoRefreshSchedule(
            enabled: true,
          ),
          now: DateTime(2026, 10, 21, 9, 10),
          lastSuccess: DateTime(2026, 10, 20, 9),
          lastAttempt: DateTime(2026, 10, 21, 9),
        ),
        CourseAutoRefreshDecision.wait,
        reason: '尝试晚于成功 = 上次失败，冷却期内一律安静',
      );
    });

    test('冷却期过（40 分钟）→ 允许重试', () {
      expect(
        decideCourseAutoRefresh(
          schedule: const CourseAutoRefreshSchedule(
            enabled: true,
          ),
          now: DateTime(2026, 10, 21, 9, 40),
          lastSuccess: DateTime(2026, 10, 20, 9),
          lastAttempt: DateTime(2026, 10, 21, 9),
        ),
        CourseAutoRefreshDecision.run,
      );
    });

    test('尝试时间等于成功时间（上次成功）不算失败', () {
      expect(
        decideCourseAutoRefresh(
          schedule: const CourseAutoRefreshSchedule(
            enabled: true,
            mode: CourseAutoRefreshMode.intervalHours,
            intervalHours: 1,
          ),
          now: DateTime(2026, 10, 21, 10, 1),
          lastSuccess: DateTime(2026, 10, 21, 9),
          lastAttempt: DateTime(2026, 10, 21, 9),
        ),
        CourseAutoRefreshDecision.run,
      );
    });
  });

  group('最近一档时刻', () {
    test('未到点取昨天、已过点取今天', () {
      expect(
        mostRecentDailySlot(DateTime(2026, 10, 21, 6, 59), 8 * 60),
        DateTime(2026, 10, 20, 8),
      );
      expect(
        mostRecentDailySlot(DateTime(2026, 10, 21, 8), 8 * 60),
        DateTime(2026, 10, 21, 8),
      );
      expect(
        mostRecentDailySlot(DateTime(2026, 10, 21, 23, 59), 0),
        DateTime(2026, 10, 21),
      );
    });
  });

  group('配置的容错', () {
    test('未知模式 / 越界小时 / 越界时刻都退回合法值', () {
      final parsed = CourseAutoRefreshSchedule.fromJson(<String, Object?>{
        'enabled': true,
        'mode': 'nonsense',
        'intervalHours': 9999,
        'dailyMinuteOfDay': -30,
      });
      expect(parsed.mode, CourseAutoRefreshMode.everyLaunch);
      expect(parsed.intervalHours, kCourseAutoRefreshMaxIntervalHours);
      expect(parsed.dailyMinuteOfDay, 0);
      expect(parsed.enabled, isTrue);
    });

    test('整份不是 Map 时退回默认（功能关闭）', () {
      final parsed = CourseAutoRefreshSchedule.fromJson('garbage');
      expect(parsed.enabled, isFalse);
      expect(parsed.mode, CourseAutoRefreshMode.everyLaunch);
    });

    test('enabled 只认真正的 true：字符串 "true" 不算开', () {
      expect(
        CourseAutoRefreshSchedule.fromJson(<String, Object?>{
          'enabled': 'true',
        }).enabled,
        isFalse,
      );
    });

    test('copyWith 会把越界输入夹进合法区间', () {
      const base = CourseAutoRefreshSchedule();
      expect(base.copyWith(intervalHours: 0).intervalHours, 1);
      expect(base.copyWith(intervalHours: 500).intervalHours, 168);
      expect(base.copyWith(dailyMinuteOfDay: 2000).dailyMinuteOfDay, 1439);
    });

    test('toJson → fromJson 往返不丢设定', () {
      const original = CourseAutoRefreshSchedule(
        enabled: true,
        mode: CourseAutoRefreshMode.intervalHours,
        intervalHours: 12,
        dailyMinuteOfDay: 8 * 60 + 15,
      );
      final round = CourseAutoRefreshSchedule.fromJson(original.toJson());
      expect(round.enabled, isTrue);
      expect(round.mode, CourseAutoRefreshMode.intervalHours);
      expect(round.intervalHours, 12);
      expect(round.dailyMinuteOfDay, 8 * 60 + 15);
    });
  });
}
