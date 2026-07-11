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

  return showDialog<String>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierColor: HyperosColors.windowDimming(context),
    builder: (ctx) => _AppTextInputDialog(
      title: title,
      initialValue: initialValue,
      bodyBuilder: bodyBuilder,
      cancelLabel: cancelLabel ?? l10n.cancelAction,
      confirmLabel: confirmLabel ?? l10n.saveAction,
      validate: validate,
    ),
  );
}

class _AppTextInputDialog extends StatefulWidget {
  const _AppTextInputDialog({
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
  State<_AppTextInputDialog> createState() => _AppTextInputDialogState();
}

class _AppTextInputDialogState extends State<_AppTextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (widget.validate != null && !widget.validate!(value)) {
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return HyperosDialog(
      title: widget.title,
      body: widget.bodyBuilder(_controller),
      actions: [
        HyperosDialogAction(
          label: widget.cancelLabel,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: widget.confirmLabel,
          isPrimary: true,
          onPressed: _submit,
        ),
      ],
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

  return showDialog<int>(
    context: context,
    barrierColor: HyperosColors.windowDimming(context),
    builder: (ctx) {
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
                onPressed: () => Navigator.pop(ctx),
              ),
              HyperosDialogAction(
                label: confirmLabel ?? l10n.saveAction,
                isPrimary: true,
                onPressed: () => Navigator.pop(ctx, selectedIndex),
              ),
            ],
          );
        },
      );
    },
  );
}
