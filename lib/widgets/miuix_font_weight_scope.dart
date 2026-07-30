import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

/// 读取 Android 系统字体粗细增量（`Configuration.fontWeightAdjustment`）。
///
/// Android 12+ 返回该增量；低版本、未定义或非 Android 返回 null，交由调用方
/// 回退到 [MediaQueryData.boldText]。
abstract final class SystemFontWeightService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/system_ui',
  );

  static Future<int?> readAdjustment() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>('getFontWeightAdjustment');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// 让子树内的 flutter_miuix 组件字重跟随系统字体粗细。
///
/// flutter_miuix 的文字默认不随系统字重变化（不像 Compose 由 Android Typeface
/// 自动套用 fontWeightAdjustment）。此 scope 读取原生增量（Android 12+），失败时
/// 回退到 [MediaQueryData.boldText]，据此为子树提供一个"已按角色分级平移字重"的
/// [MiuixTheme]，并屏蔽 Flutter 框架对 [Text] 的统一加粗，避免盖掉分级结果。
///
/// 只影响字重：配色与亮度沿用当前 [MiuixTheme.of]（本项目即 Miuix 默认浅色回退），
/// 不改变设置页现有观感。
class MiuixFontWeightScope extends StatefulWidget {
  const MiuixFontWeightScope({required this.child, super.key});

  final Widget child;

  @override
  State<MiuixFontWeightScope> createState() => _MiuixFontWeightScopeState();
}

class _MiuixFontWeightScopeState extends State<MiuixFontWeightScope>
    with WidgetsBindingObserver {
  int? _adjustment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 系统字体粗细变化会触发配置变更（metrics）或无障碍特性变更，两者都重读。
  @override
  void didChangeMetrics() => _refresh();

  @override
  void didChangeAccessibilityFeatures() => _refresh();

  Future<void> _refresh() async {
    final value = await SystemFontWeightService.readAdjustment();
    if (!mounted || value == _adjustment) {
      return;
    }
    setState(() => _adjustment = value);
  }

  @override
  Widget build(BuildContext context) {
    final delta =
        _adjustment ??
        (MediaQuery.boldTextOf(context) ? kMiuixBoldTextFontWeightDelta : 0);

    // 沿用当前配色/亮度（本项目为 Miuix 浅色回退），仅调整字重。
    final existing = MiuixTheme.of(context);
    final data = MiuixThemeData(
      colors: existing.colors,
      brightness: existing.brightness,
      textStyles: applyFontWeightDelta(defaultTextStyles(), delta),
      fontWeightAdjustment: delta,
    );

    // delta != 0 时屏蔽框架的"统一加粗到 w700"，让分级字重成为唯一权威。
    Widget child = widget.child;
    if (delta != 0) {
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null && mediaQuery.boldText) {
        child = MediaQuery(
          data: mediaQuery.copyWith(boldText: false),
          child: child,
        );
      }
    }

    return MiuixTheme(data: data, child: child);
  }
}
