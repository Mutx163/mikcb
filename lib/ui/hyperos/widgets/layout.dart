import 'package:flutter/material.dart';

import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';

class HyperosInsetDivider extends StatelessWidget {
  const HyperosInsetDivider({super.key, required this.indent});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: const Divider(
        height: 0.5,
        thickness: 0.5,
        color: HyperosTokens.divider,
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

EdgeInsets hyperosRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.rowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
}

EdgeInsets hyperosChevronRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.chevronRowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
}

/// Fixed-height row shell shared by settings list tiles (56dp single-line default).
Widget hyperosListRowShell({
  required EdgeInsetsGeometry padding,
  required Widget child,
  double? minHeight,
}) {
  final targetHeight = minHeight ?? HyperosTokens.listRowMinHeight;
  final padded = Padding(
    padding: padding,
    child: child,
  );
  // Two-line rows use min height so subtitle ellipsis survives narrow widths
  // (e.g. HyperosPageRoute shared-axis transition) without bottom overflow.
  if (minHeight != null && minHeight > HyperosTokens.listRowMinHeight) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: targetHeight),
      child: padded,
    );
  }
  return SizedBox(height: targetHeight, child: padded);
}

/// White rounded card grouping list rows.
class HyperosListGroup extends StatelessWidget {
  const HyperosListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: HyperosColors.card(context),
        shape: HyperosTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
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
        padding: EdgeInsets.only(
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
        padding: EdgeInsets.only(
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
