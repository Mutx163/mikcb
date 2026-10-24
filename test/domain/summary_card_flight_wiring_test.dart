import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/holiday_service.dart';
import 'package:university_timetable/widgets/timetable/summary_card_flight.dart';

import '../helpers_test_app.dart';

/// 摘要卡飞行在**真实首页**里能不能拿到终点（2026-10-23）。
///
/// ## 为什么这条测试必须存在
///
/// `summary_card_flight_test` / `_render_test` / `_overlay_test` 三份都只喂
/// **现成的终点矩形**。如果真实首页里那个 `MeasureFlightTarget` 根本没挂上、
/// 或挂在了不会被构建的那一页上，那三份全绿，而真机上摘要卡**一动也不动**
/// （退回旧裁剪）—— 典型的「测试通过但功能没生效」。
///
/// 所以这里跑真首页：`TimetableScreen` + 真 provider，点星期栏进日视图，断言
/// 转场中**真的出现了飞行的摘要卡，而且它在变大**。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HolidayService mockHolidayService() => HolidayService(
    client: MockClient((request) async {
      final url = request.url.toString();
      if (url.contains('ailcc')) {
        return http.Response('{"code":0,"holiday":{}}', 200);
      }
      return http.Response('{"code":0,"data":[]}', 200);
    }),
  );

  Future<TimetableProvider> createProvider(WidgetTester tester) async {
    late TimetableProvider provider;
    await tester.runAsync(() async {
      provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
        holidayService: mockHolidayService(),
      );
      await provider.initialize();
      final now = DateTime.now();
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: weekStart,
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      final scheme = await provider.createTimeScheme(
        name: '摘要卡飞行测试',
        sections: const [
          SectionTime(startTime: '08:00', endTime: '08:45'),
          SectionTime(startTime: '08:55', endTime: '09:40'),
        ],
      );
      final sections = scheme.sections;
      await provider.addCourse(
        Course(
          id: 'flight-test-course',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 2,
          startTime: sections.first.startTime,
          endTime: sections.last.endTime,
          timeSchemeIdOverride: scheme.id,
        ),
      );
    });
    return provider;
  }

  testWidgets('点星期栏进日视图：转场中出现并长大的飞行摘要卡', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final provider = await createProvider(tester);
    final today = DateTime.now();

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final cell = find.byKey(ValueKey('weekday-header-1-${today.weekday}'));
    expect(cell, findsOneWidget, reason: '星期栏应有今天那一格，否则这条测试空转');
    await tester.tap(cell);

    // 逐帧推进（一次大跨度 pump 只走一帧，ticker 的 elapsed 恒为 0）。
    var found = false;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byType(SummaryFlightCard).evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }

    expect(
      found,
      isTrue,
      reason:
          '转场中应有飞行的摘要卡。找不到说明真实首页里摘要卡的终点没被量到'
          '（MeasureFlightTarget 没挂上 / 挂在非活动页 / 代数不对）——'
          '数据与渲染两份测试都覆盖不到这一环。',
    );

    // ── 真实首页里也必须没被祖先裁掉 ─────────────────────────────────
    //
    // 隔离测试（`summary_card_flight_clip_test`）搭的是一个合成 `Stack`；真实首页
    // 在它外面还有好几层（`TimetableWeekPager` 的 `Stack`、`Positioned.fill`、
    // 首页 Stack…）。任何一层用了默认裁剪，摘要卡在星期栏那条带里的前 40% 都会
    // 被切掉 —— 而 `getRect` 照样返回正确矩形。
    //
    // 判据看 widget 的 `clipBehavior` 声明（不是渲染对象类型：`RenderStack` 的裁剪
    // 在 paint 里 pushClipRect，祖先链里没有 `RenderClipRect`，上一轮就是被这个
    // 骗过）。
    void expectNoAncestorClips(Rect card) {
      final cardElement = tester.element(find.byType(SummaryFlightCard));
      cardElement.visitAncestorElements((element) {
        final w = element.widget;
        var clips = false;
        if (w is Stack) {
          clips = w.clipBehavior != Clip.none;
        } else if (w is ClipRect) {
          clips = w.clipBehavior != Clip.none;
        } else if (w is ClipPath) {
          clips = w.clipBehavior != Clip.none;
        }
        if (clips) {
          final box = element.renderObject;
          if (box is RenderBox && box.hasSize) {
            final r = box.localToGlobal(Offset.zero) & box.size;
            expect(
              r.top,
              lessThanOrEqualTo(card.top + 0.5),
              reason:
                  '真实首页里有一层 ${w.runtimeType} 的裁剪区顶边在 y=${r.top}，'
                  '而飞行摘要卡的顶边在 y=${card.top} —— 卡在星期栏那条带里'
                  '（层上方）的部分会被切掉，「从星期格里长出来」的前 40% 看不见。'
                  '该层裁剪区：$r',
            );
            expect(
              r.left,
              lessThanOrEqualTo(card.left + 0.5),
              reason: '${w.runtimeType} 的裁剪区左边 ${r.left} 在卡左边 ${card.left} 之内',
            );
            expect(
              r.right,
              greaterThanOrEqualTo(card.right - 0.5),
              reason: '${w.runtimeType} 的裁剪区右边 ${r.right} 在卡右边 ${card.right} 之内',
            );
          }
        }
        return true;
      });
    }

    expectNoAncestorClips(tester.getRect(find.byType(SummaryFlightCard)));

    // ── 下半部分必须来自真卡（端到端） ───────────────────────────────
    //
    // 飞行卡的下半部分（计数 / 日程 / 状态 / 考试）由**真卡构建**、经
    // `onLowerSectionBuilt` 存进缓存、再被转场层读走。这条链路任何一环断了，
    // 飞行卡就会少画那一块 —— 落定那一帧胶囊凭空冒出来。
    //
    // 这里种子课表当天有 1 门课，所以真卡的下半部分含「1 门课」。
    // 逐帧推进到淡入完成（k>0.95），此时它必须已经出现。
    var sawLowerSection = false;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(SummaryFlightCard).evaluate().isEmpty) {
        break;
      }
      if (find
          .descendant(
            of: find.byType(SummaryFlightCard),
            matching: find.textContaining('门课'),
          )
          .evaluate()
          .isNotEmpty) {
        sawLowerSection = true;
        break;
      }
    }
    expect(
      sawLowerSection,
      isTrue,
      reason:
          '转场中的飞行摘要卡没有画出真卡的下半部分（计数胶囊等）。这条链路是：'
          '真卡 build → `onLowerSectionBuilt` → `FlightTargetCache.recordSummaryLower`'
          ' → 转场层读 `summaryLower` → 飞行卡渲染。任何一环断了，落定那一帧'
          '胶囊都会凭空冒出来。',
    );

    final first = tester.getRect(find.byType(SummaryFlightCard));
    // 它必须真的在长，而不是定在某个位置不动。
    var grew = false;
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byType(SummaryFlightCard).evaluate().isEmpty) {
        break;
      }
      if (tester.getRect(find.byType(SummaryFlightCard)).width >
          first.width + 1) {
        grew = true;
        break;
      }
    }
    expect(grew, isTrue, reason: '飞行中的摘要卡必须逐帧变大（起点宽 ${first.width}）');

    // 落定：真摘要卡接管，飞行卡退场。
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(
      find.byKey(const ValueKey('day-view-summary')),
      findsOneWidget,
      reason: '落定后应是真摘要卡',
    );
    expect(find.byType(SummaryFlightCard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
