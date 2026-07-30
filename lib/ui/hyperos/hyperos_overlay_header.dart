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

class HyperosOverlayNestedHeader extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    final font = DefaultTextStyle.of(context).style;
    return SafeArea(
      bottom: false,
      child: Semantics(
        header: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: prefixes),
                    Row(mainAxisSize: MainAxisSize.min, children: suffixes),
                  ],
                ),
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: DefaultTextStyle.merge(
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: colors.onBackground,
                        fontFamily: font.fontFamily,
                        fontFamilyFallback: font.fontFamilyFallback,
                      ),
                      child: title,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
