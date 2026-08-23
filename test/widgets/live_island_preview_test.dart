import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/live_island_preview.dart';

/// 超级岛预览与原生 islandCriticalText 组合规则的一致性测试。
///
/// 原生摘要态胶囊文本 = [islandCourseName, islandLocation,
/// islandCriticalStatusText] 过滤空白后拼接：
/// * 课程名受 showCourseName 门控（5 字截断）；
/// * 地点受 showLocation 门控；
/// * 课中且显示倒计时时状态位是裸倒计时（无“距下课”前缀），
///   其余情况才是 visibleStatusText（阶段词 / 距上课 / 距下课）。
void main() {
  LiveDisplaySettings display({
    bool showCourseName = true,
    bool showLocation = true,
    bool showCountdown = true,
    LiveCountdownTextStyle countdownTextStyle = LiveCountdownTextStyle.smart,
    bool showStageText = true,
    bool useShortName = false,
    bool hidePrefixText = false,
  }) {
    return LiveDisplaySettings(
      showCourseName: showCourseName,
      showLocation: showLocation,
      showCountdown: showCountdown,
      countdownTextStyle: countdownTextStyle,
      showStageText: showStageText,
      useShortName: useShortName,
      hidePrefixText: hidePrefixText,
      duringClassTimeDisplayMode: LiveDuringClassTimeDisplayMode.nearest,
      enableMiuiIslandLabelImage: false,
      miuiIslandLabelStyle: MiuiIslandLabelStyle.iconAndText,
      miuiIslandLabelContent: MiuiIslandLabelContent.courseNameAndLocation,
      miuiIslandLabelFontColor: '#FFFFFF',
      miuiIslandLabelFontWeight: MiuiIslandLabelFontWeight.medium,
      miuiIslandLabelRenderQuality: MiuiIslandLabelRenderQuality.standard,
      miuiIslandLabelFontSize: 12,
      miuiIslandLabelOffsetX: 0,
      miuiIslandLabelOffsetY: 0,
      miuiIslandLabelLogoPath: null,
      miuiIslandLabelLogoCornerRadius: 2,
      miuiIslandExpandedIconMode: MiuiIslandExpandedIconMode.appIcon,
      miuiIslandExpandedIconPath: null,
    );
  }

  Finder textMatching(RegExp pattern) => find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data != null && pattern.hasMatch(widget.data!),
      );

  Future<void> pumpPreview(
    WidgetTester tester, {
    required LiveDisplaySettings displayConfig,
    bool forDuringEnd = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: LiveIslandPreviewCard(
            display: displayConfig,
            forDuringEnd: forDuringEnd,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('全开关打开：课前岛显示「课程名 + 地点」和「距上课」倒计时', (tester) async {
    await pumpPreview(tester, displayConfig: display());

    expect(find.text('高等数学 三教-401'), findsOneWidget,
        reason: 'showCourseName 与 showLocation 都开启时，左侧信息块应为课程名+地点');
    expect(textMatching(RegExp(r'^距上课\d+分钟$')), findsOneWidget,
        reason: '右侧应是带前缀的上课前倒计时');
    expect(find.text('上课中'), findsNothing);
  });

  testWidgets('全开关打开：课中岛显示裸倒计时而非「上课中」，下课岛显示「距下课」', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(),
      forDuringEnd: true,
    );

    // 阶段小标题仍然标注两个岛
    expect(find.text('上课中'), findsOneWidget);
    expect(find.text('下课提醒'), findsOneWidget);

    // 两个胶囊的信息块都是课程名+地点
    expect(find.text('高等数学 三教-401'), findsNWidgets(2));

    // 课中胶囊：裸倒计时（criticalTimeText，无前缀）
    expect(textMatching(RegExp(r'^\d+分钟$')), findsOneWidget,
        reason: '课中显示倒计时时，右侧应是 criticalTimeText 裸倒计时');

    // 下课胶囊：带前缀的距下课倒计时
    expect(textMatching(RegExp(r'^距下课\d+分钟$')), findsOneWidget);
  });

  testWidgets('关闭地点：信息块只剩课程名', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showLocation: false),
    );

    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('三教-401'), findsNothing);
    expect(find.text('高等数学 三教-401'), findsNothing);
  });

  testWidgets('关闭课程名：信息块只剩地点', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showCourseName: false),
    );

    expect(find.text('三教-401'), findsOneWidget);
    expect(find.text('高等数学'), findsNothing);
  });

  testWidgets('关闭倒计时但保留阶段词：右侧显示阶段词', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showCountdown: false),
    );

    expect(find.text('即将上课'), findsOneWidget);
    expect(find.textContaining('距上课'), findsNothing);
  });

  testWidgets('关闭倒计时与阶段词：右侧为空，信息块保留', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showCountdown: false, showStageText: false),
    );

    expect(find.text('高等数学 三教-401'), findsOneWidget,
        reason: '状态为空时原生仍会渲染课程名与地点');
    expect(find.text('即将上课'), findsNothing);
  });

  testWidgets('隐藏前缀：课前倒计时不再带「距上课」', (tester) async {
    await pumpPreview(tester, displayConfig: display(hidePrefixText: true));

    expect(textMatching(RegExp(r'^\d+分钟$')), findsOneWidget);
    expect(find.textContaining('距上课'), findsNothing);
  });
}
