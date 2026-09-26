import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

/// HyperOS-styled text field — delegates to [MiuixTextField].
class HyperosTextField extends StatelessWidget {
  const HyperosTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.fontSize = HyperosMiuixTextField.labelFontSizeNormal,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? hint ?? '';
    final useLabelAsPlaceholder = label == null && hint != null;
    final resolvedColor = Theme.of(context).colorScheme;
    final miuixDefaults = MiuixTextFieldDefaults.textFieldColors(context);
    // 框体填充：Miuix 默认 secondaryContainer（亮 #F0F0F0）与 mikcb 页面背景
    // settingsBackground（#F2F2F2）只差约 2 个灰阶，未激活时整个框融进页面。
    // 亮色降一级用 secondary（#E6E6E6）让框立出来；暗色页面背景 #242424 与
    // secondaryContainer（#434343）本就对比充分，维持不变。标签/占位文字与
    // 聚焦边框保持 Miuix 默认配色。
    final fieldColors = MiuixTextFieldColors(
      backgroundColor: HyperosColors.textFieldContainer(context),
      labelColor: miuixDefaults.labelColor,
      borderColor: miuixDefaults.borderColor,
    );

    Widget buildField(TextEditingController? textController) => MiuixTextField(
      controller: textController,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      label: effectiveLabel,
      useLabelAsPlaceholder: useLabelAsPlaceholder,
      enabled: enabled,
      textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400),
      singleLine: maxLines == 1,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofocus: autofocus,
      colors: fieldColors,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 只有 hint（占位模式）时套一层桥：Miuix 不会在「文本变非空」时重建，
        // 那行灰色占位文字会留在框里压住输入内容，见 [_HintYieldsToTextBridge]。
        if (useLabelAsPlaceholder)
          _HintYieldsToTextBridge(
            controller: controller,
            builder: buildField,
          )
        else
          buildField(controller),
        if (helper != null && helper!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: TextStyle(
              fontSize: 12,
              color: resolvedColor.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

/// 强制随文本变化重建的桥，包住占位模式（`useLabelAsPlaceholder`）的输入框。
///
/// [MiuixTextField] 的标签显隐只挂在标签动画控制器上：`_onTextChanged` 仅当
/// 「是否浮动」与当前动画值不一致时才 forward / reverse。占位模式下文本由空变非空时，
/// 标签状态是 `normal → placeholder`，但动画值始终为 0 ⇒ 既不 forward 也不 reverse，
/// 也就没有任何通知，`AnimatedBuilder` 不重建，那行灰色占位文字就一直留在输入框里，
/// 正好压在你打的字上。
///
/// 平时这个坑被「敲键盘时顺带获得焦点」盖住（焦点变化会动边框动画控制器，顺带重建
/// 一次）。但 `autofocus: true` 的弹窗输入框一打开就已聚焦，没有任何别的重建来源，
/// 于是每敲一个字都叠一层灰字 —— 新建课表、重命名课表等弹窗即此。
///
/// 这里自己持有（外部没给就自建）controller，文本一变就 `setState` 一次，让
/// [MiuixTextField] 重新求值标签状态。零依赖改动，视觉与交互都不变。
class _HintYieldsToTextBridge extends StatefulWidget {
  const _HintYieldsToTextBridge({
    required this.controller,
    required this.builder,
  });

  final TextEditingController? controller;
  final Widget Function(TextEditingController controller) builder;

  @override
  State<_HintYieldsToTextBridge> createState() => _HintYieldsToTextBridgeState();
}

class _HintYieldsToTextBridgeState extends State<_HintYieldsToTextBridge> {
  /// 仅在外部未给 controller 时创建；外部给的那份归调用方所有，不能 dispose。
  TextEditingController? _ownedController;

  /// 当前挂监听的那份，用于换 controller 时正确摘挂。
  TextEditingController? _listeningTo;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _HintYieldsToTextBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(_listeningTo, _controller)) {
      _listeningTo?.removeListener(_onTextChanged);
      _attach();
    }
  }

  @override
  void dispose() {
    _listeningTo?.removeListener(_onTextChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  void _attach() {
    _listeningTo = _controller..addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

/// Tappable value field with the same chrome as [HyperosTextField].
///
/// Use on frosted sheets / forms instead of a bare [HyperosListTile] or white
/// [HyperosListGroup] (those read as opaque square cards and break glass UI).
class HyperosPickerField extends StatelessWidget {
  const HyperosPickerField({
    super.key,
    this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.leading,
    this.enabled = true,
    this.isPlaceholder = false,
    this.fontSize = HyperosMiuixTextField.labelFontSizeNormal,
    this.showChevron = true,
  });

  /// 顶部标签；为 null 时仅渲染字段本体，用于组标签已由外部提供的场景。
  final String? label;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;

  /// 行首自定义元素（如颜色块），先于 [icon] 渲染。
  final Widget? leading;
  final bool enabled;
  final bool isPlaceholder;
  final double fontSize;

  /// 尾部箭头开关。半宽紧凑字段（双列开始/结束对）可关闭，为长值文本
  /// （如「下午 12:00」）让出宽度，避免省略号截断。
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    final onSurface = HyperosColors.onSurface(context);
    final summary = HyperosColors.onSurfaceVariantSummary(context);
    final fill = HyperosColors.secondaryVariant(context);
    final disabled = HyperosColors.disabledOnSurface(context);
    final outline = HyperosColors.outline(context);
    final canTap = enabled && onTap != null;
    final radius = BorderRadius.circular(HyperosMiuixTextField.cornerRadius);
    final valueColor = !canTap
        ? disabled
        : (isPlaceholder || value.isEmpty ? summary : onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: fontSize,
              color: canTap ? onSurface : disabled,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Material(
          color: canTap ? fill : fill.withValues(alpha: 0.5),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canTap ? onTap : null,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: outline),
              ),
              child: Padding(
                padding: HyperosMiuixTextField.insideMargin,
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 10),
                    ],
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: canTap ? primary : disabled),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        value.isEmpty ? '—' : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: fontSize, color: valueColor),
                      ),
                    ),
                    if (showChevron)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: canTap ? summary : disabled,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Text field inside a white HyperOS control card.
class HyperosTextFieldTile extends StatelessWidget {
  const HyperosTextFieldTile({
    super.key,
    this.cardTitle,
    this.cardSubtitle,
    required this.field,
  });

  final String? cardTitle;
  final String? cardSubtitle;
  final HyperosTextField field;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cardTitle != null) ...[
              Text(cardTitle!, style: HyperosTypography.title(context)),
              if (cardSubtitle != null) ...[
                const SizedBox(height: HyperosTokens.titleCaptionGap),
                Text(
                  cardSubtitle!,
                  style: HyperosTypography.sectionDescription(context),
                ),
              ],
              const SizedBox(height: 12),
            ],
            field,
          ],
        ),
      ),
    );
  }
}
