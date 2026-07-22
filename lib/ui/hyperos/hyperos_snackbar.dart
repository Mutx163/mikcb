import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

/// Dismisses the active HyperOS system toast (if any).
void hideHyperosToast({bool animated = true}) {
  _HyperosToastController.hide(animated: animated);
}

Color _toastMessageColor() {
  // System status toast is always black on milky glass — not theme primary blue.
  return HyperosMiuixSnackbar.messageColor;
}

Color _toastDescriptionColor() {
  return HyperosMiuixSnackbar.messageColor.withValues(alpha: 0.72);
}

Color _toastTint(BuildContext context, {required bool withBlur}) {
  // Blur on: milky translucent glass. Blur off: solid white (never see-through).
  if (!withBlur) {
    return HyperosColors.surfaceContainer(context);
  }
  return Colors.white.withValues(alpha: HyperosMiuixSnackbar.tintAlphaWithBlur);
}

TextStyle _messageStyle() {
  return TextStyle(
    fontSize: HyperosMiuixSnackbar.messageFontSize,
    fontWeight: HyperosMiuixSnackbar.messageFontWeight,
    height: HyperosMiuixSnackbar.messageLineHeight,
    color: _toastMessageColor(),
  );
}

TextStyle _descriptionStyle() {
  return TextStyle(
    fontSize: HyperosMiuixTypography.footnote1,
    fontWeight: FontWeight.w400,
    height: 1.25,
    color: _toastDescriptionColor(),
  );
}

TextStyle _actionStyle(BuildContext context) {
  return TextStyle(
    fontSize: HyperosMiuixSnackbar.actionFontSize,
    fontWeight: FontWeight.w500,
    height: HyperosMiuixSnackbar.messageLineHeight,
    color: HyperosColors.primary(context),
  );
}

/// Frosted system-style toast: content-tight rounded rect (not a full capsule).
class HyperosToastCapsule extends StatelessWidget {
  const HyperosToastCapsule({
    super.key,
    required this.message,
    this.description,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? description;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxOuterWidth = screenWidth * HyperosMiuixSnackbar.maxWidthFraction;
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final tint = _toastTint(context, withBlur: useBlur);
    // Same sigma as 外观与配色 / sheet frosted glass.
    final blurSigma = HyperosBlurredHeader.blurSigmaOf(context);
    final hasAction = actionLabel != null && onAction != null;
    final messageColor = _toastMessageColor();
    final hasDescription = description != null && description!.isNotEmpty;

    // Keep label wrapping within content-tight shell (not screen-wide).
    final maxTextWidth =
        maxOuterWidth -
        HyperosMiuixSnackbar.insideMarginHorizontal * 2 -
        (icon != null
            ? HyperosMiuixSnackbar.iconSize + HyperosMiuixSnackbar.iconGap
            : 0) -
        (hasAction ? 72 : 0);

    final textBlock = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxTextWidth.clamp(64, maxOuterWidth),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _messageStyle(),
          ),
          if (hasDescription) ...[
            const SizedBox(height: HyperosTokens.titleCaptionGap),
            Text(
              description!,
              textAlign: TextAlign.center,
              // Longer apply/result hints need more than two lines.
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: _descriptionStyle(),
            ),
          ],
        ],
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: HyperosMiuixSnackbar.iconSize,
            color: iconColor ?? messageColor,
          ),
          const SizedBox(width: HyperosMiuixSnackbar.iconGap),
        ],
        textBlock,
        if (hasAction) ...[
          const SizedBox(width: HyperosMiuixSnackbar.actionStartPadding),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Text(actionLabel!, style: _actionStyle(context)),
            ),
          ),
        ],
      ],
    );

    final radius = BorderRadius.circular(HyperosMiuixSnackbar.cornerRadius);

    // IntrinsicWidth is critical: never let [Center]/[Stack]/[Positioned.fill]
    // expand the glass to the full Overlay max width.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxOuterWidth),
      child: IntrinsicWidth(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: HyperosMiuixSnackbar.shadowAlpha,
                ),
                blurRadius: HyperosMiuixSnackbar.shadowRadius,
                offset: const Offset(0, HyperosMiuixSnackbar.shadowYOffset),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: useBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: blurSigma,
                            sigmaY: blurSigma,
                            tileMode: TileMode.clamp,
                          ),
                          child: ColoredBox(color: tint),
                        )
                      : ColoredBox(color: tint),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HyperosMiuixSnackbar.insideMarginHorizontal,
                    vertical: HyperosMiuixSnackbar.insideMarginVertical,
                  ),
                  child: content,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _HyperosToastController {
  static OverlayEntry? _entry;
  static VoidCallback? _requestDismiss;

  static void hide({bool animated = true}) {
    if (animated && _requestDismiss != null) {
      _requestDismiss!();
      return;
    }
    _removeEntry();
  }

  static void _removeEntry() {
    _requestDismiss = null;
    final entry = _entry;
    _entry = null;
    if (entry == null) {
      return;
    }
    // Never remove mid-layout; bottom sheets may still be measuring.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      entry.remove();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        entry.remove();
      });
    }
  }

  static void show({
    required BuildContext context,
    required String message,
    String? description,
    IconData? icon,
    Color? iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration,
  }) {
    final overlayState =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlayState == null) {
      return;
    }

    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    final content = _HyperosToastContent(
      message: message,
      description: description,
      icon: icon,
      iconColor: iconColor,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );

    // Prefer in-place update on a long-lived host. Creating/destroying
    // FadeTransition + AnimationController while a modal bottom sheet is
    // laying out triggers ChangeNotifier.debugAssertNotDisposed.
    final hostState = _HyperosToastHostState.current;
    if (hostState != null && hostState.mounted && _entry != null) {
      hostState.showContent(content);
      return;
    }

    void insertHost() {
      final liveHost = _HyperosToastHostState.current;
      if (liveHost != null && liveHost.mounted && _entry != null) {
        liveHost.showContent(content);
        return;
      }

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (overlayContext) {
          return _HyperosToastHost(
            initialContent: content,
            registerDismiss: (requestDismiss) {
              if (_entry == entry) {
                _requestDismiss = requestDismiss;
              }
            },
            onDismissed: () {
              if (_entry == entry) {
                _removeEntry();
              }
            },
          );
        },
      );
      _entry = entry;
      overlayState.insert(entry);
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      insertHost();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        insertHost();
      });
    }
  }
}

class _HyperosToastContent {
  const _HyperosToastContent({
    required this.message,
    required this.duration,
    this.description,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? description;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
}

class _HyperosToastHost extends StatefulWidget {
  const _HyperosToastHost({
    required this.initialContent,
    required this.registerDismiss,
    required this.onDismissed,
  });

  final _HyperosToastContent initialContent;
  final void Function(VoidCallback requestDismiss) registerDismiss;
  final VoidCallback onDismissed;

  @override
  State<_HyperosToastHost> createState() => _HyperosToastHostState();
}

class _HyperosToastHostState extends State<_HyperosToastHost> {
  static _HyperosToastHostState? current;

  late _HyperosToastContent _content = widget.initialContent;
  double _opacity = 0;
  double _scale = HyperosMiuixSnackbar.enterScale;
  Timer? _autoHideTimer;
  bool _isExiting = false;
  int _showGeneration = 0;

  @override
  void initState() {
    super.initState();
    current = this;
    widget.registerDismiss(_dismiss);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _opacity = 1;
        _scale = 1;
      });
      _scheduleAutoHide(_content.duration);
    });
  }

  void showContent(_HyperosToastContent content) {
    if (!mounted) {
      return;
    }
    _showGeneration += 1;
    _isExiting = false;
    _autoHideTimer?.cancel();
    setState(() {
      _content = content;
      _opacity = 1;
      _scale = 1;
    });
    _scheduleAutoHide(content.duration);
  }

  void _scheduleAutoHide(Duration duration) {
    _autoHideTimer?.cancel();
    if (duration <= Duration.zero) {
      return;
    }
    final generation = _showGeneration;
    _autoHideTimer = Timer(duration, () {
      if (!mounted || generation != _showGeneration) {
        return;
      }
      unawaited(_dismiss());
    });
  }

  Future<void> _dismiss() async {
    if (_isExiting || !mounted) {
      return;
    }
    _isExiting = true;
    _autoHideTimer?.cancel();
    setState(() {
      _opacity = 0;
      _scale = HyperosMiuixSnackbar.enterScale;
    });
    await Future<void>.delayed(
      const Duration(milliseconds: HyperosMiuixSnackbar.exitMs),
    );
    if (!mounted) {
      return;
    }
    widget.onDismissed();
  }

  void _handleAction() {
    final action = _content.onAction;
    if (action == null) {
      return;
    }
    action();
    unawaited(_dismiss());
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    if (identical(current, this)) {
      current = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.paddingOf(context).bottom +
        HyperosMiuixSnackbar.hostBottomPadding;
    final animMs = _opacity >= 1
        ? HyperosMiuixSnackbar.enterMs
        : HyperosMiuixSnackbar.exitMs;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HyperosMiuixSnackbar.outerPaddingHorizontal,
          ),
          // Implicit animations only — no AnimationController for the toast
          // transitions, so modal sheet layout cannot addListener on a disposed
          // ticker.
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: Duration(milliseconds: animMs),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: _scale,
              duration: Duration(milliseconds: animMs),
              curve: Curves.easeOutCubic,
              child: Material(
                type: MaterialType.transparency,
                child: HyperosToastCapsule(
                  message: _content.message,
                  description: _content.description,
                  icon: _content.icon,
                  iconColor: _content.iconColor,
                  actionLabel: _content.actionLabel,
                  onAction: _content.onAction == null ? null : _handleAction,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a HyperOS system-style frosted toast (no swipe dismiss; auto-hides).
void showHyperosSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(
    milliseconds: HyperosMiuixSnackbar.durationShortMs,
  ),
}) {
  _HyperosToastController.show(
    context: context,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

/// Rich frosted toast with optional icon and secondary line (app toast pattern).
void showHyperosRichSnackBar(
  BuildContext context, {
  required String message,
  String? description,
  IconData? icon,
  Color? iconColor,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(
    milliseconds: HyperosMiuixSnackbar.durationShortMs,
  ),
}) {
  _HyperosToastController.show(
    context: context,
    message: message,
    description: description,
    icon: icon,
    iconColor: iconColor,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

/// Compatibility alias — prefer [showHyperosSnackBar] / [showHyperosRichSnackBar].
@Deprecated('Use showHyperosSnackBar instead of constructing a SnackBar')
class HyperosSnackBar extends SnackBar {
  HyperosSnackBar({
    super.key,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    super.duration = const Duration(
      milliseconds: HyperosMiuixSnackbar.durationShortMs,
    ),
    required BuildContext context,
  }) : super(
         behavior: SnackBarBehavior.floating,
         backgroundColor: Colors.transparent,
         elevation: 0,
         padding: EdgeInsets.zero,
         dismissDirection: DismissDirection.none,
         content: HyperosToastCapsule(
           message: message,
           actionLabel: actionLabel,
           onAction: onAction,
         ),
       );
}
