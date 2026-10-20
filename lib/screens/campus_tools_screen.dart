import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../domain/campus_tool_presets.dart';
import '../l10n/campus_tool_localizer.dart';
import '../models/campus_tool_entry.dart';
import '../services/campus_tool_runner.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../utils/app_toast.dart';
import '../widgets/campus_tool_icons.dart';

/// 校园小工具：一排固定的取件快捷入口，点一下直达。
///
/// ## 这个页面是什么
///
/// 取件身份码、待取快递这几页在各自 App 里都埋得很深（淘宝要点「我的 → 我的
/// 快递 → 待取件 → 身份码」好几层）。本页把它们收成固定的一排，点一下就出示
/// 码。跳转口径参考 QuickJump（github.com/chuhe0719/QuickJump）：先试直达
/// deeplink，再拉起官方 App，最后网页兜底。
///
/// ## 为什么是固定内容、不做自定义
///
/// 这是「工具页」不是「配置页」：用户来这里是执行（人在快递柜前，要立刻出示
/// 码），不是编辑。所以入口表写死在 domain/campus_tool_presets.dart，页面上
/// 没有添加 / 删除 / 排序 / 改名 —— 那些能力会把一个 2 秒的动作变成「先理解
/// 数据结构」的事。链接失效的兜底靠多级回退（直达失败自动降级到打开 App），
/// 而不是靠用户自己改链接。
///
/// 状态极其简单：没有持久化、没有 Provider，只有一个「哪条正在跳」的瞬时态。
class CampusToolsScreen extends StatefulWidget {
  const CampusToolsScreen({super.key});

  @override
  State<CampusToolsScreen> createState() => _CampusToolsScreenState();
}

class _CampusToolsScreenState extends State<CampusToolsScreen> {
  /// 正在跳转的入口 id（防连点，并给那一条画进度）。
  String? _busyEntryId;

  Future<void> _openEntry(CampusToolEntry entry) async {
    if (_busyEntryId != null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final title = campusToolEntryTitle(l10n, entry);
    setState(() => _busyEntryId = entry.id);
    final result = await CampusToolRunner.instance.run(entry);
    if (!mounted) {
      return;
    }
    setState(() => _busyEntryId = null);
    switch (result.status) {
      case CampusToolRunStatus.launched:
        // 直达成功：目标 App 已切到前台，这里再弹任何东西都只会碍事。
        return;
      case CampusToolRunStatus.openedWeb:
        return;
      case CampusToolRunStatus.openedApp:
        showAppToast(context, message: l10n.campusToolsOpenedAppToast(title));
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
            title,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final identityCodes = <CampusToolEntry>[
      for (final entry in kCampusToolPresets)
        if (campusToolIsIdentityCode(entry.icon)) entry,
    ];
    final parcels = <CampusToolEntry>[
      for (final entry in kCampusToolPresets)
        if (!campusToolIsIdentityCode(entry.icon)) entry,
    ];
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.campusToolsTitle),
      child: HyperosListView(
        children: [
          // 两组之间不写任何说明文字：分组标题已经把「这一组点下去干什么」
          // 说清了，每条下面只有平台名。
          HyperosSectionLabel(text: l10n.campusToolsIdentitySectionTitle),
          const SizedBox(height: 10),
          _CampusToolGrid(
            entries: identityCodes,
            busyEntryId: _busyEntryId,
            onTap: _openEntry,
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.campusToolsParcelsSectionTitle),
          const SizedBox(height: 10),
          _CampusToolGrid(
            entries: parcels,
            busyEntryId: _busyEntryId,
            onTap: _openEntry,
          ),
        ],
      ),
    );
  }
}

/// 一组入口：等宽方格，一行放三个。
///
/// 为什么是方格而不是横条：每条下面只写平台名（两三个字），横条那套
/// 「图标 + 标题 + 副标题 + 箭头」会留一大片空白，而且七个平台竖排下来要滑两次。
/// 方格一屏就能看完两组，拇指活动范围也小 —— 站快递柜前单手操作更省事。
class _CampusToolGrid extends StatelessWidget {
  const _CampusToolGrid({
    required this.entries,
    required this.busyEntryId,
    required this.onTap,
  });

  final List<CampusToolEntry> entries;
  final String? busyEntryId;
  final ValueChanged<CampusToolEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: _CampusToolTile(
              entry: entries[index],
              title: campusToolEntryTitle(l10n, entries[index]),
              busy: busyEntryId == entries[index].id,
              dimmed: busyEntryId != null && busyEntryId != entries[index].id,
              onTap: () => onTap(entries[index]),
            ),
          ),
        ],
        // 不满一行时补空位，避免剩下的格子被拉伸得比上面一行宽。
        for (var index = entries.length; index < 3; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          const Expanded(child: SizedBox.shrink()),
        ],
      ],
    );
  }
}

/// 一颗入口砖：品牌色图标井 + 平台名。整块可点，最小 84×92dp。
///
/// 没有副标题、没有箭头：分组标题已经说明这一组干什么，砖上写平台名就够。
class _CampusToolTile extends StatelessWidget {
  const _CampusToolTile({
    required this.entry,
    required this.title,
    required this.busy,
    required this.dimmed,
    required this.onTap,
  });

  final CampusToolEntry entry;
  final String title;
  final bool busy;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = campusToolAccentFor(context, entry.id);
    final primaryText = HyperosColors.primaryText(context);
    return AnimatedOpacity(
      duration: 150.scaledMs,
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: HyperosColors.card(context),
        shape: const MiuixSquircleBorder(
          cornerRadius: MiuixCardDefaults.cornerRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: accent,
                            ),
                          )
                        : _CampusToolIconWell(
                            iconName: entry.icon,
                            accent: accent,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: HyperosTypography.listDetail(
                    context,
                  ).copyWith(color: primaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 图标井：品牌色 12% 淡底 + 品牌色图形，与八宫格预览砖同一口径
/// （HyperosBlurredHeader.accentSurfaceTintColor）。
class _CampusToolIconWell extends StatelessWidget {
  const _CampusToolIconWell({required this.iconName, required this.accent});

  final String iconName;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: HyperosBlurredHeader.accentSurfaceTintColor(accent),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(campusToolIconFor(iconName), size: 24, color: accent),
    );
  }
}
