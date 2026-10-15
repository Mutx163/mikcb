import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
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
    List<LiveExpandedDetailField>? expandedDetailFields,
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
      expandedDetailFields: expandedDetailFields,
    );
  }

  Finder textMatching(RegExp pattern) => find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data != null && pattern.hasMatch(widget.data!),
      );

  /// 展开态预览用的示例课程：字段默认齐全（老演示数据的字面值），需要
  /// 验证「空值跳行」时逐字段置空。
  Course sampleCourse({
    String name = '高等数学',
    String? shortName = '高数',
    String teacher = '张老师',
    String location = '三教-401',
    String? note = '带教材与习题册',
    String? description,
  }) {
    return Course(
      id: 'preview-sample',
      name: name,
      shortName: shortName,
      teacher: teacher,
      location: location,
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '08:45',
      note: note,
      description: description,
    );
  }

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
      textMatching(RegExp(r'^高等数学 三教-401 距上课 \d+分钟$')),
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
    expect(textMatching(RegExp(r'^高等数学 三教-401 距下课 \d+分钟$')), findsOneWidget);
  });

  testWidgets('关闭地点：右侧文本只剩课程名与状态', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showLocation: false),
    );

    expect(textMatching(RegExp(r'^高等数学 距上课 \d+分钟$')), findsOneWidget);
    expect(find.textContaining('三教-401'), findsNothing);
  });

  testWidgets('关闭课程名：右侧文本只剩地点与状态', (tester) async {
    await pumpPreview(
      tester,
      displayConfig: display(showCourseName: false),
    );

    expect(textMatching(RegExp(r'^三教-401 距上课 \d+分钟$')), findsOneWidget);
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

  testWidgets('非小米机型未开自定义标签：左侧图标位画阶段小图标', (tester) async {
    // 测试环境没有原生通道，机型探测回落到 false（= 非小米系）。
    // 2026-10-12 起预览对非小米机型也画原生同款阶段小图标（时钟 / 书本 /
    // 倒计时圆环）：既对齐真实通知栏的 setSmallIcon，也避免非小米用户
    // 看到左侧空白误以为功能失效。
    await pumpPreview(tester, displayConfig: display());

    expect(find.byIcon(Icons.access_time), findsOneWidget,
        reason: '课前阶段的白色模板小图标（ic_upcoming）');
    expect(
      textMatching(RegExp(r'^高等数学 三教-401 距上课 \d+分钟$')),
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
      textMatching(RegExp(r'^高等数学 三教-401 距上课 \d+分钟$')),
      findsOneWidget,
      reason: '左图不参与 islandCriticalText 拼接，右侧文本保持不变',
    );
  });

  // --- 展开态预览 ---------------------------------------------------------

  Future<void> pumpExpandedPreview(
    WidgetTester tester, {
    required LiveDisplaySettings displayConfig,
    bool forDuringEnd = false,
    bool promoteDuringClass = true,
    Course? sampleCourse,
    String? nextCourseName,
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
          body: SingleChildScrollView(
            child: LiveIslandExpandedPreviewCard(
              display: displayConfig,
              forDuringEnd: forDuringEnd,
              promoteDuringClass: promoteDuringClass,
              sampleCourse: sampleCourse,
              nextCourseName: nextCourseName,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('展开态预览：课前标题带阶段前缀，正文含状态与时间', (tester) async {
    await pumpExpandedPreview(tester, displayConfig: display());

    expect(find.text('即将上课：高等数学'), findsOneWidget,
        reason: '原生 title_before_class 会拼上课程名');
    expect(
      textMatching(RegExp(r'^距上课 \d+分钟 · 08:00 - 08:45 · 三教-401 · 张老师$')),
      findsOneWidget,
      reason: 'promotedContentText = 状态 · 时间 · 地点 · 教师',
    );
  });

  testWidgets('展开态预览：默认顺序渲染原生默认详情行', (tester) async {
    await pumpExpandedPreview(
      tester,
      displayConfig: display(),
      sampleCourse: sampleCourse(),
      nextCourseName: '大学物理',
    );

    // 默认顺序 progress, status, time, location, teacher, shortName, next, note
    // 课前没有进度块 → 进度行不出现；课前恒定提升 → status 行被原生
    // detailStatusText 的 `&& !shouldPromote` 吞掉，同样不出现（状态改由
    // 正文 promotedContentText 首项承载）。
    expect(find.textContaining('状态：'), findsNothing);
    expect(find.text('时间：08:00 - 08:45'), findsOneWidget);
    expect(find.text('地点：三教-401'), findsOneWidget);
    expect(find.text('教师：张老师'), findsOneWidget);
    expect(find.text('简称：高数'), findsOneWidget);
    expect(find.text('下一节：大学物理'), findsOneWidget);
    expect(find.text('备注：带教材与习题册'), findsOneWidget);
  });

  testWidgets('展开态预览：字段空缺显示灰字占位行，开关有可见反应', (tester) async {
    // 真实课没填地点/教师/备注/简称、也没有下一节：真机会跳过这些行，
    // 预览用灰字占位行解释（开关拨了要有可见反应，2026-10-15 反馈），
    // 只有「时间」渲染真实值。
    await pumpExpandedPreview(
      tester,
      displayConfig: display(),
      sampleCourse: sampleCourse(
        name: '形势',
        shortName: null,
        teacher: '',
        location: '',
        note: null,
      ),
    );

    expect(find.text('地点（未填写，岛上不显示）'), findsOneWidget);
    expect(find.text('教师（未填写，岛上不显示）'), findsOneWidget);
    expect(find.text('下节课（未填写，岛上不显示）'), findsOneWidget);
    expect(find.text('备注（未填写，岛上不显示）'), findsOneWidget);
    // 真实值行照常渲染
    expect(find.text('时间：08:00 - 08:45'), findsOneWidget);
    // 占位行与真实行不再有演示兜底数据
    expect(find.text('地点：三教-401'), findsNothing);
    expect(find.text('教师：张老师'), findsNothing);
  });

  testWidgets('展开态预览：关闭字段开关后占位行随之消失', (tester) async {
    // 开关关掉 → 该字段整行不出（与真机「关闭即不渲染」一致）；
    // 开关开着但课程没填 → 灰字占位。两种状态肉眼可辨。
    await pumpExpandedPreview(
      tester,
      displayConfig: display(expandedDetailFields: const [
        LiveExpandedDetailField.location,
        LiveExpandedDetailField.teacher,
      ]),
      sampleCourse: sampleCourse(
        name: '形势',
        shortName: null,
        teacher: '',
        location: '',
        note: null,
      ),
    );
    expect(find.textContaining('地点'), findsOneWidget);
    expect(find.textContaining('教师'), findsOneWidget);
    expect(find.textContaining('备注'), findsNothing);
  });

  testWidgets('展开态预览：备注取 liveNote（description 回落）', (tester) async {
    // 备注编辑页写的是 description；原生端 note/description 已合并下发，
    // 预览同规则——description 有值时「备注」行必须出现。
    await pumpExpandedPreview(
      tester,
      displayConfig: display(expandedDetailFields: const [
        LiveExpandedDetailField.note,
      ]),
      sampleCourse: sampleCourse(note: null, description: '带教材与习题册'),
    );
    expect(find.text('备注：带教材与习题册'), findsOneWidget);

    // 旧字段 note 仍然优先。
    await pumpExpandedPreview(
      tester,
      displayConfig: display(expandedDetailFields: const [
        LiveExpandedDetailField.note,
      ]),
      sampleCourse: sampleCourse(note: '旧备注', description: '新简介'),
    );
    expect(find.text('备注：旧备注'), findsOneWidget);
  });

  testWidgets('展开态预览：自定义顺序按用户设置排列', (tester) async {
    await pumpExpandedPreview(
      tester,
      displayConfig: display(expandedDetailFields: const [
        LiveExpandedDetailField.note,
        LiveExpandedDetailField.location,
      ]),
      sampleCourse: sampleCourse(),
    );

    expect(find.text('备注：带教材与习题册'), findsOneWidget);
    expect(find.text('地点：三教-401'), findsOneWidget);
    expect(find.textContaining('教师：'), findsNothing,
        reason: '未启用的字段不渲染');
    expect(find.textContaining('下一节：'), findsNothing);

    // 顺序断言：备注在地点之前
    final noteY = tester.getTopLeft(find.text('备注：带教材与习题册')).dy;
    final locY = tester.getTopLeft(find.text('地点：三教-401')).dy;
    expect(noteY, lessThan(locY));
  });

  testWidgets('展开态预览：提升态不渲染阶段行', (tester) async {
    await pumpExpandedPreview(
      tester,
      displayConfig: display(expandedDetailFields: const [
        LiveExpandedDetailField.stage,
      ]),
    );

    // 课前恒定提升 → promotedExpandedDetailText 的 stageTitle 传 null，
    // 阶段信息由标题「即将上课：高等数学」承载，详情区不该再有一行。
    expect(find.text('即将上课：高等数学'), findsOneWidget);
    expect(find.text('即将上课'), findsNothing);
    expect(find.text('已隐藏全部详情行，展开后只显示标题与摘要'), findsOneWidget);
  });

  testWidgets('展开态预览：关掉课中提升通知后阶段与状态行回归', (tester) async {
    await pumpExpandedPreview(
      tester,
      displayConfig: display(
        showCountdown: false,
        expandedDetailFields: const [
          LiveExpandedDetailField.stage,
          LiveExpandedDetailField.status,
        ],
      ),
      forDuringEnd: true,
      promoteDuringClass: false,
    );

    // 课中关掉提升 → 走非提升态 expandedDetailText，stageTitle 与 status 都出；
    // 关掉倒计时是为了避开「课中带进度块时 status 让位给进度行」的另一条规则。
    // 下课提醒恒提升，那张卡片仍然不出这两行。
    expect(find.text('状态：上课中'), findsOneWidget);
    expect(find.text('上课中'), findsWidgets);
    expect(find.text('下课提醒'), findsOneWidget);
  });

  testWidgets('展开态预览：空列表 = 全部隐藏，只显示提示', (tester) async {
    await pumpExpandedPreview(
      tester,
      displayConfig: display(expandedDetailFields: const []),
    );

    expect(find.text('已隐藏全部详情行，展开后只显示标题与摘要'), findsOneWidget);
    expect(find.textContaining('时间：'), findsNothing);
    expect(find.textContaining('地点：'), findsNothing);
  });

  testWidgets('展开态预览：课中带进度块时出进度行并隐藏状态行', (tester) async {
    await pumpExpandedPreview(
      tester,
      displayConfig: display(),
      forDuringEnd: true,
    );

    // 两个阶段（课中 / 下课提醒）各一张卡片
    expect(find.text('上课中'), findsOneWidget);
    expect(find.text('下课提醒'), findsOneWidget);
    // 课中卡片有进度块
    expect(find.textContaining('下一节点：'), findsOneWidget);
    expect(find.textContaining('整节下课：'), findsOneWidget);
    // 课中标题不带前缀，下课提醒标题带前缀
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('下课提醒：高等数学'), findsOneWidget);
  });

  testWidgets('展开态预览：跟随课前设置时展示说明徽标', (tester) async {
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
          body: SingleChildScrollView(
            child: LiveIslandExpandedPreviewCard(
              display: display(),
              forDuringEnd: true,
              followBeforeClass: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('跟随课前提醒设置，修改课前提醒即生效'), findsOneWidget);
  });
}
