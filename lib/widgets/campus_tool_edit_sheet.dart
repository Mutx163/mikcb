import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../domain/campus_tool_link_parser.dart';
import '../l10n/campus_tool_localizer.dart';
import '../models/campus_tool_entry.dart';
import '../ui/hyperos/hyperos.dart';
import 'campus_tool_icons.dart';

/// 打开「新建 / 编辑入口」弹层；保存时返回新条目，取消返回 null。
Future<CampusToolEntry?> showCampusToolEditSheet({
  required BuildContext context,
  CampusToolEntry? entry,
}) {
  return showHomeHyperosSheet<CampusToolEntry>(
    context: context,
    builder: (sheetContext) => CampusToolEditSheet(entry: entry),
  );
}

/// 入口编辑弹层。
///
/// 字段口径就是 QuickJump 的四级结构：直达链接（可带限定包名）→ 兜底应用
/// → 网页兜底，外加名称 / 图标 / 强制新开 / 启用开关。全部字段都可在界面
/// 里改，**改链接不需要等发版** —— 这是这类三方页面入口最容易失效的地方。
class CampusToolEditSheet extends StatefulWidget {
  const CampusToolEditSheet({super.key, this.entry});

  /// null = 新建。
  final CampusToolEntry? entry;

  @override
  State<CampusToolEditSheet> createState() => _CampusToolEditSheetState();
}

class _CampusToolEditSheetState extends State<CampusToolEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _linksController;
  late final TextEditingController _packagesController;
  late final TextEditingController _webController;
  late String _icon;
  late bool _clearTask;
  late bool _enabled;
  String? _error;

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.title ?? '');
    _linksController = TextEditingController(
      text: entry == null
          ? ''
          : <String>[for (final link in entry.links) link.editableLine].join('\n'),
    );
    _packagesController = TextEditingController(
      text: entry == null ? '' : entry.appPackages.join('\n'),
    );
    _webController = TextEditingController(text: entry?.webUri ?? '');
    _icon = entry?.icon ?? kCampusToolDefaultIconName;
    _clearTask = entry?.clearTask ?? false;
    _enabled = entry?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _linksController.dispose();
    _packagesController.dispose();
    _webController.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final id = widget.entry?.id ?? const Uuid().v4();
    final name = _nameController.text.trim();
    if (name.isEmpty && campusToolPresetTitle(l10n, id).isEmpty) {
      setState(() => _error = l10n.campusToolsErrorNameRequired);
      return;
    }
    final linksResult = parseCampusToolLinks(_linksController.text);
    if (!linksResult.ok) {
      setState(() {
        _error = linksResult.error == CampusToolLinkParseError.package
            ? l10n.campusToolsErrorInvalidPackage(linksResult.lineNumber)
            : l10n.campusToolsErrorInvalidLink(linksResult.lineNumber);
      });
      return;
    }
    final packagesResult = parseCampusToolPackages(_packagesController.text);
    if (!packagesResult.ok) {
      setState(() {
        _error = l10n.campusToolsErrorInvalidPackage(
          packagesResult.badLineNumber,
        );
      });
      return;
    }
    final web = _webController.text.trim();
    if (web.isNotEmpty && !isValidCampusToolWebUri(web)) {
      setState(() => _error = l10n.campusToolsErrorInvalidWeb);
      return;
    }
    if (linksResult.links.isEmpty &&
        packagesResult.packages.isEmpty &&
        web.isEmpty) {
      setState(() => _error = l10n.campusToolsErrorNoTarget);
      return;
    }
    Navigator.of(context).pop(
      CampusToolEntry(
        id: id,
        title: name,
        icon: _icon,
        links: linksResult.links,
        appPackages: packagesResult.packages,
        webUri: web.isEmpty ? null : web,
        clearTask: _clearTask,
        enabled: _enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.top;
    final maxHeight = (availableHeight * 0.9).clamp(
      280.0,
      mediaQuery.size.height * 0.88,
    );
    return HyperosSheetFrame(
      maxHeight: maxHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, l10n),
            const SizedBox(height: 16),
            _buildSectionLabel(context, l10n.campusToolsNameLabel),
            const SizedBox(height: 8),
            HyperosTextField(
              controller: _nameController,
              hint: l10n.campusToolsNameHint,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            _buildSectionLabel(context, l10n.campusToolsIconLabel),
            const SizedBox(height: 8),
            _buildIconPicker(context),
            const SizedBox(height: 18),
            _buildSectionLabel(
              context,
              l10n.campusToolsLinksLabel,
              hint: l10n.campusToolsLinksHint,
            ),
            const SizedBox(height: 8),
            HyperosTextField(
              controller: _linksController,
              hint: l10n.campusToolsLinksHint,
              maxLines: 5,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.campusToolsLinksHelp,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.secondaryText(context),
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionLabel(
              context,
              l10n.campusToolsAppPackagesLabel,
              hint: l10n.campusToolsAppPackagesHint,
            ),
            const SizedBox(height: 8),
            HyperosTextField(
              controller: _packagesController,
              hint: l10n.campusToolsAppPackagesHint,
              maxLines: 3,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 18),
            _buildSectionLabel(
              context,
              l10n.campusToolsWebFallbackLabel,
              hint: l10n.campusToolsWebFallbackHint,
            ),
            const SizedBox(height: 8),
            HyperosTextField(
              controller: _webController,
              hint: l10n.campusToolsWebFallbackHint,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 18),
            HyperosListGroup(
              children: [
                HyperosSwitchTile(
                  icon: Icons.open_in_new_rounded,
                  title: l10n.campusToolsClearTaskLabel,
                  subtitle: l10n.campusToolsClearTaskDesc,
                  value: _clearTask,
                  onChanged: (value) => setState(() => _clearTask = value),
                ),
                HyperosSwitchTile(
                  icon: Icons.visibility_outlined,
                  title: l10n.campusToolsEnabledLabel,
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: HyperosTypography.listDetail(context).copyWith(
                  color: HyperosColors.error(context),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: HyperosButton(
                    label: l10n.cancelAction,
                    variant: HyperosButtonVariant.secondary,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosButton(
                    label: l10n.campusToolsSaveAction,
                    expand: true,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final accent = HyperosColors.primary(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HyperosBlurredHeader.accentSurfaceTintColor(accent),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(campusToolIconFor(_icon), color: accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNew ? l10n.campusToolsAddTitle : l10n.campusToolsEditTitle,
                style: HyperosTypography.title(context),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.campusToolsEditHint,
                style: HyperosTypography.listDetail(context).copyWith(
                  color: HyperosColors.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String label, {
    String? hint,
  }) {
    final secondary = HyperosColors.secondaryText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HyperosTypography.listTitle(context)),
        if (hint != null && hint.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            hint,
            style: HyperosTypography.listDetail(context).copyWith(
              color: secondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIconPicker(BuildContext context) {
    final accent = HyperosColors.primary(context);
    final secondary = HyperosColors.secondaryText(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in kCampusToolIcons.entries)
          GestureDetector(
            onTap: () => setState(() => _icon = item.key),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.key == _icon
                    ? HyperosBlurredHeader.accentSurfaceTintColor(accent)
                    : HyperosColors.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.key == _icon
                      ? accent
                      : secondary.withValues(alpha: 0.24),
                  width: item.key == _icon ? 1.5 : 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                item.value,
                size: 22,
                color: item.key == _icon ? accent : secondary,
              ),
            ),
          ),
      ],
    );
  }
}
