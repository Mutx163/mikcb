import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';

import '../domain/pickup_code_presets.dart';
import '../l10n/pickup_code_localizer.dart';
import '../models/pickup_code_entry.dart';
import '../services/pickup_code_runner.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../utils/app_toast.dart';
import '../widgets/pickup_code_icons.dart';

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
/// 码），不是编辑。所以入口表写死在 domain/pickup_code_presets.dart，页面上
/// 没有添加 / 删除 / 排序 / 改名 —— 那些能力会把一个 2 秒的动作变成「先理解
/// 数据结构」的事。链接失效的兜底靠多级回退（直达失败自动降级到打开 App），
/// 而不是靠用户自己改链接。
///
/// 状态极其简单：没有持久化、没有 Provider，只有一个「哪条正在跳」的瞬时态。
class PickupCodesScreen extends StatefulWidget {
  const PickupCodesScreen({super.key});

  @override
  State<PickupCodesScreen> createState() => _PickupCodesScreenState();
}

class _PickupCodesScreenState extends State<PickupCodesScreen> {
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
    final installed = await PickupCodeRunner.instance.installedPackages(
      pickupCodeAllPackages(),
    );
    if (!mounted || installed == null) {
      return;
    }
    setState(() => _installedPackages = installed);
  }

  Future<void> _openEntry(PickupCodeEntry entry) async {
    if (_busyEntryId != null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final title = pickupCodeEntryTitle(l10n, entry);
    // 点下即反馈：站柜子前不一定看着屏幕，手感比进度圈更早到。
    _vibrate();
    setState(() => _busyEntryId = entry.id);
    final result = await PickupCodeRunner.instance.run(
      entry,
      alreadyInstalled: _installedPackages,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busyEntryId = null);
    switch (result.status) {
      case PickupCodeRunStatus.launched:
        // 直达成功：目标 App 已切到前台，这里再弹任何东西都只会碍事。
        return;
      case PickupCodeRunStatus.openedWeb:
        return;
      case PickupCodeRunStatus.openedApp:
        showAppToast(context, message: l10n.pickupCodeOpenedAppToast(title));
        return;
      case PickupCodeRunStatus.unsupported:
        showAppToast(
          context,
          message: l10n.pickupCodeUnsupported,
          kind: AppToastKind.warning,
        );
        return;
      case PickupCodeRunStatus.failed:
        showAppToast(
          context,
          message: l10n.pickupCodeLaunchFailed(
            title,
            _reasonLabel(l10n, result.reason),
          ),
          description: l10n.pickupCodeLaunchFailedHint,
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
      'no_activity' => l10n.pickupCodeReasonNoActivity,
      'app_not_found' => l10n.pickupCodeReasonAppNotFound,
      'invalid_uri' => l10n.pickupCodeReasonInvalidUri,
      'invalid_package' => l10n.pickupCodeReasonInvalidPackage,
      'timeout' => l10n.pickupCodeReasonTimeout,
      'unsupported' => l10n.pickupCodeReasonUnsupported,
      _ => l10n.pickupCodeReasonUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final identityCodes = <PickupCodeEntry>[
      for (final entry in kPickupCodePresets)
        if (pickupCodeIsIdentityCode(entry.icon)) entry,
    ];
    final parcels = <PickupCodeEntry>[
      for (final entry in kPickupCodePresets)
        if (!pickupCodeIsIdentityCode(entry.icon)) entry,
    ];
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.pickupCodeTitle),
      // 砖高按可用高度分配（见 _PickupCodePanel），滚动仍交给
      // HyperosListView —— 它自己处理大标题留白与玻璃坞底部余量。
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _PickupCodePanel(
            identityCodes: identityCodes,
            parcels: parcels,
            busyEntryId: _busyEntryId,
            installedPackages: _installedPackages,
            maxHeight: constraints.maxHeight,
            onTap: _openEntry,
          );
        },
      ),
    );
  }
}

/// 整页两组入口，每组一张卡片、每行一条横条。
///
/// ## 为什么不是网格
///
/// 7 个入口排两列必然有奇偶问题：末行单砖要么留个洞，要么横跨两列——而跨列
/// 会让那一块看起来比其他块重要得多（用户原话：「显得你把拼多多放得比其他
/// 重要多了」）。横条列表没有这个矛盾：7 条就是 7 行，谁都不特殊，也永远
/// 不会有空格。整行都是热区，手忙脚乱时更好按。
///
/// ## 行高怎么定
///
/// 这一页内容天生短，按自然高度排在 640dp 屏上会空掉小半屏。行高**按剩余空间
/// 均分**：可用高度 = 页面高 − 大标题展开高度（HyperosBlurredHeaderScope）−
/// 分组标题 − 行间距 − 玻璃坞底部余量（GlassDockScrollReliefScope）− 卡片内
/// 边距。屏幕越高行越厚越好按；夹在 [minRowHeight, maxRowHeight] 之间防变形。
///
/// ## 滚动为什么交给 HyperosListView
///
/// 早期版本用裸 SingleChildScrollView + 手算顶部留白，漏算了可折叠大标题那层，
/// 真机截图里首行被标题盖住。HyperosListView 自己读头部 inset、玻璃坞余量与
/// overscroll 物理，**不许绕开它手算**。
class _PickupCodePanel extends StatelessWidget {
  const _PickupCodePanel({
    required this.identityCodes,
    required this.parcels,
    required this.busyEntryId,
    required this.installedPackages,
    required this.maxHeight,
    required this.onTap,
  });

  /// 行高下限：低于这个值就不像一条能点的行。
  static const double minRowHeight = 64;

  /// 行高上限：平板上再厚就变形，多出来的空间留给底部。
  static const double maxRowHeight = 96;

  /// 两组之间的间距。
  static const double _groupGap = 16;

  /// 分组标题占位（HyperosSectionLabel：文字行高 + 自带 8dp 下边距）。
  static const double _sectionLabelHeight = 30;

  /// 卡片内上下边距（见 _buildGroup 的 padding）。
  static const double _cardVerticalPadding = 8;

  final List<PickupCodeEntry> identityCodes;
  final List<PickupCodeEntry> parcels;
  final String? busyEntryId;
  final Set<String>? installedPackages;
  final double maxHeight;
  final ValueChanged<PickupCodeEntry> onTap;

  int get _totalRows => identityCodes.length + parcels.length;

  /// 按剩余空间算行高；夹在上下限之间。
  ///
  /// 头部与底部留白**从 scope 读**（大标题展开高度、玻璃坞余量都是动态的），
  /// 不手算状态栏 / 标题高度 —— 早期手算漏层才把首行顶进标题底下。
  double _resolveRowHeight(BuildContext context) {
    final headerInset = HyperosBlurredHeaderScope.insetOf(context);
    final dockRelief = GlassDockScrollReliefScope.insetOf(context);
    final reserved = headerInset +
        dockRelief +
        _sectionLabelHeight * 2 +
        _groupGap +
        _cardVerticalPadding * 2 +
        24;
    final available = maxHeight - reserved;
    final perRow = available / (_totalRows == 0 ? 1 : _totalRows);
    return perRow.clamp(minRowHeight, maxRowHeight);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rowHeight = _resolveRowHeight(context);
    return HyperosListView(
      children: [
        HyperosSectionLabel(text: l10n.pickupCodeIdentitySectionTitle),
        _buildGroup(context, identityCodes, rowHeight),
        const SizedBox(height: _groupGap),
        HyperosSectionLabel(text: l10n.pickupCodeParcelsSectionTitle),
        _buildGroup(context, parcels, rowHeight),
      ],
    );
  }

  /// 一组入口：一张卡片，行与行之间用缩进分隔线（与设置页列表同口径）。
  Widget _buildGroup(
    BuildContext context,
    List<PickupCodeEntry> entries,
    double rowHeight,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[];
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (index > 0) {
        children.add(
          const HyperosInsetDivider(indent: 68),
        );
      }
      children.add(
        SizedBox(
          height: rowHeight,
          child: _PickupCodeRow(
            entry: entry,
            title: pickupCodeEntryTitle(l10n, entry),
            subtitle: pickupCodeEntryHint(l10n, entry),
            busy: busyEntryId == entry.id,
            dimmed: busyEntryId != null && busyEntryId != entry.id,
            missing: _isMissing(entry),
            onTap: () => onTap(entry),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _cardVerticalPadding),
      child: HyperosListGroup(children: children),
    );
  }

  /// 这条入口的兜底应用一个都没装 → 点了也没用，行上要弱化。
  bool _isMissing(PickupCodeEntry entry) {
    final installed = installedPackages;
    if (installed == null || entry.appPackages.isEmpty) {
      return false;
    }
    return !entry.appPackages.any(installed.contains);
  }
}

/// 一条入口横条：左侧首字井 + 平台名 + 一行动作说明 + 右侧箭头。整行可点。
///
/// ## 为什么图标用「平台首字」而不是 Material 图标
///
/// 几家平台在 Material 图标集里只有近似的购物袋 / 二维码，靠颜色区分——而淘宝
/// 红、拼多多红、菜鸟橙都是红橙色系，三个一样的图标排在一起扫一眼分不出来。
/// 改成「菜 / 淘 / 拼 / 京 / 抖」单字方块：字本身就能区分平台，颜色只做辅助，
/// 深色模式下也不失辨识度。
///
/// ## [subtitle] 必须是**新信息**
///
/// 行上已经有「平台名 + 分组标题」两层，subtitle 若再写「打开取件码」就是同一
/// 句话第三遍（用户明确说过灰字太多不简洁）。所以这里只放「这个平台跳过去
/// 具体到哪」——驿站自提 / 快递柜 / 某平台的包裹列表——帮用户在几条之间选。
///
/// ## 状态
/// - `busy`：正在跳转，首字井位置换成进度圈
/// - `dimmed`：别的行在跳转，这一条淡下去
/// - `missing`：兜底应用一个都没装，整条降为 55%、首字加删除线
class _PickupCodeRow extends StatelessWidget {
  const _PickupCodeRow({
    required this.entry,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.dimmed,
    required this.missing,
    required this.onTap,
  });

  final PickupCodeEntry entry;
  final String title;
  final String subtitle;
  final bool busy;
  final bool dimmed;
  final bool missing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = pickupCodeAccentFor(context, entry.id);
    final primaryText = HyperosColors.primaryText(context);
    final secondaryText = HyperosColors.secondaryText(context);
    final groupLabel = pickupCodeIsIdentityCode(entry.icon)
        ? l10n.pickupCodeIdentitySectionTitle
        : l10n.pickupCodeParcelsSectionTitle;
    // 读屏时把「分组 + 平台 + 状态」一次说清：只听「菜鸟 按钮」不知道点下去
    // 是出示码还是查包裹。
    final semanticsLabel = missing
        ? '${l10n.pickupCodeSemanticsEntry(title, groupLabel)}，'
              '${l10n.pickupCodeSemanticsNotInstalled}'
        : l10n.pickupCodeSemanticsEntry(title, groupLabel);
    return AnimatedOpacity(
      duration: 150.scaledMs,
      opacity: dimmed ? 0.45 : (missing ? 0.55 : 1),
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 首字井：跳转时换成进度圈（同尺寸占位，整行不跳）。
                SizedBox(
                  width: 40,
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
                        : _PickupCodeGlyph(
                            title: title,
                            accent: accent,
                            missing: missing,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HyperosTypography.listTitle(
                          context,
                        ).copyWith(color: primaryText),
                      ),
                      const SizedBox(height: 2),
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

/// 平台首字方块：品牌色淡底 + 品牌色首字。
///
/// 取首字而不是字母缩写：中文环境下「菜」「淘」「拼」「京」「抖」一眼可认，
/// 而 CJK 里取 `characters.first` 才能正确切（emoji / 组合字符不会被劈开）。
class _PickupCodeGlyph extends StatelessWidget {
  const _PickupCodeGlyph({
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
