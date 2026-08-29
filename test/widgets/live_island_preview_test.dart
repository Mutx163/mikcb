import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/live_island_preview.dart';

/// 超级岛预览与原生 islandCriticalText 组合规则的一致性测试。
///
/// 原生摘要态胶囊只有两个区域：
/// * 摄像头左侧 = 通知 smallIcon（不承载文本）；
/// * 摄像头右侧 = islandCriticalText = [islandCourseName, islandLocation,
///   islandCriticalStatusText] 过滤空白后拼接。
/// 因此「显示内容」那组开关（课程名 / 简称 / 地点 / 倒计时 / 阶段文字 /
/// 前缀）改变的都是**右侧文本**：
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
    bool enableMiuiIslandLabelImage = false,
    MiuiIslandLabelStyle miuiIslandLabelStyle = MiuiIslandLabelStyle.textOnly,
    MiuiIslandLabelContent miuiIslandLabelContent =
        MiuiIslandLabelContent.courseNameAndLocation,
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
      enableMiuiIslandLabelImage: enableMiuiIslandLabelImage,
      miuiIslandLabelStyle: miuiIslandLabelStyle,
      miuiIslandLabelContent: miuiIslandLabelContent,
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

  testWidgets('全开关打开：课前岛右侧是「课程名 + 地点 + 距上课」', (tester) async {
    await pumpPreview(tester, displayConfig: display());

    expect(
      textMatching(RegExp(r'^高等数学 三教-401 距上课\d+分钟$')),
      findsOneWidget,
      reason: '右侧应是与原生一致的 islandCriticalText：课程名+地点+状态',
    );
    expect(find.text('高等数学 三教-401'), findsNothing,
        reason: '课程名与地点不再单独渲染在左侧');
    expect(find.text('上课中'), findsNothing);
  });

  testWidgets('全开关打开：课中岛右侧裸倒计时，下课岛右侧「距下课」', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(),
      forDuringEnd: true,
    );

    // 阶段小标题仍然标注两个岛
    expect(find.text('上课中'), findsOneWidget);
    expect(find.text('下课提醒'), findsOneWidget);

    // 课中胶囊：裸倒计时（criticalTimeText，无前缀）
    expect(
      textMatching(RegExp(r'^高等数学 三教-401 \d+分钟$')),
      findsOneWidget,
      reason: '课中显示倒计时时，右侧状态位是 criticalTimeText 裸倒计时',
    );

    // 下课胶囊：带前缀的距下课倒计时
    expect(textMatching(RegExp(r'^高等数学 三教-401 距下课\d+分钟$')), findsOneWidget);
  });

  testWidgets('关闭地点：右侧文本只剩课程名与状态', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showLocation: false),
    );

    expect(textMatching(RegExp(r'^高等数学 距上课\d+分钟$')), findsOneWidget);
    expect(find.textContaining('三教-401'), findsNothing);
  });

  testWidgets('关闭课程名：右侧文本只剩地点与状态', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showCourseName: false),
    );

    expect(textMatching(RegExp(r'^三教-401 距上课\d+分钟$')), findsOneWidget);
    expect(find.textContaining('高等数学'), findsNothing);
  });

  testWidgets('关闭倒计时但保留阶段词：右侧状态位是阶段词', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showCountdown: false),
    );

    expect(find.text('高等数学 三教-401 即将上课'), findsOneWidget);
    expect(find.textContaining('距上课'), findsNothing);
  });

  testWidgets('关闭倒计时与阶段词：右侧只剩课程名与地点', (tester) async {
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

    expect(textMatching(RegExp(r'^高等数学 三教-401 \d+分钟$')), findsOneWidget);
    expect(find.textContaining('距上课'), findsNothing);
  });

  testWidgets('非小米机型且未开自定义标签：左侧图标位为空', (tester) async {
    // 测试环境没有原生通道，机型探测回落到 false（= 非小米系）。
    await pumpPreview(tester, displayConfig: display());

    expect(find.byIcon(Icons.access_time), findsNothing,
        reason: '非小米机型没有超级岛，左侧图标位不应画阶段图标');
    expect(
      textMatching(RegExp(r'^高等数学 三教-401 距上课\d+分钟$')),
      findsOneWidget,
      reason: '机型只影响左侧图标位，右侧文本照常渲染',
    );
  });

  testWidgets('开启自定义标签：左侧渲染标签文字，右侧仍是完整文本', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(
        enableMiuiIslandLabelImage: true,
        miuiIslandLabelContent: MiuiIslandLabelContent.courseName,
      ),
    );

    expect(find.text('高等数学'), findsOneWidget,
        reason: '左侧图标位显示自定义标签（纯文字样式）');
    expect(
      textMatching(RegExp(r'^高等数学 三教-401 距上课\d+分钟$')),
      findsOneWidget,
      reason: '左图不参与 islandCriticalText 拼接，右侧文本保持不变',
    );
  });
}
