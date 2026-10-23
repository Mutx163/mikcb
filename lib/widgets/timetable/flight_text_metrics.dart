library;

import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';

/// 日视图「卡片对卡片」转场：**两端文字锚点的纯几何**（2026-10-23）。
///
/// ## 这个文件解决什么
///
/// 用户三次反馈的是同一件事的三种说法：
///
/// > 「动画和卡片不是一对一缩放的」
/// > 「颜色和实际课程卡片差的非常远」
/// > 「卡片里面的字不是平移过去的，而是开始的、动画上的、最终的，是三个位置」
///
/// 前两条已修（飞行卡吃与议程卡同一份展示条目、同一个调色板）。第三条的病根是
/// **飞行卡的文字位置是手写的近似值**（`52` / `78.5` / `50`），而真实卡片的
/// 位置是一串嵌套排版算出来的。近似值差几像素，起飞与落定那两帧就各跳一次。
///
/// 这里把两端各自的真实排版**复算**一遍，产出每一行字的矩形与字号；飞行卡只做
/// `lerp`，不再持有任何手写近似值。
///
/// ## 正确性由真实卡片验收，不是自证
///
/// `test/domain/flight_text_metrics_test.dart` 会分别泵起
/// `CourseCard(isCompact: true)` 与 `TimetableCourseAgendaDefaultCard`，
/// 用 `tester.getRect(find.text(...))` 量真值，再与本文件逐行比对（容差 1.5dp）。
/// 改这里任何一条公式，那条测试都会红。
///
/// ## 坐标口径
///
/// 所有矩形都以**卡片表面（`CourseSurface`）左上角**为原点，单位逻辑像素。
/// 飞行卡的 `Positioned` 也落在卡片表面里，两端同一坐标原点，中间无需换算。
/// 一行文字（或一个图标）在某一端的锚点。
class FlightTextAnchor {
  const FlightTextAnchor({
    required this.id,
    required this.text,
    required this.rect,
    required this.fontSize,
    this.weight = FontWeight.w400,
    this.isIcon = false,
    this.icon,
    this.lineHeightFactor = 1.15,
    this.maxLines,
  });

  /// 稳定标识：`name` / `teacher` / `location` / `time` / `weeks` /
  /// `description` / `weather` / `icon-time` / `icon-teacher` / `icon-location`。
  final String id;

  /// 这一行画什么字（图标锚点为空串）。
  final String text;

  /// 相对卡片表面左上角的矩形。
  final Rect rect;

  /// 实际渲染字号（图标锚点里是图标尺寸）。
  final double fontSize;

  final FontWeight weight;

  /// 是不是图标。
  final bool isIcon;

  /// 图标字形（仅 [isIcon] 时有意义）。
  final IconData? icon;

  /// 渲染用的行高倍数。两端不同（网格卡课名 1.15、议程卡课名 1.10），
  /// 中间必须插值——否则字会随着「位置在动、行高在跳」抖一下。
  final double lineHeightFactor;

  /// 最多几行（null = 不限）。议程卡课名是 2、信息行是 1。
  final int? maxLines;

  @override
  String toString() =>
      'FlightTextAnchor($id, $rect, ${fontSize.toStringAsFixed(1)}sp)';
}

/// 一端的全部锚点 + 卡片尺寸。
class FlightCardAnchors {
  const FlightCardAnchors({
    required this.cardSize,
    required this.anchors,
  });

  final Size cardSize;
  final List<FlightTextAnchor> anchors;

  FlightTextAnchor? operator [](String id) {
    for (final a in anchors) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  bool get isEmpty => anchors.isEmpty;

  static const FlightCardAnchors empty = FlightCardAnchors(
    cardSize: Size.zero,
    anchors: <FlightTextAnchor>[],
  );

  @override
  String toString() => 'FlightCardAnchors($cardSize, $anchors)';
}

/// 紧凑卡里一行文字的输入（与 `course_card.dart` 的 `_CompactTextLine` 同形）。
class CompactLineSpec {
  const CompactLineSpec({
    required this.id,
    required this.text,
    required this.fontSize,
    required this.height,
    this.weight = FontWeight.w400,
    this.icon,
  });

  final String id;
  final String text;
  final double fontSize;

  /// 行高倍数：课名 1.15、其余 1.1（`_buildCompactTextLines` 的 `height:`）。
  final double height;
  final FontWeight weight;

  /// 行首图标（只有天气行带）。带了就锁死单行，与真实卡片一致。
  final IconData? icon;
}

/// 复算「周网格紧凑卡」里每一行的真实位置。
///
/// 复算的排版链（与 `course_card.dart` `_buildCompactCard` 逐层对应）：
///
/// ```
/// CourseSurface
///   └ Padding(horizontal: 4, vertical: compactVerticalPadding)
///       └ Expanded > ClipRect > LayoutBuilder
///           └ Align(垂直对齐) > FittedBox(scaleDown)
///               └ SizedBox(width: 内宽) > Column(子项间距 2)
/// ```
///
/// 两处最容易算错：
///
/// 1. **宽度被 `SizedBox` 钉死**，所以 `BoxFit.scaleDown` 只在「高度放不下」时
///    生效，系数 = `min(1, 内高 / 内容高)`；横向永远不会被缩。
/// 2. **高度是折行后的高度**，不是单行高。窄格里「教三-201」在 8sp / 内宽 44dp
///    时会折成两行（实测 18dp），按单行算会把整块文字整体上移半行。
CompactCardTextMetrics measureCompactCardText({
  required Size surfaceSize,
  required double verticalPadding,
  required List<CompactLineSpec> lines,
  /// 卡内文字最终会与 `DefaultTextStyle` 合并（`TextStyle.inherit` 默认 true），
  /// 所以量宽高时**必须**用同一份基底样式：字形宽度差一点点，窄格里的地点行
  /// 就会多折一行（实测 11sp / 内宽 44dp：不合并 = 3 行、合并 = 2 行，整块文字
  /// 因此上移 6dp）。调用方从真实卡片的 context 取 `DefaultTextStyle.of(context)`。
  TextStyle baseStyle = const TextStyle(),
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  bool alignTop = false,
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  const horizontalPadding = 4.0;
  const lineGap = 2.0;

  final innerWidth = (surfaceSize.width - horizontalPadding * 2).clamp(
    0.0,
    double.infinity,
  );
  final innerHeight = (surfaceSize.height - verticalPadding * 2).clamp(
    0.0,
    double.infinity,
  );

  final measured = <_MeasuredLine>[];
  for (final spec in lines) {
    measured.add(
      _MeasuredLine(
        spec: spec,
        box: _layoutText(
          text: spec.text,
          fontSize: spec.fontSize,
          height: spec.height,
          weight: spec.weight,
          maxWidth: innerWidth,
          maxLines: spec.icon == null ? null : 1,
          textDirection: textDirection,
          textScaler: textScaler,
          baseStyle: baseStyle,
        ),
      ),
    );
  }

  var contentHeight = 0.0;
  for (var i = 0; i < measured.length; i++) {
    contentHeight += measured[i].box.height;
    if (i > 0) {
      contentHeight += lineGap;
    }
  }

  final scale = contentHeight > 0
      ? (innerHeight / contentHeight).clamp(0.0, 1.0)
      : 1.0;
  final blockHeight = contentHeight * scale;
  // `Align` 在 `FittedBox` 外层：放不下时贴顶，放得下时按用户设置居中/贴顶。
  final blockTop = alignTop ? 0.0 : (innerHeight - blockHeight) / 2;

  final anchors = <FlightTextAnchor>[];
  var offset = 0.0;
  for (final line in measured) {
    final lineWidth = line.box.width * scale;
    final left = switch (crossAxisAlignment) {
      CrossAxisAlignment.center => (innerWidth - lineWidth) / 2,
      CrossAxisAlignment.end => innerWidth - lineWidth,
      _ => 0.0,
    };
    anchors.add(
      FlightTextAnchor(
        id: line.spec.id,
        text: line.spec.text,
        rect: Rect.fromLTWH(
          horizontalPadding + left,
          verticalPadding + blockTop + offset * scale,
          lineWidth,
          line.box.height * scale,
        ),
        fontSize: line.spec.fontSize * scale,
        weight: line.spec.weight,
        isIcon: line.spec.icon != null,
        icon: line.spec.icon,
        lineHeightFactor: line.spec.height,
        maxLines: line.spec.icon == null ? null : 1,
      ),
    );
    offset += line.box.height + lineGap;
  }

  return CompactCardTextMetrics(
    scale: scale,
    anchors: FlightCardAnchors(
      cardSize: surfaceSize,
      anchors: List.unmodifiable(anchors),
    ),
  );
}

/// 紧凑卡的测量结果：缩放系数 + 锚点。
///
/// [scale] 单独暴露是因为它本身也是一个观感量：网格卡在窄格里会把字整体缩小，
/// 飞行卡起点必须**用同一份缩放后的字号**，否则第一帧字就比真卡大一圈。
class CompactCardTextMetrics {
  const CompactCardTextMetrics({required this.scale, required this.anchors});

  final double scale;
  final FlightCardAnchors anchors;

  FlightTextAnchor? operator [](String id) => anchors[id];
}

/// 议程卡里「时间胶囊」那一行的高度（实测 30）。
///
/// 由三件事共同决定：胶囊 26（`vertical: 5` + 16 行高的时间文字）、右侧
/// 「记作业 / 备注」按钮 30（`vertical: 6` + 12sp 文字的 16 行高 + 1px 描边 ×2）。
/// 取最大者 = 30。**不能取 26**：那会让课名整体上移 4dp，起飞/落地各跳一次
/// （实测旧值 28 的偏差正是这样来的）。
const double kAgendaHeaderRowHeight = 30;

/// 时间胶囊高度（`vertical: 5` × 2 + 16 行盒）。
const double kAgendaTimeChipHeight = 26;

/// 胶囊内时间文字的字号（`labelSmall`）。
const double kAgendaTimeTextSize = 12;

/// 胶囊内时间文字的行盒高度（12sp，行高 1 → 12；实测 16 是 labelSmall 的默认行高）。
const double kAgendaTimeTextHeight = 16;

/// 复算「日视图议程卡」里每一行的真实位置。
///
/// 议程卡结构固定（`day_view_course_agenda_card_variants.dart`）：
///
/// ```
/// Padding(fromLTRB(14, 12, 10, 12))
///   ├ Row(时间胶囊 + 状态徽标 + 记作业/备注)   ← 顶边 12，高 30
///   ├ SizedBox(height: 8)
///   ├ Text(课名, maxLines: 2, height: 1.10 → 实测 18)
///   ├ SizedBox(height: 10)
///   ├ DayAgendaInfoRow(教师)                    ← 高 14
///   ├ SizedBox(height: 5.5)
///   ├ DayAgendaInfoRow(地点)                    ← 高 14
///   └ (天气 / 本节备注，同 5.5 间距)
/// ```
///
/// 实测校验（364dp 宽、课名一行）：课名 **50.0**、教师 **78.5**、地点 **98.0**；
/// 12 + 30 + 8 = 50、50 + 18 + 10 = 78、78 + 14 + 5.5 = 97.5 —— 逐项吻合。
FlightCardAnchors measureAgendaCardText({
  required Size surfaceSize,
  required String name,
  required String? teacherLine,
  required String? locationLine,
  required double titleFontSize,
  double titleHeight = 1.10,
  double infoFontSize = 11.5,
  double infoHeight = 1.15,
  double infoIconSize = 14,
  double padLeft = 14,
  double padRight = 10,
  double padTop = 12,
  double headerRowHeight = kAgendaHeaderRowHeight,
  double timeChipHeight = kAgendaTimeChipHeight,
  double gapAfterHeader = 8,
  double gapAfterTitle = 10,
  double gapBetweenInfoRows = 5.5,
  String? timeText,
  /// 课名最终合并到的基底样式（`Theme.of(context).textTheme.titleMedium` 之上
  /// 还有 `DefaultTextStyle`）。量宽高时必须同源，理由同 `measureCompactCardText`。
  TextStyle baseStyle = const TextStyle(),
  /// 信息行（教师/地点）的基底样式：`theme.textTheme.bodySmall`。
  TextStyle infoBaseStyle = const TextStyle(),
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final innerWidth = (surfaceSize.width - padLeft - padRight).clamp(
    0.0,
    double.infinity,
  );

  final anchors = <FlightTextAnchor>[];
  var top = padTop;

  // ── 时间胶囊（顶端对齐在 header 行内，与真实 Row 的 crossAxisAlignment:
  //    start 一致；胶囊内部文字垂直居中）─────────────────────────────────
  if (timeText != null) {
    final timeBox = _layoutText(
      text: timeText,
      fontSize: kAgendaTimeTextSize,
      height: 1,
      maxWidth: innerWidth,
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
      baseStyle: infoBaseStyle,
    );
    anchors.add(
      FlightTextAnchor(
        id: 'icon-time',
        text: '',
        rect: Rect.fromLTWH(
          padLeft + 8,
          top + (timeChipHeight - 13) / 2,
          13,
          13,
        ),
        fontSize: 13,
        isIcon: true,
        icon: Icons.schedule_rounded,
      ),
    );
    anchors.add(
      FlightTextAnchor(
        id: 'time',
        text: timeText,
        rect: Rect.fromLTWH(
          padLeft + 8 + 13 + 5,
          top + (timeChipHeight - kAgendaTimeTextHeight) / 2,
          timeBox.width,
          kAgendaTimeTextHeight,
        ),
        fontSize: kAgendaTimeTextSize,
          maxLines: 1,
      ),
    );
  }
  top += headerRowHeight + gapAfterHeader;

  // ── 课名（最多两行）──────────────────────────────────────────────────
  final titleBox = _layoutText(
    text: name,
    fontSize: titleFontSize,
    height: titleHeight,
    maxWidth: innerWidth,
    maxLines: 2,
    textDirection: textDirection,
    textScaler: textScaler,
    baseStyle: baseStyle,
  );
  anchors.add(
    FlightTextAnchor(
      id: 'name',
      text: name,
      rect: Rect.fromLTWH(padLeft, top, innerWidth, titleBox.height),
      fontSize: titleFontSize,
      lineHeightFactor: titleHeight,
      maxLines: 2,
    ),
  );
  top += titleBox.height + gapAfterTitle;

  // ── 教师行 ────────────────────────────────────────────────────────────
  if (teacherLine != null && teacherLine.isNotEmpty) {
    final rowHeight = _infoRowHeight(
      text: teacherLine,
      fontSize: infoFontSize,
      height: infoHeight,
      iconSize: infoIconSize,
      maxWidth: innerWidth - infoIconSize - 6,
      textDirection: textDirection,
      textScaler: textScaler,
      baseStyle: infoBaseStyle,
    );
    anchors.add(
      FlightTextAnchor(
        id: 'icon-teacher',
        text: '',
        rect: Rect.fromLTWH(padLeft, top, infoIconSize, rowHeight),
        fontSize: infoIconSize,
        isIcon: true,
        icon: Icons.person_outline_rounded,
      ),
    );
    anchors.add(
      FlightTextAnchor(
        id: 'teacher',
        text: teacherLine,
        rect: Rect.fromLTWH(
          padLeft + infoIconSize + 6,
          top + (rowHeight - infoFontSize * infoHeight) / 2,
          innerWidth - infoIconSize - 6,
          infoFontSize * infoHeight,
        ),
        fontSize: infoFontSize,
        lineHeightFactor: infoHeight,
        maxLines: 1,
      ),
    );
    top += rowHeight + gapBetweenInfoRows;
  }

  // ── 地点行 ────────────────────────────────────────────────────────────
  if (locationLine != null && locationLine.isNotEmpty) {
    final rowHeight = _infoRowHeight(
      text: locationLine,
      fontSize: infoFontSize,
      height: infoHeight,
      iconSize: infoIconSize,
      maxWidth: innerWidth - infoIconSize - 6,
      textDirection: textDirection,
      textScaler: textScaler,
      baseStyle: infoBaseStyle,
    );
    anchors.add(
      FlightTextAnchor(
        id: 'icon-location',
        text: '',
        rect: Rect.fromLTWH(padLeft, top, infoIconSize, rowHeight),
        fontSize: infoIconSize,
        isIcon: true,
        icon: Icons.location_on_outlined,
      ),
    );
    anchors.add(
      FlightTextAnchor(
        id: 'location',
        text: locationLine,
        rect: Rect.fromLTWH(
          padLeft + infoIconSize + 6,
          top + (rowHeight - infoFontSize * infoHeight) / 2,
          innerWidth - infoIconSize - 6,
          infoFontSize * infoHeight,
        ),
        fontSize: infoFontSize,
        lineHeightFactor: infoHeight,
        maxLines: 1,
      ),
    );
  }

  return FlightCardAnchors(
    cardSize: surfaceSize,
    anchors: List.unmodifiable(anchors),
  );
}

/// 飞行卡上的一项：位置、字号、字重、透明度与它画什么。
class FlightLayoutItem {
  const FlightLayoutItem({
    required this.id,
    required this.text,
    required this.rect,
    required this.fontSize,
    required this.weight,
    required this.opacity,
    required this.isIcon,
    this.icon,
    this.lineHeightFactor = 1.15,
    this.maxLines,
  });

  final String id;
  final String text;
  final Rect rect;
  final double fontSize;
  final FontWeight weight;

  /// 0..1。**只作用在文字/图标上**，绝不套在玻璃面上（`CourseSurface` 铁律）。
  final double opacity;

  final bool isIcon;
  final IconData? icon;

  /// 渲染用的行高倍数（两端插值）。
  final double lineHeightFactor;

  /// 最多几行（终点值优先；null = 不限）。
  final int? maxLines;
}

/// 两端锚点插值后的一组布局项（飞行卡按这个渲染）。
class FlightLayout {
  const FlightLayout({required this.items, required this.surfaceSize});

  final List<FlightLayoutItem> items;

  /// 当前帧的卡片表面尺寸（两端矩形插值）。
  final Size surfaceSize;

  Map<String, Rect> get rects => {
    for (final item in items) item.id: item.rect,
  };
}

/// 把两端锚点插值成当前帧的布局。
///
/// 三条规则，每条都对应一个具体的观感问题：
///
/// 1. **两端都有**的行：位置 / 字号 / 字重全部线性插值 → 全程连续，落地不跳。
/// 2. **只有起点有**的行（周数 / 备注 / 天气）：留在起点，`t > 0.45` 后淡出。
///    直接消失会读成「卡片抖了一下」。
/// 3. **只有终点有**的行（时间胶囊及其图标）：留在终点，`t > 0.55` 后淡入。
///    提前出现会挤在还没长大的卡里。
FlightLayout lerpFlightLayout({
  required FlightCardAnchors from,
  required FlightCardAnchors to,
  required Size surfaceSize,
  required double t,
}) {
  final k = t.clamp(0.0, 1.0);
  final items = <FlightLayoutItem>[];
  final seen = <String>{};

  for (final a in from.anchors) {
    seen.add(a.id);
    final b = to[a.id];
    if (b != null) {
      items.add(
        FlightLayoutItem(
          id: a.id,
          text: b.text.isNotEmpty ? b.text : a.text,
          rect: _lerpRect(a.rect, b.rect, k),
          fontSize: _lerp(a.fontSize, b.fontSize, k),
          weight: FontWeight.lerp(a.weight, b.weight, k) ?? a.weight,
          opacity: 1,
          isIcon: a.isIcon || b.isIcon,
          icon: b.icon ?? a.icon,
          lineHeightFactor: _lerp(a.lineHeightFactor, b.lineHeightFactor, k),
          // 行数取两端更宽松的那个：中途收紧会让字突然被截断（读作抖动）。
          maxLines: b.maxLines ?? a.maxLines,
        ),
      );
      continue;
    }
    items.add(
      FlightLayoutItem(
        id: a.id,
        text: a.text,
        rect: a.rect,
        fontSize: a.fontSize,
        weight: a.weight,
        opacity: (1 - (k - 0.45) / 0.35).clamp(0.0, 1.0),
        isIcon: a.isIcon,
        icon: a.icon,
        lineHeightFactor: a.lineHeightFactor,
        maxLines: a.maxLines,
      ),
    );
  }

  for (final b in to.anchors) {
    if (seen.contains(b.id)) {
      continue;
    }
    items.add(
      FlightLayoutItem(
        id: b.id,
        text: b.text,
        rect: b.rect,
        fontSize: b.fontSize,
        weight: b.weight,
        opacity: ((k - 0.55) / 0.35).clamp(0.0, 1.0),
        isIcon: b.isIcon,
        icon: b.icon,
        lineHeightFactor: b.lineHeightFactor,
        maxLines: b.maxLines,
      ),
    );
  }

  // 固定绘制顺序：两端列表顺序可能不同，按 id 排序才不会出现遮挡关系跳变。
  const order = <String>[
    'icon-time',
    'time',
    'name',
    'icon-teacher',
    'teacher',
    'icon-location',
    'location',
    'weather',
    'weeks',
    'description',
  ];
  items.sort((x, y) {
    final ix = order.indexOf(x.id);
    final iy = order.indexOf(y.id);
    return (ix < 0 ? order.length : ix).compareTo(iy < 0 ? order.length : iy);
  });

  return FlightLayout(items: List.unmodifiable(items), surfaceSize: surfaceSize);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

Rect _lerpRect(Rect a, Rect b, double t) => Rect.fromLTWH(
  _lerp(a.left, b.left, t),
  _lerp(a.top, b.top, t),
  _lerp(a.width, b.width, t),
  _lerp(a.height, b.height, t),
);

class _MeasuredLine {
  const _MeasuredLine({required this.spec, required this.box});

  final CompactLineSpec spec;
  final Size box;
}

Size _layoutText({
  required String text,
  required double fontSize,
  required double height,
  FontWeight weight = FontWeight.w400,
  required double maxWidth,
  int? maxLines,
  required TextDirection textDirection,
  required TextScaler textScaler,
  TextStyle baseStyle = const TextStyle(),
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: baseStyle.merge(
        TextStyle(fontSize: fontSize, height: height, fontWeight: weight),
      ),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: maxLines,
    // 真实卡片对锁单行的文字用 `TextOverflow.ellipsis`；这里同口径，
    // 否则量出来的行宽会多出一个「…」。
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth);
  final size = Size(painter.width, painter.height);
  painter.dispose();
  return size;
}

double _infoRowHeight({
  required String text,
  required double fontSize,
  required double height,
  required double iconSize,
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
  TextStyle baseStyle = const TextStyle(),
}) {
  final box = _layoutText(
    text: text,
    fontSize: fontSize,
    height: height,
    maxWidth: maxWidth,
    maxLines: 1,
    textDirection: textDirection,
    textScaler: textScaler,
    baseStyle: baseStyle,
  );
  return box.height < iconSize ? iconSize : box.height;
}

/// 一次「卡片对卡片」转场的**两端文字方案**（起点 = 周网格卡，终点 = 日议程卡）。
///
/// 由 [buildFlightCardPlan] 按「这门课在两端的真实排版」一次算好，转场期间每帧
/// 只做插值（[lerpFlightLayout]）。**不要在转场里每帧重算**：`TextPainter.layout`
/// 一帧几十次会直接吃掉预算（本仓已有 3~9ms/帧的实测口径）。
class FlightCardPlan {
  const FlightCardPlan({
    required this.start,
    required this.end,
  });

  /// 起点：周网格紧凑卡里的每行字。
  final FlightCardAnchors start;

  /// 终点：日视图议程卡里的每行字。
  final FlightCardAnchors end;

  bool get isEmpty => start.isEmpty && end.isEmpty;
}

/// 组装两端文字方案。
///
/// 判定口径**逐个照抄真实卡片**，任何一处判据不同，那一行就会在落地时消失或
/// 凭空出现：
///
/// | 行 | 周网格卡判据（`_buildCompactTextLines`） | 日用卡判据 |
/// |---|---|---|
/// | 冲突标签 | `compactOverlineText` 非空 | — |
/// | 课名 | `showName` | 恒有 |
/// | 教师 | `showTeacher && teacher 非空` | 恒有（占位「未知教师」） |
/// | 地点 | `showLocation && location 非空` | 恒有（占位「未知地点」） |
/// | 时间 | `showTime`（两行：开始 / 结束） | 时间胶囊（一行 `a - b`） |
/// | 周数 / 简介 | `showWeeks` / `showDescription` | — |
/// | 天气 | 有数据才有 | 有数据才有 |
///
/// [gridSurfaceSize] / [agendaSurfaceSize] 都是**卡片表面**尺寸（不含外边距）。
FlightCardPlan buildFlightCardPlan({
  required String name,
  required String teacher,
  required String location,
  required TimetableSettings settings,
  required Size gridSurfaceSize,
  required Size agendaSurfaceSize,
  required String startTime,
  required String endTime,
  required String teacherLine,
  required String locationLine,
  /// 冲突等角标文案（网格卡顶上那一行）；null = 没有。
  String? overlineText,
  /// 周数文案；仅 `settings.courseCardShowWeeks` 时有效。
  String? weeksText,
  /// 课程简介；仅 `settings.courseCardShowDescription` 时有效。
  String? descriptionText,
  /// 天气文案（网格卡片上带图标的那一行）。
  String? weatherText,
  IconData? weatherIcon,
  /// 网格卡的垂直内边距（`sectionHeight < 64 ? 4 : 6`）。
  required double gridVerticalPadding,
  TitleWeightResolver titleWeight = _defaultTitleWeight,
  TitleWeightResolver detailWeight = _defaultDetailWeight,
  /// 网格卡课名的实际字号（= `settings.courseCardFontSize`）。
  double? gridTitleFontSize,
  /// 议程卡课名实际字号（= `theme.textTheme.titleMedium.fontSize`）。
  required double agendaTitleFontSize,
  /// 文字最终合并到的基底样式（必须来自**真实卡片的 context**）。
  TextStyle gridBaseStyle = const TextStyle(),
  TextStyle agendaBaseStyle = const TextStyle(),
  TextStyle agendaInfoBaseStyle = const TextStyle(),
  bool gridAlignTop = false,
  CrossAxisAlignment gridCrossAxisAlignment = CrossAxisAlignment.center,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final titleSize = gridTitleFontSize ?? settings.courseCardFontSize;
  final subtitleSize = (titleSize - 1).clamp(7.0, 14.0);

  final compactLines = <CompactLineSpec>[];
  if (overlineText != null && overlineText.trim().isNotEmpty) {
    compactLines.add(
      CompactLineSpec(
        id: 'overline',
        text: overlineText.trim(),
        fontSize: (subtitleSize - 1).clamp(6.0, 12.0),
        height: 1.05,
        weight: detailWeight(subtitleSize),
      ),
    );
  }
  if (settings.courseCardShowName) {
    compactLines.add(
      CompactLineSpec(
        id: 'name',
        text: name,
        fontSize: titleSize,
        height: 1.15,
        weight: titleWeight(titleSize),
      ),
    );
  }
  if (settings.courseCardShowTeacher && teacher.trim().isNotEmpty) {
    compactLines.add(
      CompactLineSpec(
        id: 'teacher',
        text: teacher.trim(),
        fontSize: subtitleSize,
        height: 1.1,
        weight: detailWeight(subtitleSize),
      ),
    );
  }
  if (settings.courseCardShowLocation && location.trim().isNotEmpty) {
    compactLines.add(
      CompactLineSpec(
        id: 'location',
        text: location.trim(),
        fontSize: subtitleSize,
        height: 1.1,
        weight: detailWeight(subtitleSize),
      ),
    );
  }
  if (settings.courseCardShowTime) {
    compactLines
      ..add(
        CompactLineSpec(
          id: 'time',
          text: startTime,
          fontSize: subtitleSize,
          height: 1.1,
          weight: detailWeight(subtitleSize),
        ),
      )
      ..add(
        CompactLineSpec(
          id: 'time-end',
          text: endTime,
          fontSize: subtitleSize,
          height: 1.1,
          weight: detailWeight(subtitleSize),
        ),
      );
  }
  if (settings.courseCardShowWeeks &&
      weeksText != null &&
      weeksText.trim().isNotEmpty) {
    compactLines.add(
      CompactLineSpec(
        id: 'weeks',
        text: weeksText.trim(),
        fontSize: subtitleSize,
        height: 1.1,
        weight: detailWeight(subtitleSize),
      ),
    );
  }
  if (settings.courseCardShowDescription &&
      descriptionText != null &&
      descriptionText.trim().isNotEmpty) {
    compactLines.add(
      CompactLineSpec(
        id: 'description',
        text: descriptionText.trim(),
        fontSize: subtitleSize,
        height: 1.1,
        weight: detailWeight(subtitleSize),
      ),
    );
  }
  if (weatherText != null && weatherText.isNotEmpty) {
    compactLines.add(
      CompactLineSpec(
        id: 'weather',
        text: weatherText,
        fontSize: subtitleSize,
        height: 1.1,
        weight: detailWeight(subtitleSize),
        icon: weatherIcon ?? Icons.wb_sunny_outlined,
      ),
    );
  }
  if (compactLines.isEmpty) {
    // 与真实卡片的兜底一致：一个字段都没开时也要有课名。
    compactLines.add(
      CompactLineSpec(
        id: 'name',
        text: name,
        fontSize: titleSize,
        height: 1.15,
        weight: titleWeight(titleSize),
      ),
    );
  }

  final start = measureCompactCardText(
    surfaceSize: gridSurfaceSize,
    verticalPadding: gridVerticalPadding,
    lines: compactLines,
    baseStyle: gridBaseStyle,
    alignTop: gridAlignTop,
    crossAxisAlignment: gridCrossAxisAlignment,
    textScaler: textScaler,
  ).anchors;

  final end = measureAgendaCardText(
    surfaceSize: agendaSurfaceSize,
    name: name,
    teacherLine: teacherLine,
    locationLine: locationLine,
    titleFontSize: agendaTitleFontSize,
    timeText: '$startTime - $endTime',
    baseStyle: agendaBaseStyle,
    infoBaseStyle: agendaInfoBaseStyle,
    textScaler: textScaler,
  );

  return FlightCardPlan(start: start, end: end);
}

/// 把「设计字重」解析成运行时字重（`AppFontScope` 会整体平移字重）。
typedef TitleWeightResolver = FontWeight Function(double fontSize);

FontWeight _defaultTitleWeight(double _) => FontWeight.w700;
FontWeight _defaultDetailWeight(double _) => FontWeight.w400;
