import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'hyperos_blurred_header.dart';

class HyperosScrollRevealedTitle extends StatelessWidget {
  const HyperosScrollRevealedTitle({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible = HyperosBlurredHeaderScope.contentUnderHeaderOf(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.4),
        duration: Duration(milliseconds: visible ? 300 : 150),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: Duration(milliseconds: visible ? 300 : 150),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}

/// Root-header clone of Forui's `FHeader` (root variant): the title is
/// left-aligned, wrapped in [Expanded] and stays interactive — unlike
/// [HyperosOverlayNestedHeader] whose centered title sits under an
/// [IgnorePointer]. Used by root pages such as the timetable home, where the
/// title itself is a tap target (profile quick-switch).
class HyperosRootHeader extends StatelessWidget {
  const HyperosRootHeader({
    super.key,
    required this.title,
    this.suffixes = const [],
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 2),
    this.minHeight = 44,
  });

  final Widget title;
  final List<Widget> suffixes;

  /// Content padding inside the bar (below the status-bar SafeArea).
  final EdgeInsetsGeometry padding;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    final font = DefaultTextStyle.of(context).style;
    return SafeArea(
      bottom: false,
      child: Semantics(
        header: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                      color: colors.onBackground,
                      fontFamily: font.fontFamily,
                      fontFamilyFallback: font.fontFamilyFallback,
                    ),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    child: title,
                  ),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: suffixes),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 二级页顶栏（frosted nested header）。
///
/// 标题按整条栏居中，但**宽度与位置都被左右两组图标夹住**：夹在
/// `[前缀宽度 + 留白, 栏宽 − 后缀宽度 − 留白]` 这段空档里，放不下就走省略号。
/// 以前标题完全不知道两边图标占多宽，学校名一长就直接压到图标上——图标先画、
/// 标题后画盖住，看着像「字里长出黑块」（2026-09-28 真机反馈：教务导入网页页
/// 的「重庆城市科技学院强智通适配」237dp，把右边 3 个图标整个盖掉）。
///
/// 两侧等宽（绝大多数页：1 个返回键 + 0/1 个动作）时空档居中 == 整条栏居中，
/// 与旧渲染逐像素一致；两侧不等宽时标题让位到空档里，不压图标。
class HyperosOverlayNestedHeader extends StatefulWidget {
  const HyperosOverlayNestedHeader({
    super.key,
    required this.title,
    this.prefixes = const [],
    this.suffixes = const [],
  });
  final Widget title;
  final List<Widget> prefixes;
  final List<Widget> suffixes;

  @override
  State<HyperosOverlayNestedHeader> createState() =>
      _HyperosOverlayNestedHeaderState();
}

/// 图标槽的名义宽度：返回键 44、动作键 40，首帧没量到时统一按 44 留位。
/// 宁可多留几个像素（标题早一帧就省略号），也不要出现压住图标的那一帧。
const double _kNominalHeaderSlotWidth = 44;

/// 标题离左右图标组的最小间距。
const double _kHeaderTitleInset = 10;

class _HyperosOverlayNestedHeaderState
    extends State<HyperosOverlayNestedHeader> {
  final GlobalKey _prefixesKey = GlobalKey();
  final GlobalKey _suffixesKey = GlobalKey();

  Size _prefixesSize = Size.zero;
  Size _suffixesSize = Size.zero;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    _fallbackToNominalWidths();
  }

  @override
  void didUpdateWidget(covariant HyperosOverlayNestedHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.prefixes, widget.prefixes) ||
        !identical(oldWidget.suffixes, widget.suffixes)) {
      // 图标组换了：实测宽度作废，先退回名义估算，帧末再量一次。
      _fallbackToNominalWidths();
    }
  }

  void _fallbackToNominalWidths() {
    _prefixesSize = Size(
      widget.prefixes.length * _kNominalHeaderSlotWidth,
      0,
    );
    _suffixesSize = Size(
      widget.suffixes.length * _kNominalHeaderSlotWidth,
      0,
    );
    _measured = false;
  }

  void _scheduleMeasure() {
    if (_measured) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      var bothRead = true;
      var didChange = false;
      void measure(GlobalKey key, Size current, ValueSetter<Size> setter) {
        final context = key.currentContext;
        if (context == null) {
          bothRead = false;
          return;
        }
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) {
          bothRead = false;
          return;
        }
        if (box.size != current) {
          setter(box.size);
          didChange = true;
        }
      }

      measure(_prefixesKey, _prefixesSize, (size) => _prefixesSize = size);
      measure(_suffixesKey, _suffixesSize, (size) => _suffixesSize = size);
      if (!mounted || !bothRead) {
        return;
      }
      // 两边都量到了才收工：宽度与名义值相同的图标组也算量过，不再每帧挂
      // postFrameCallback。
      _measured = true;
      if (didChange) {
        setState(() {});
      }
    });
  }

  /// 标题的自然宽度。只有纯 [Text] 算得出来，别的（复合标题）返回 null，
  /// 那种情况退化成「填满空档再居中」——一样不压图标。
  ///
  /// 同步算、不等回填：夹取**位置**必须先知道标题有多宽，而它可能比空档宽，
  /// 只夹宽度的话居中的那一截照样会捅到图标那边去（空档与整条栏不同心时）。
  double? _naturalTitleWidth(BuildContext context, TextStyle style) {
    final title = widget.title;
    if (title is! Text) {
      return null;
    }
    final data = title.data;
    if (data == null || data.isEmpty) {
      return null;
    }
    final painter = TextPainter(
      text: TextSpan(text: data, style: style.merge(title.style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.isFinite ? width : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    final font = DefaultTextStyle.of(context).style;
    final titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: colors.onBackground,
      fontFamily: font.fontFamily,
      fontFamilyFallback: font.fontFamilyFallback,
    );
    _scheduleMeasure();
    return SafeArea(
      bottom: false,
      child: Semantics(
        header: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // 标题能站的那段：左边让开前缀组、右边让开后缀组，各留 10。
                final gapLeft = _prefixesSize.width + _kHeaderTitleInset;
                final gapRight = width - _suffixesSize.width - _kHeaderTitleInset;
                // 图标多到中间没空档了（两侧加起来超过整条栏）就不夹：这时
                // 标题压上去也比被压成一个点强，退回旧的整条栏居中。
                final hasGap = gapRight > gapLeft;
                final gapWidth = hasGap ? gapRight - gapLeft : width;
                final naturalWidth = _naturalTitleWidth(context, titleStyle);
                final titleWidth = naturalWidth == null
                    ? gapWidth
                    : math.min(naturalWidth, gapWidth);
                var left = (width - titleWidth) / 2;
                if (hasGap) {
                  if (left < gapLeft) {
                    left = gapLeft;
                  } else if (left > gapRight - titleWidth) {
                    left = gapRight - titleWidth;
                  }
                }
                return Stack(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        KeyedSubtree(
                          key: _prefixesKey,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.prefixes,
                          ),
                        ),
                        KeyedSubtree(
                          key: _suffixesKey,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.suffixes,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: titleWidth,
                      child: IgnorePointer(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: titleWidth),
                            child: DefaultTextStyle.merge(
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                              style: titleStyle,
                              child: widget.title,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
