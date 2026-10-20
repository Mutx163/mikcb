import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../domain/campus_tool_presets.dart';
import '../l10n/campus_tool_localizer.dart';
import '../models/campus_tool_entry.dart';
import '../services/campus_tool_runner.dart';
import '../services/campus_tools_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../widgets/campus_tool_edit_sheet.dart';
import '../widgets/campus_tool_icons.dart';

/// 校园小工具：一排可以自己添加快捷入口的按钮。
///
/// 用途是「把常用页面收成一排，一点直达」—— 取件身份码、待取快递、校园网
/// 认证这类页面通常埋在各自 App 的几层菜单里。跳转口径参考 QuickJump
/// （github.com/chuhe0719/QuickJump）：**先试直达 deeplink，再拉起官方 App，
/// 最后网页兜底**，每一条都能在长按编辑里随时改，三方 App 更新导致失效时
/// 用户自己就能修，不用等发版。
///
/// 状态全部由本页持有（不挂 Provider）：入口列表只有这一处消费，另起一个
/// Provider 只会增加启动期的装配面，没有任何跨页共享需求。
class CampusToolsScreen extends StatefulWidget {
  const CampusToolsScreen({super.key});

  @override
  State<CampusToolsScreen> createState() => _CampusToolsScreenState();
}

class _CampusToolsScreenState extends State<CampusToolsScreen> {
  List<CampusToolEntry> _entries = const <CampusToolEntry>[];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await CampusToolsService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _persist(List<CampusToolEntry> next) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _entries = List<CampusToolEntry>.unmodifiable(next);
    });
    final saved = await CampusToolsService.save(next);
    if (!mounted || saved) {
      return;
    }
    showAppToast(
      context,
      message: l10n.campusToolsSaveFailed,
      kind: AppToastKind.error,
    );
  }

  Future<void> _openEditor({CampusToolEntry? entry}) async {
    final result = await showCampusToolEditSheet(context: context, entry: entry);
    if (!mounted || result == null) {
      return;
    }
    final next = List<CampusToolEntry>.of(_entries);
    final index = next.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      next[index] = result;
    } else {
      next.add(result);
    }
    await _persist(next);
  }

  Future<void> _runEntry(CampusToolEntry entry) async {
    if (_busy || !entry.enabled) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final name = campusToolEntryTitle(l10n, entry);
    setState(() => _busy = true);
    final result = await CampusToolRunner.instance.run(entry);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    switch (result.status) {
      case CampusToolRunStatus.launched:
        // 直达成功：目标 App 已经切到前台，这里再弹任何东西都只会碍事。
        return;
      case CampusToolRunStatus.openedWeb:
        return;
      case CampusToolRunStatus.openedApp:
        showAppToast(
          context,
          message: l10n.campusToolsOpenedAppToast(name),
        );
        return;
      case CampusToolRunStatus.unsupported:
        showAppToast(
          context,
          message: l10n.campusToolsUnsupported,
          kind: AppToastKind.warning,
        );
        return;
      case CampusToolRunStatus.failed:
        showAppToast(
          context,
          message: l10n.campusToolsLaunchFailed(
            name,
            _reasonLabel(l10n, result.reason),
          ),
          kind: AppToastKind.error,
        );
        return;
    }
  }

  String _reasonLabel(AppLocalizations l10n, String? reason) {
    return switch (reason) {
      'no_activity' => l10n.campusToolsReasonNoActivity,
      'app_not_found' => l10n.campusToolsReasonAppNotFound,
      'invalid_uri' => l10n.campusToolsReasonInvalidUri,
      'invalid_package' => l10n.campusToolsReasonInvalidPackage,
      'timeout' => l10n.campusToolsReasonTimeout,
      'unsupported' => l10n.campusToolsReasonUnsupported,
      _ => l10n.campusToolsReasonUnknown,
    };
  }

  Future<void> _showEntryActions(CampusToolEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showHyperosDialog<String>(
      context: context,
      title: campusToolEntryTitle(l10n, entry),
      message: l10n.campusToolsTargetCount(entry.targetCount),
      actions: [
        HyperosDialogAction(
          label: l10n.campusToolsEditAction,
          onPressed: () => Navigator.pop(context, 'edit'),
        ),
        HyperosDialogAction(
          label: entry.enabled
              ? l10n.campusToolsDisableAction
              : l10n.campusToolsEnableAction,
          onPressed: () => Navigator.pop(context, 'toggle'),
        ),
        HyperosDialogAction(
          label: l10n.campusToolsDeleteAction,
          isDestructive: true,
          onPressed: () => Navigator.pop(context, 'delete'),
        ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'edit':
        await _openEditor(entry: entry);
      case 'toggle':
        await _persist(<CampusToolEntry>[
          for (final item in _entries)
            if (item.id == entry.id) item.copyWith(enabled: !item.enabled) else item,
        ]);
      case 'delete':
        await _confirmDelete(entry);
    }
  }

  Future<void> _confirmDelete(CampusToolEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final title = campusToolEntryTitle(l10n, entry);
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.campusToolsDeleteTitle,
      message: l10n.campusToolsDeleteBody(title),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.campusToolsDeleteAction,
      destructive: true,
    );
    if (!mounted || confirmed != true) {
      return;
    }
    await _persist(<CampusToolEntry>[
      for (final item in _entries)
        if (item.id != entry.id) item,
    ]);
  }

  Future<void> _restoreDefaults() async {
    final l10n = AppLocalizations.of(context)!;
    final before = _entries.length;
    final next = campusToolRestoreMissingPresets(_entries);
    if (next.length == before) {
      showAppToast(
        context,
        message: l10n.campusToolsRestoreDefaultsEmpty,
      );
      return;
    }
    await _persist(next);
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.campusToolsRestoreDefaultsToast(next.length - before),
      kind: AppToastKind.success,
    );
  }

  Future<void> _showMoreActions() async {
    final l10n = AppLocalizations.of(context)!;
    final supported = CampusToolRunner.instance.isSupported;
    final action = await showHyperosDialog<String>(
      context: context,
      title: l10n.campusToolsMoreTitle,
      actions: [
        if (supported)
          HyperosDialogAction(
            label: l10n.campusToolsDiagnoseAction,
            onPressed: () => Navigator.pop(context, 'diagnose'),
          ),
        HyperosDialogAction(
          label: l10n.campusToolsRestoreDefaults,
          onPressed: () => Navigator.pop(context, 'restore'),
        ),
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'diagnose':
        await _showDiagnostics();
      case 'restore':
        await _restoreDefaults();
    }
  }

  Future<void> _showDiagnostics() async {
    final l10n = AppLocalizations.of(context)!;
    final entries = _entries;
    setState(() => _busy = true);
    final probes = await Future.wait(<Future<CampusToolProbe>>[
      for (final entry in entries) CampusToolRunner.instance.probe(entry),
    ]);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    await showHyperosDialog<void>(
      context: context,
      title: l10n.campusToolsDiagnoseTitle,
      maxBodyHeightFactor: 0.6,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.campusToolsDiagnoseHint,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.secondaryText(context),
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < entries.length; index++)
              _buildProbeBlock(context, l10n, entries[index], probes[index]),
          ],
        ),
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.closeAction,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildProbeBlock(
    BuildContext context,
    AppLocalizations l10n,
    CampusToolEntry entry,
    CampusToolProbe probe,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campusToolEntryTitle(l10n, entry),
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          for (final link in probe.links)
            _buildProbeRow(context, link.text, link.ok),
          for (final item in probe.appInstalled.entries)
            _buildProbeRow(
              context,
              item.key,
              item.value,
              okLabel: item.value
                  ? l10n.campusToolsDiagnoseAppInstalled
                  : l10n.campusToolsDiagnoseAppMissing,
            ),
          if (probe.web != null)
            _buildProbeRow(context, probe.web!.text, probe.web!.ok),
        ],
      ),
    );
  }

  Widget _buildProbeRow(
    BuildContext context,
    String text,
    bool ok, {
    String? okLabel,
  }) {
    final color = ok
        ? HyperosColors.primary(context)
        : HyperosColors.error(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              okLabel == null ? text : '$text  ${okLabel.trim()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.secondaryText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = <CampusToolEntry>[
      for (final entry in _entries)
        if (entry.enabled) entry,
    ];
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.campusToolsTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.add_rounded),
          semanticsLabel: l10n.campusToolsAddAction,
          onPress: _openEditor,
        ),
        FHeaderAction(
          icon: const Icon(Icons.more_horiz_rounded),
          semanticsLabel: l10n.campusToolsMoreAction,
          onPress: _showMoreActions,
        ),
      ],
      child: HyperosListView(
        children: [
          Text(
            l10n.campusToolsIntro,
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.secondaryText(context),
            ),
          ),
          const HyperosSectionGap(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            HyperosEmptyState(
              title: l10n.campusToolsEmptyTitle,
              subtitle: l10n.campusToolsEmptySubtitle,
              icon: Icons.widgets_outlined,
              action: HyperosButton(
                label: l10n.campusToolsAddAction,
                onPressed: _openEditor,
              ),
            )
          else ...[
            _buildGridCard(context, visible),
            HyperosSectionDescription(text: l10n.campusToolsGridHint),
            const HyperosSectionGap(),
            HyperosSectionLabel(text: l10n.campusToolsManageTitle),
            HyperosListGroup(
              children: [
                for (final entry in _entries)
                  HyperosListTile(
                    icon: campusToolIconFor(entry.icon),
                    title: campusToolEntryTitle(l10n, entry),
                    details: entry.enabled
                        ? l10n.campusToolsTargetCount(entry.targetCount)
                        : l10n.campusToolsDisabledDetails,
                    onTap: () => _openEditor(entry: entry),
                    onLongPress: () => _showEntryActions(entry),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    List<CampusToolEntry> visible,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final secondary = HyperosColors.secondaryText(context);
    return HyperosCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final entry in visible)
            _CampusToolTile(
              title: campusToolEntryTitle(l10n, entry),
              icon: campusToolIconFor(entry.icon),
              onTap: () => _runEntry(entry),
              onLongPress: () => _showEntryActions(entry),
            ),
          _CampusToolTile(
            title: l10n.campusToolsAddTile,
            icon: Icons.add_rounded,
            onTap: _openEditor,
            onLongPress: _openEditor,
            isAdd: true,
          ),
          if (_busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: secondary),
            ),
        ],
      ),
    );
  }
}

/// 一颗快捷按钮：46dp 图标砖 + 一行标题，尺寸对齐八宫格编辑器的预览砖。
class _CampusToolTile extends StatelessWidget {
  const _CampusToolTile({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.onLongPress,
    this.isAdd = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isAdd;

  @override
  Widget build(BuildContext context) {
    final accent = HyperosColors.primary(context);
    final secondary = HyperosColors.secondaryText(context);
    return SizedBox(
      width: 72,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isAdd
                    ? secondary.withValues(alpha: 0.12)
                    : HyperosBlurredHeader.accentSurfaceTintColor(accent),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 24, color: isAdd ? secondary : accent),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context),
            ),
          ],
        ),
      ),
    );
  }
}
