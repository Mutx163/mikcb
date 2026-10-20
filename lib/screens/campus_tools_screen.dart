import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';

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

  /// 进页面时批量查到的已安装包名；null = 还没查完 / 查不到（不弱化任何格子）。
  Set<String>? _installedPackages;

  @override
  void initState() {
    super.initState();
    _loadInstalledPackages();
  }

  /// 批量查「兜底应用装没装」，用来把没装的入口在视觉上弱化。
  ///
  /// 只为「预判」服务：查不到（非 Android / 通道异常）就保持 null，运行时
  /// 仍会逐个试，功能不受影响。
  Future<void> _loadInstalledPackages() async {
    final installed = await CampusToolRunner.instance.installedPackages(
      campusToolAllPackages(),
    );
    if (!mounted || installed == null) {
      return;
    }
    setState(() => _installedPackages = installed);
  }

  Future<void> _openEntry(CampusToolEntry entry) async {
    if (_busyEntryId != null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final title = campusToolEntryTitle(l10n, entry);
    // 点下即反馈：站柜子前不一定看着屏幕，手感比进度圈更早到。
    _vibrate();
    setState(() => _busyEntryId = entry.id);
    final result = await CampusToolRunner.instance.run(
      entry,
      alreadyInstalled: _installedPackages,
    );
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
          description: l10n.campusToolsLaunchFailedHint,
          kind: AppToastKind.error,
        );
        return;
    }
  }

  /// 触觉反馈：跟随设置里的「震动反馈」开关（与切课表、点空白格同一条口径）。
  void _vibrate() {
    final provider = context.read<TimetableProvider?>();
    if (provider?.settings.enableHaptics ?? true) {
      HapticFeedback.selectionClick();
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
          _CampusToolGrid(
            entries: identityCodes,
            busyEntryId: _busyEntryId,
            installedPackages: _installedPackages,
            onTap: _openEntry,
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.campusToolsParcelsSectionTitle),
          _CampusToolGrid(
            entries: parcels,
            busyEntryId: _busyEntryId,
            installedPackages: _installedPackages,
            onTap: _openEntry,
          ),
        ],
      ),
    );
  }
}

/// 一组入口：四列等宽方格。
///
/// **两组都按四列**：身份码组 3 个、待取组 4 个，若各自按「有几个分几列」，
/// 两组格子宽度会差 30%（103dp vs 75dp），下面那行看起来像被挤扁。固定
/// 四列后两组格子一样大，视觉上是一套东西；不足一行用空位补齐。
///
/// 为什么是方格而不是横条：砖上只写平台名（两三个字），横条那套
/// 「图标 + 标题 + 副标题 + 箭头」会留一大片空白，七个平台竖排要滑两次。
class _CampusToolGrid extends StatelessWidget {
  const _CampusToolGrid({
    required this.entries,
    required this.busyEntryId,
    required this.installedPackages,
    required this.onTap,
  });

  /// 每行固定四列。
  static const int _columns = 4;

  final List<CampusToolEntry> entries;
  final String? busyEntryId;

  /// 已安装的包名；null = 还没查出来（全部按可用显示）。
  final Set<String>? installedPackages;

  final ValueChanged<CampusToolEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];
    for (var start = 0; start < entries.length; start += _columns) {
      final chunk = entries.sublist(
        start,
        (start + _columns).clamp(0, entries.length),
      );
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < _columns; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: index < chunk.length
                    ? _CampusToolTile(
                        entry: chunk[index],
                        title: campusToolEntryTitle(l10n, chunk[index]),
                        busy: busyEntryId == chunk[index].id,
                        dimmed:
                            busyEntryId != null && busyEntryId != chunk[index].id,
                        missing: _isMissing(chunk[index]),
                        onTap: () => onTap(chunk[index]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (start + _columns < entries.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  /// 这条入口的兜底应用一个都没装 → 点了也没用，砖上要弱化。
  bool _isMissing(CampusToolEntry entry) {
    final installed = installedPackages;
    if (installed == null || entry.appPackages.isEmpty) {
      return false;
    }
    return !entry.appPackages.any(installed.contains);
  }
}

/// 一颗入口砖：首字图标 + 平台名。整块可点。
///
/// ## 为什么图标用「平台首字」而不是 Material 图标
///
/// 四家平台在 Material 图标集里只有近似的购物袋 / 二维码，靠颜色区分——而淘宝
/// 红、拼多多红、菜鸟橙都是红橙色系，三个一样的二维码图标排在一起扫一眼分不
/// 出来。改成「菜 / 淘 / 拼 / 京 / 抖」单字方块：字本身就能区分平台，颜色只做
/// 辅助，深色模式下也不失辨识度。
///
/// ## 状态
/// - `busy`：正在跳转，图标位置换成进度圈
/// - `dimmed`：别的砖在跳转，这一块淡下去
/// - `missing`：兜底应用一个都没装，整块降为 55% 并加一行「未安装」角标
class _CampusToolTile extends StatelessWidget {
  const _CampusToolTile({
    required this.entry,
    required this.title,
    required this.busy,
    required this.dimmed,
    required this.missing,
    required this.onTap,
  });

  final CampusToolEntry entry;
  final String title;
  final bool busy;
  final bool dimmed;
  final bool missing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = campusToolAccentFor(context, entry.id);
    final primaryText = HyperosColors.primaryText(context);
    final groupLabel = campusToolIsIdentityCode(entry.icon)
        ? l10n.campusToolsIdentitySectionTitle
        : l10n.campusToolsParcelsSectionTitle;
    // 读屏时把「分组 + 平台 + 状态」一次说清：只听「菜鸟 按钮」不知道点下去
    // 是出示码还是查包裹。
    final semanticsLabel = missing
        ? '${l10n.campusToolsSemanticsEntry(title, groupLabel)}，'
              '${l10n.campusToolsSemanticsNotInstalled}'
        : l10n.campusToolsSemanticsEntry(title, groupLabel);
    return AnimatedOpacity(
      duration: 150.scaledMs,
      opacity: dimmed ? 0.45 : (missing ? 0.55 : 1),
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: Material(
          color: HyperosColors.card(context),
          shape: const MiuixSquircleBorder(
            cornerRadius: MiuixCardDefaults.cornerRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: busy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: accent,
                              ),
                            )
                          : _CampusToolGlyph(
                              title: title,
                              accent: accent,
                              missing: missing,
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
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
      ),
    );
  }
}

/// 平台首字方块：品牌色淡底 + 品牌色首字。
///
/// 取首字而不是字母缩写：中文环境下「菜」「淘」「拼」「京」「抖」一眼可认，
/// 而 CJK 里取 `characters.first` 才能正确切（emoji / 组合字符不会被劈开）。
class _CampusToolGlyph extends StatelessWidget {
  const _CampusToolGlyph({
    required this.title,
    required this.accent,
    required this.missing,
  });

  final String title;
  final Color accent;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final glyph = title.characters.isEmpty ? '?' : title.characters.first;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: HyperosBlurredHeader.accentSurfaceTintColor(accent),
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Text(
        glyph,
        style: HyperosTypography.listTitle(context).copyWith(
          color: accent,
          height: 1,
          decoration: missing ? TextDecoration.lineThrough : null,
          decorationColor: accent,
        ),
      ),
    );
  }
}
