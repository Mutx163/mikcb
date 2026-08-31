// 测试目标：复现真机 "A RenderFlex overflowed by 0.500 pixels on the bottom" 告警。
//
// 真机环境出现该告警，发生在日视图 agenda 列表卡片内。卡片结构（见
// lib/screens/timetable_screen.dart 的 _buildDefaultDayAgendaCard /
// _buildCurrentDayAgendaCard）核心是一段 Padding(14,12,10/14,12) 包裹
// 的 Column，Column 子项由 SizedBox(8) / SizedBox(10) / SizedBox(6) 固定
// 间距串联。真机上 Material clip 后 Column 被一个有界高度约束，固定间距
// 与字体度量之和比可用高度多出 0.5px，触发底部 0.5px 溢出。
//
// 测试环境字体度量与真机不同，之前用 31 种视口高度 × 4 种材质样式都无法
// 复现。本测试改用「先测量 Column 自然高度，再用 (自然高度 - 0.5) 的 tight
// 约束」直接复刻 Material clip 后的 bounded 高度场景，确认 0.5px 溢出可被
// 触发，并验证两种修复方案的有效性。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

/// 与 _buildCurrentDayAgendaCard / _buildDefaultDayAgendaCard 内部 Column
/// 一致的内容结构。[context] 用于读取 Theme（与真机一致）。
///
/// [variant] 控制文字内容与样式：
///  - 0：标题单行 + 教师 + 地点（最常见，无备注行）。
///  - 1：长标题两行换行 + 教师 + 地点 + 备注（全显示，触发额外 info row）。
///  - 2：标题 + 教师 + 地点 + 备注，但使用更重字重与更大行高。
///
/// [fix] 控制修复方案：
///  - 0：原始结构（最后一个 SizedBox(6) 不变）。
///  - 1：把最后一个 SizedBox(6) 改为 SizedBox(5.5)（间距补偿 0.5px）。
///  - 2：把最后一个 info row 包进 Flexible（允许它在压力下收缩）。
Widget buildAgendaColumn(
  BuildContext context, {
  required int variant,
  int fix = 0,
  required Color ink,
}) {
  final theme = Theme.of(context);
  final textTheme = theme.textTheme;

  Widget infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: ink.withValues(alpha: 0.82)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: ink.withValues(alpha: 0.92),
              fontWeight: FontWeight.w400,
              fontSize: 11.5,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }

  final String title;
  final String teacherLine;
  final String locationLine;
  final String? noteLine;
  final FontWeight titleWeight;
  final double titleHeight;

  switch (variant) {
    case 0:
      title = '高等数学（线性代数部分）';
      teacherLine = '授课教师：张老师 · 第1-2节';
      locationLine = '上课地点：A101';
      noteLine = null;
      titleWeight = FontWeight.w400;
      titleHeight = 1.10;
    case 1:
      title = '高等数学下册——多元函数微分学及其在工程与经济中的应用专题讲座与习题精讲';
      teacherLine = '授课教师：李教授 · 第3-4节';
      locationLine = '上课地点：教学楼B区302阶梯教室';
      noteLine = '本周需带教材第7章与配套习题册，课前完成预习作业';
      titleWeight = FontWeight.w400;
      titleHeight = 1.10;
    case 2:
      title = '离散数学';
      teacherLine = '授课教师：王老师 · 第5-6节';
      locationLine = '上课地点：C201';
      noteLine = '期中测验范围：第1-4章';
      titleWeight = FontWeight.w600;
      titleHeight = 1.25;
    default:
      throw ArgumentError('unknown variant $variant');
  }

  final children = <Widget>[];

  children.add(
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: ink),
                    const SizedBox(width: 5),
                    Text(
                      '08:00 - 09:35',
                      style: textTheme.labelSmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  children.add(const SizedBox(height: 8));

  children.add(
    Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textTheme.titleMedium?.copyWith(
        color: ink,
        fontWeight: titleWeight,
        height: titleHeight,
      ),
    ),
  );

  children.add(const SizedBox(height: 10));
  children.add(infoRow(Icons.person_outline_rounded, teacherLine));
  // teacherRow -> locationRow 之间的间距恒为 6。
  children.add(const SizedBox(height: 6));
  final locationRow = infoRow(Icons.location_on_outlined, locationLine);

  // 最后一个固定间距受 fix=1 控制（6 -> 5.5，整体少占 0.5px，抵消溢出）；
  // 最后一个子项受 fix=2 控制（包 Flexible，压力下收缩，避免整体超出）。
  final double lastGap = fix == 1 ? 5.5 : 6;
  final Widget lastChild;
  if (noteLine != null) {
    children.add(locationRow);
    final Widget noteRow = infoRow(Icons.sticky_note_2_outlined, noteLine);
    lastChild = noteRow;
  } else {
    lastChild = locationRow;
  }
  // 把「最后一个间距 + 最后一个子项」一起加入；fix=1 改间距，fix=2 包 Flexible。
  children.add(SizedBox(height: lastGap));
  children.add(fix == 2 ? Flexible(child: lastChild) : lastChild);

  return Column(
    key: _columnKey,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: children,
  );
}

Widget _testApp(Widget home) {
  return Localizations(
    locale: const Locale('zh'),
    delegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // 关键：不使用 Navigator，避免 offstage overlay 在 pump 时被布局导致
        // hasSize 断言失败。这里只渲染 home 本身。
        home: home,
      ),
    ),
  );
}

const _columnKey = ValueKey('__agenda_column__');

/// 用 Builder 提供 BuildContext（读取 Theme），其内部就是带 [_columnKey] 的
/// Column。测量时用 SingleChildScrollView + UnconstrainedBox 让 Column 以
/// min 高度布局；用 pump() 而非 pumpAndSettle()，避免 MaterialApp Navigator
/// 的 offstage overlay 在 settle 时被布局导致 hasSize 断言失败。
Future<double> measureNaturalHeight(
  WidgetTester tester,
  Widget Function(BuildContext) buildColumn,
) async {
  await tester.pumpWidget(
    _testApp(
      Center(
        child: SizedBox(
          width: 320,
          child: OverflowBox(
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Builder(builder: buildColumn),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final size = tester.getSize(find.byKey(_columnKey));
  return size.height;
}

Future<List<String>> pumpWithTightHeight(
  WidgetTester tester, {
  required Widget Function(BuildContext) buildColumn,
  required double height,
  required List<FlutterErrorDetails> errors,
}) async {
  final messages = <String>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    errors.add(details);
    messages.add(details.toString());
    // 故意不转发给 previousOnError：RenderFlex overflow 在 debug 模式下被
    // 默认 onError 当作未捕获异常上报，会让本测试因 Multiple exceptions
    // 失败。我们只想捕获错误文本做断言，不让它污染测试结果。
  };
  try {
    await tester.pumpWidget(
      _testApp(
        Center(
          child: SizedBox(
            width: 320,
            height: height,
            child: Builder(builder: buildColumn),
          ),
        ),
      ),
    );
    await tester.pump();
  } finally {
    FlutterError.onError = previousOnError;
  }
  return messages;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ink = Color(0xFF1A1A1A);

  group('RenderFlex 0.5px overflow reproduction', () {
    testWidgets(
        'tight (natural - 0.5) triggers bottom overflow on all variants',
        (tester) async {
      for (var variant = 0; variant < 3; variant++) {
        final errors = <FlutterErrorDetails>[];
        final natural = await measureNaturalHeight(
          tester,
          (ctx) => buildAgendaColumn(ctx, variant: variant, ink: ink),
        );

        final messages = await pumpWithTightHeight(
          tester,
          buildColumn: (ctx) =>
              buildAgendaColumn(ctx, variant: variant, ink: ink),
          height: natural - 0.5,
          errors: errors,
        );

        final overflowHit = messages.any(
          (m) => m.contains('A RenderFlex overflowed by 0.500 pixels on the bottom'),
        );
        expect(
          overflowHit,
          isTrue,
          reason:
              'variant=$variant: tight height ${natural - 0.5} (natural=$natural) '
              '应触发 "A RenderFlex overflowed by 0.500 pixels on the bottom"。'
              ' 收到的错误：$messages',
        );
        debugPrint(
          'variant=$variant natural=$natural -> tight ${natural - 0.5}: overflow reproduced',
        );
      }
    });
  });

  group('fix: last spacing 6 -> 5.5', () {
    testWidgets('compensated spacing removes the overflow', (tester) async {
      for (var variant = 0; variant < 3; variant++) {
        final errors = <FlutterErrorDetails>[];
        // 真机可用高度 = 原始自然高度 - 0.5（Material clip 后的有界高度）。
        final originalNatural = await measureNaturalHeight(
          tester,
          (ctx) => buildAgendaColumn(ctx, variant: variant, ink: ink),
        );
        final available = originalNatural - 0.5;
        // fix=1 把最后一个固定间距 6 -> 5.5，自然高度恰好降到 available。
        final fixedNatural = await measureNaturalHeight(
          tester,
          (ctx) => buildAgendaColumn(ctx, variant: variant, fix: 1, ink: ink),
        );

        final messages = await pumpWithTightHeight(
          tester,
          buildColumn: (ctx) =>
              buildAgendaColumn(ctx, variant: variant, fix: 1, ink: ink),
          height: available,
          errors: errors,
        );

        final overflowHit = messages.any(
          (m) => m.contains('A RenderFlex overflowed'),
        );
        expect(
          fixedNatural,
          lessThanOrEqualTo(available),
          reason:
              'variant=$variant: 修复后自然高度 $fixedNatural 应 <= 可用高度 $available',
        );
        expect(
          overflowHit,
          isFalse,
          reason:
              'variant=$variant: 间距补偿 6->5.5 后，可用高度 $available '
              '（原始 natural=$originalNatural，修复 natural=$fixedNatural）不应再溢出。'
              '收到错误：$messages',
        );
        debugPrint(
          'variant=$variant originalNatural=$originalNatural available=$available fixedNatural=$fixedNatural: overflow fixed by spacing 5.5',
        );
      }
    });
  });

  group('fix: wrap last info row in Flexible', () {
    testWidgets('Flexible last child removes the overflow', (tester) async {
      for (var variant = 0; variant < 3; variant++) {
        final errors = <FlutterErrorDetails>[];
        // 真机可用高度 = 原始自然高度 - 0.5。
        final originalNatural = await measureNaturalHeight(
          tester,
          (ctx) => buildAgendaColumn(ctx, variant: variant, ink: ink),
        );
        final available = originalNatural - 0.5;
        // fix=2 用 Flexible 包最后一个子项；在有界约束下 Flexible 子项可被压缩，
        // Column 整体不会超出 available。
        final fixedNatural = await measureNaturalHeight(
          tester,
          (ctx) => buildAgendaColumn(ctx, variant: variant, fix: 2, ink: ink),
        );

        final messages = await pumpWithTightHeight(
          tester,
          buildColumn: (ctx) =>
              buildAgendaColumn(ctx, variant: variant, fix: 2, ink: ink),
          height: available,
          errors: errors,
        );

        final overflowHit = messages.any(
          (m) => m.contains('A RenderFlex overflowed'),
        );
        expect(
          overflowHit,
          isFalse,
          reason:
              'variant=$variant: 最后一个 info row 包 Flexible 后，可用高度 '
              '$available（原始 natural=$originalNatural，修复 natural=$fixedNatural）'
              '不应再溢出。收到错误：$messages',
        );
        debugPrint(
          'variant=$variant originalNatural=$originalNatural available=$available fixedNatural=$fixedNatural: overflow fixed by Flexible',
        );
      }
    });
  });
}
