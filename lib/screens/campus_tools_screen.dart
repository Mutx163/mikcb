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
          Text(
            l10n.campusToolsIntro,
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.secondaryText(context),
              height: 1.5,
            ),
          ),
          const HyperosSectionGap(),
          // 身份码区：最常用、最急，放最上面。
          _CampusToolSectionHeader(
            title: l10n.campusToolsIdentitySectionTitle,
            subtitle: l10n.campusToolsIdentitySectionHint,
          ),
          const SizedBox(height: 8),
          for (final entry in identityCodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CampusToolCard(
                entry: entry,
                title: campusToolEntryTitle(l10n, entry),
                subtitle: l10n.campusToolsIdentitySubtitle,
                busy: _busyEntryId == entry.id,
                dimmed: _busyEntryId != null && _busyEntryId != entry.id,
                onTap: () => _openEntry(entry),
              ),
            ),
          const HyperosSectionGap(),
          _CampusToolSectionHeader(
            title: l10n.campusToolsParcelsSectionTitle,
            subtitle: l10n.campusToolsParcelsSectionHint,
          ),
          const SizedBox(height: 8),
          for (final entry in parcels)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CampusToolCard(
                entry: entry,
                title: campusToolEntryTitle(l10n, entry),
                subtitle: l10n.campusToolsParcelsSubtitle,
                busy: _busyEntryId == entry.id,
                dimmed: _busyEntryId != null && _busyEntryId != entry.id,
                onTap: () => _openEntry(entry),
              ),
            ),
          const HyperosSectionGap(),
          HyperosSectionDescription(text: l10n.campusToolsFooterHint),
        ],
      ),
    );
  }
}

/// 分区标题：一行标题 + 一行灰字说明，说明这一组点下去会看到什么。
class _CampusToolSectionHeader extends StatelessWidget {
  const _CampusToolSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: HyperosTypography.sectionLabel(context).copyWith(
            color: HyperosColors.primaryText(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.secondaryText(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// 一条入口横条：左侧品牌色图标井 + 平台名 + 功能说明 + 右侧箭头。
///
/// 为什么是横条而不是方格：方格（图标 + 下面一行小字）适合一眼扫，但这里每条
/// 入口都要说清「这是身份码还是查包裹」，方格塞不下一行说明；横条能在一次扫视
/// 里给出「平台 + 功能」两个信息，而且整行都是热区（48dp 以上），在快递柜前
/// 手忙脚乱时更好按。
class _CampusToolCard extends StatelessWidget {
  const _CampusToolCard({
    required this.entry,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.dimmed,
    required this.onTap,
  });

  final CampusToolEntry entry;
  final String title;
  final String subtitle;
  final bool busy;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = campusToolAccentFor(context, entry.id);
    final primaryText = HyperosColors.primaryText(context);
    final secondaryText = HyperosColors.secondaryText(context);
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
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                _CampusToolIconWell(iconName: entry.icon, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HyperosTypography.listTitle(
                          context,
                        ).copyWith(color: primaryText),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HyperosTypography.listDetail(
                          context,
                        ).copyWith(color: secondaryText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: secondaryText.withValues(alpha: 0.5),
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: HyperosBlurredHeader.accentSurfaceTintColor(accent),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(campusToolIconFor(iconName), size: 22, color: accent),
    );
  }
}
