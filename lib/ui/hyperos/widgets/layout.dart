import 'package:flutter/material.dart';

import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';
import 'adaptive_card.dart';

class HyperosInsetDivider extends StatelessWidget {
  const HyperosInsetDivider({super.key, required this.indent});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: HyperosColors.dividerLine(context),
      ),
    );
  }
}

/// Position of a tile inside a [HyperosListGroup] (first / last row).
class HyperosListTileScope extends InheritedWidget {
  const HyperosListTileScope({
    super.key,
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  final bool isFirst;
  final bool isLast;

  static HyperosListTileScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HyperosListTileScope>();
  }

  @override
  bool updateShouldNotify(HyperosListTileScope oldWidget) {
    return isFirst != oldWidget.isFirst || isLast != oldWidget.isLast;
  }
}

/// Marks descendants inside [HyperosControlCard].
///
/// The card body is edge-to-edge; interactive rows apply [HyperosTokens.rowPaddingUniform]
/// themselves. Non-row blocks should wrap in [HyperosControlCardInset].
class HyperosControlCardScope extends InheritedWidget {
  const HyperosControlCardScope({
    super.key,
    required this.hasHeader,
    required this.bodyBottomInset,
    required this.cornerRadius,
    required super.child,
  });

  static const defaultHorizontalPadding = 16.0;

  /// Extra bottom inset for non-edge-to-edge cards (inset content under a
  /// header). Edge-to-edge preference rows use first/last row padding only —
  /// do not add this under a lone select row or the label looks top-heavy.
  static const defaultBodyBottomInset = 12.0;

  /// Whether [HyperosControlCard] rendered a title/subtitle block above [child].
  final bool hasHeader;
  final double bodyBottomInset;
  final double cornerRadius;

  static HyperosControlCardScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosControlCardScope>();
  }

  @override
  bool updateShouldNotify(HyperosControlCardScope oldWidget) {
    return hasHeader != oldWidget.hasHeader ||
        bodyBottomInset != oldWidget.bodyBottomInset ||
        cornerRadius != oldWidget.cornerRadius;
  }
}

/// Positions a full-bleed row inside [HyperosControlCard] (first/last padding).
class HyperosControlCardRowScope extends InheritedWidget {
  const HyperosControlCardRowScope({
    super.key,
    required this.isFirst,
    required this.isLast,
    required super.child,
  });

  final bool isFirst;
  final bool isLast;

  static HyperosControlCardRowScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosControlCardRowScope>();
  }

  @override
  bool updateShouldNotify(HyperosControlCardRowScope oldWidget) {
    return isFirst != oldWidget.isFirst || isLast != oldWidget.isLast;
  }
}

/// Stacks multiple full-bleed rows inside one [HyperosControlCard].
///
/// **Required** when a card holds more than one [HyperosSelectTile],
/// [HyperosSwitchTile], [HyperosSliderTile], or similar preference row.
/// Without this wrapper, every row assumes it is both first and last and the
/// top/bottom padding looks uneven (first row glued to the top, later rows
/// over-padded).
///
/// Prefer [HyperosListGroup] when there is no card title/subtitle and the
/// whole block is only preference rows (system Settings list style).
class HyperosControlCardRows extends StatelessWidget {
  const HyperosControlCardRows({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          HyperosControlCardRowScope(
            isFirst: i == 0,
            isLast: i == children.length - 1,
            child: children[i],
          ),
      ],
    );
  }
}

/// Resolves first/last row flags for preference tiles.
///
/// Priority: [HyperosListTileScope] (ListGroup) → [HyperosControlCardRowScope]
/// (ControlCardRows) → standalone first+last.
({bool isFirst, bool isLast}) hyperosRowEdgeFlags(BuildContext context) {
  final listScope = HyperosListTileScope.maybeOf(context);
  final cardRowScope = HyperosControlCardRowScope.maybeOf(context);
  return (
    isFirst: listScope?.isFirst ?? cardRowScope?.isFirst ?? true,
    isLast: listScope?.isLast ?? cardRowScope?.isLast ?? true,
  );
}

EdgeInsets hyperosRowPadding(BuildContext context) {
  final edges = hyperosRowEdgeFlags(context);
  return HyperosTokens.rowPadding(isFirst: edges.isFirst, isLast: edges.isLast);
}

EdgeInsets hyperosChevronRowPadding(BuildContext context) {
  final edges = hyperosRowEdgeFlags(context);
  return HyperosTokens.chevronRowPadding(
    isFirst: edges.isFirst,
    isLast: edges.isLast,
  );
}

/// Fixed-height row shell shared by settings list tiles (56dp single-line default).
Widget hyperosListRowShell({
  Key? key,
  required EdgeInsetsGeometry padding,
  required Widget child,
  double? minHeight,
}) {
  final targetHeight = minHeight ?? HyperosTokens.listRowMinHeight;
  final padded = Padding(padding: padding, child: child);
  // Two-line rows use min height so subtitle ellipsis survives narrow widths
  // (e.g. HyperosPageRoute shared-axis transition) without bottom overflow.
  if (minHeight != null && minHeight > HyperosTokens.listRowMinHeight) {
    return ConstrainedBox(
      key: key,
      constraints: BoxConstraints(minHeight: targetHeight),
      child: padded,
    );
  }
  return SizedBox(key: key, height: targetHeight, child: padded);
}

/// White rounded card grouping list rows.
///
/// Corner radius adapts to content height so a single action row (e.g. cloud
/// disconnect) does not look like a stadium capsule.
class HyperosListGroup extends StatelessWidget {
  const HyperosListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: HyperosAdaptiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++)
              HyperosListTileScope(
                isFirst: i == 0,
                isLast: i == children.length - 1,
                child: children[i],
              ),
          ],
        ),
      ),
    );
  }
}

/// Light caption above a settings block (Miuix preference category).
class HyperosSectionLabel extends StatelessWidget {
  const HyperosSectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(
          left: HyperosTokens.sectionLabelInset,
          right: HyperosTokens.sectionLabelInset,
          bottom: 8,
        ),
        child: Text(text, style: HyperosTypography.sectionLabel(context)),
      ),
    );
  }
}

/// Footnote below a [HyperosListGroup] (Miuix preference category helper).
///
/// Order: [HyperosSectionLabel] -> [HyperosListGroup] -> [HyperosSectionDescription].
class HyperosSectionDescription extends StatelessWidget {
  const HyperosSectionDescription({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(
          left: HyperosTokens.sectionLabelInset,
          right: HyperosTokens.sectionLabelInset,
          top: 8,
        ),
        child: Text(
          text,
          style: HyperosTypography.sectionDescription(context),
          softWrap: true,
        ),
      ),
    );
  }
}

/// HyperOS settings block: section title, multiline remark, then a card body.
///
/// Use for select rows ([HyperosListGroup]) or control cards below the remark.
class HyperosSettingsBlock extends StatelessWidget {
  const HyperosSettingsBlock({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.gapBeforeChild = 0,
  });

  final String title;
  final String? description;
  final Widget child;
  final double gapBeforeChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosSectionLabel(text: title),
        if (description != null && description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: HyperosTokens.sectionLabelInset,
              right: HyperosTokens.sectionLabelInset,
            ),
            child: Text(
              description!,
              style: HyperosTypography.sectionDescription(context),
              softWrap: true,
            ),
          ),
        SizedBox(height: gapBeforeChild),
        child,
      ],
    );
  }
}

/// Scroll state shared by rows inside [HyperosListView].
class HyperosListScrollScope extends InheritedWidget {
  const HyperosListScrollScope({
    super.key,
    required this.isUserScrolling,
    required this.pressHighlightGeneration,
    required super.child,
  });

  final bool isUserScrolling;

  /// Bumped on [ScrollStartNotification] so rows cancel pending press highlights.
  final int pressHighlightGeneration;

  static HyperosListScrollScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HyperosListScrollScope>();
  }

  static bool isUserScrollingOf(BuildContext context) {
    return maybeOf(context)?.isUserScrolling ?? false;
  }

  static int pressHighlightGenerationOf(BuildContext context) {
    return maybeOf(context)?.pressHighlightGeneration ?? 0;
  }

  @override
  bool updateShouldNotify(HyperosListScrollScope oldWidget) {
    return isUserScrolling != oldWidget.isUserScrolling ||
        pressHighlightGeneration != oldWidget.pressHighlightGeneration;
  }
}

enum PressPhase { idle, pending, highlighted, flash }

class HyperosSectionGap extends StatelessWidget {
  const HyperosSectionGap({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: HyperosTokens.sectionGap);
  }
}
