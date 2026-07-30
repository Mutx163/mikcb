import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_theme.dart';

/// Title that stays hidden while the page rests and fades in once content
/// scrolls under the frosted bar (MIUI updater style: bar is empty at rest,
/// a small centered title appears together with the frost).
///
/// Reads [HyperosBlurredHeaderScope.contentUnderHeader], so it only works
/// inside an overlay-header page shell ([HyperosSubpage] and friends).
/// Reveal/hide timings mirror the Miuix small-title folme spring
/// (show 300ms / hide 150ms, easeOutCubic + slight upward rise).
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

/// Nested settings header safe for blur overlay stacks.
///
/// [FHeader.nested] uses [_RenderNestedHeader] which asserts when prefix and
/// suffix widths consume the full bar (common during route transitions in
/// [Stack] overlays). This widget keeps the same visuals with [Stack] + [Row]
/// layout that never produces invalid title constraints.
class HyperosOverlayNestedHeader extends StatelessWidget {
  const HyperosOverlayNestedHeader({
    super.key,
    required this.title,
    this.prefixes = const [],
    this.suffixes = const [],
    this.style,
  });

  final Widget title;
  final List<Widget> prefixes;
  final List<Widget> suffixes;
  final FHeaderStyleDelta? style;

  @override
  Widget build(BuildContext context) {
    final resolved = (style ?? HyperosTheme.nestedHeaderStyle(context))(
      context.theme.headerStyles.resolve({
        context.platformVariant,
        FHeaderVariant.nested,
      }),
    );

    Widget prefixRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: resolved.actionSpacing,
      children: prefixes,
    );
    Widget suffixRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: resolved.actionSpacing,
      children: suffixes,
    );

    final slidable = resolved.slidableActions.resolve({
      context.platformVariant,
    });
    if (slidable && prefixes.isNotEmpty) {
      prefixRow = FTappableGroup(child: prefixRow);
    }
    if (slidable && suffixes.isNotEmpty) {
      suffixRow = FTappableGroup(child: suffixRow);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: resolved.systemOverlayStyle,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          header: true,
          child: ConstrainedBox(
            constraints: resolved.constraints,
            child: Padding(
              padding: resolved.padding.resolve(Directionality.of(context)),
              child: FHeaderData(
                actionStyle: resolved.actionStyle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [prefixRow, suffixRow],
                    ),
                    // Title is decorative; must not steal taps from prefix/suffix
                    // actions in the Row below (fixes save/back dead zones).
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Builder(
                          builder: (titleContext) {
                            final appFont =
                                DefaultTextStyle.of(titleContext).style;
                            final titleStyle =
                                resolved.titleTextStyle.copyWith(
                              fontFamily: appFont.fontFamily,
                              fontFamilyFallback: appFont.fontFamilyFallback,
                            );
                            return DefaultTextStyle.merge(
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                              style: titleStyle,
                              textAlign: TextAlign.center,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              child: title,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
