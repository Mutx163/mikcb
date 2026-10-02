import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
  bool destructiveConfirm = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showHyperosConfirmDialog(
    context: context,
    title: title,
    message: message,
    cancelLabel: cancelLabel ?? l10n.cancelAction,
    confirmLabel: confirmLabel ?? l10n.confirmImportAction,
    destructive: destructiveConfirm,
  );
}

Future<bool?> showAppConfirmDialogWithBody(
  BuildContext context, {
  required String title,
  required Widget body,
  String? cancelLabel,
  String? confirmLabel,
  bool destructiveConfirm = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showHyperosDialog<bool>(
    context: context,
    title: title,
    body: body,
    actions: [
      HyperosDialogAction(
        label: cancelLabel ?? l10n.cancelAction,
        onPressed: () => Navigator.pop(context, false),
      ),
      HyperosDialogAction(
        label: confirmLabel ?? l10n.confirmImportAction,
        isPrimary: !destructiveConfirm,
        isDestructive: destructiveConfirm,
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );
}

/// Returns `null` for cancel, `false` for secondary, `true` for primary.
Future<bool?> showAppTripleActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,
  required String secondaryLabel,
  required String primaryLabel,
}) {
  return showHyperosDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: [
      HyperosDialogAction(
        label: cancelLabel,
        onPressed: () => Navigator.pop(context),
      ),
      HyperosDialogAction(
        label: secondaryLabel,
        onPressed: () => Navigator.pop(context, false),
      ),
      HyperosDialogAction(
        label: primaryLabel,
        isPrimary: true,
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );
}

/// Single-line name prompt — floating HyperOS bottom card.
///
/// Same shell as [showHyperosDialog]: outer inset, full rounded surface card,
/// solid [HyperosButton]s (secondary cancel + primary confirm).
Future<String?> showAppTextInputDialog(
  BuildContext context, {
  required String title,
  required Widget Function(TextEditingController controller) bodyBuilder,
  String? cancelLabel,
  String? confirmLabel,
  String? initialValue,
  bool Function(String value)? validate,
  bool useRootNavigator = false,
}) {
  final l10n = AppLocalizations.of(context)!;

  return showHyperosSheet<String>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (sheetContext) => _AppTextInputSheet(
      title: title,
      initialValue: initialValue,
      bodyBuilder: bodyBuilder,
      cancelLabel: cancelLabel ?? l10n.cancelAction,
      confirmLabel: confirmLabel ?? l10n.saveAction,
      validate: validate,
    ),
  );
}

class _AppTextInputSheet extends StatefulWidget {
  const _AppTextInputSheet({
    required this.title,
    required this.bodyBuilder,
    required this.cancelLabel,
    required this.confirmLabel,
    this.initialValue,
    this.validate,
  });

  final String title;
  final String? initialValue;
  final Widget Function(TextEditingController controller) bodyBuilder;
  final String cancelLabel;
  final String confirmLabel;
  final bool Function(String value)? validate;

  @override
  State<_AppTextInputSheet> createState() => _AppTextInputSheetState();
}

class _AppTextInputSheetState extends State<_AppTextInputSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  /// 校验是否通过。只在「通过 ⇄ 不通过」翻转时重建，避免每次按键都重画弹层。
  late bool _isValid;

  bool get _computeValid =>
      widget.validate == null || widget.validate!(_controller.text.trim());

  @override
  void initState() {
    super.initState();
    _isValid = _computeValid;
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final next = _computeValid;
    if (next == _isValid) {
      return;
    }
    setState(() => _isValid = next);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (widget.validate != null && !widget.validate!(value)) {
      // 兜底：确认按钮在校验不过时已经是禁用态（onPressed: null），这里不再
      // 是唯一的守门人。修复前只有这一句静默 return —— 课表档/作息模板/主题
      // 命名的调用方传的都是 `value.isNotEmpty`，名字留空点「创建」界面一动
      // 不动，用户只能反复点或以为 app 卡死。
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return HyperosSheetFrame(
      chrome: HyperosSheetChrome.floating,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: HyperosTypography.sheetTitle(context)),
          const SizedBox(height: 16),
          widget.bodyBuilder(_controller),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: widget.cancelLabel,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HyperosButton(
                  label: widget.confirmLabel,
                  expand: true,
                  onPressed: _isValid ? _submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<int?> showAppSingleChoiceDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
  int initialIndex = 0,
  String? cancelLabel,
  String? confirmLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  var selectedIndex = initialIndex.clamp(
    0,
    options.isEmpty ? 0 : options.length - 1,
  );

  return showHyperosSheet<int>(
    context: context,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return HyperosDialog(
            title: title,
            body: HyperosChoiceGroup(
              children: [
                for (var i = 0; i < options.length; i++)
                  HyperosChoiceTile(
                    title: options[i],
                    selected: selectedIndex == i,
                    highlightSelectedText: true,
                    onTap: () => setState(() => selectedIndex = i),
                  ),
              ],
            ),
            actions: [
              HyperosDialogAction(
                label: cancelLabel ?? l10n.cancelAction,
                onPressed: () => Navigator.pop(sheetContext),
              ),
              HyperosDialogAction(
                label: confirmLabel ?? l10n.saveAction,
                isPrimary: true,
                onPressed: () => Navigator.pop(sheetContext, selectedIndex),
              ),
            ],
          );
        },
      );
    },
  );
}
