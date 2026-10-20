import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
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

/// 整页两栏网格：两组入口 + 自适应砖高，把可用高度吃满。
///
/// ## 砖高怎么算
///
/// 这一页只有 7 个入口，内容天生很短；按内容排，大屏上底部会空掉小半屏
/// （实测 360×640 只占 344dp）。砖高改为**按剩余空间均分**：
/// 可用高度 = 页面高 − 顶栏展开高度（HyperosBlurredHeaderScope）−
/// 两个分组标题 − 行间距 − 玻璃坞底部余量（GlassDockScrollReliefScope）。
/// 屏幕越高砖越大越好按；夹在 [minTileHeight, maxTileHeight] 之间防变形。
///
/// ## 滚动为什么必须交给 HyperosListView
///
/// 上一版用裸 SingleChildScrollView + 手工顶部留白（状态栏 + 26dp），
/// 漏算了可折叠大标题那层——真机截图里首行砖被标题盖住、首字井全被切掉。
/// HyperosListView 自己读 HyperosBlurredHeaderScope 的头部 inset、
/// GlassDockScrollReliefScope 的底部余量与 overscroll 物理，**不许绕开它手算**。
///
/// ## 两列 + 奇数末砖跨两列
///
/// 四列时砖只有 75dp 宽，撑不起「首字 + 名字 + 说明」；两列是大按钮。
/// 身份码组只有 3 个：2×2 会右下角空一块，所以**每组的末行若只有一砖，
/// 让它横跨两列**（bento 常见手法，视觉上是刻意的满铺而不是缺格）。
class _PickupCodePanel extends StatelessWidget {
  const _PickupCodePanel({
    required this.identityCodes,
    required this.parcels,
    required this.busyEntryId,
    required this.installedPackages,
    required this.maxHeight,
    required this.onTap,
  });

  /// 每行两列。
  static const int columns = 2;

  /// 砖高下限：低于这个值就不像按钮了。
  static const double minTileHeight = 104;

  /// 砖高上限：平板上再高就变形，多出来的空间留给底部留白。
  static const double maxTileHeight = 168;

  /// 组内行间距。
  static const double _rowGap = 10;

  /// 分组标题占位（HyperosSectionLabel：文字行高 + 自带 8dp 下边距）。
  static const double _sectionLabelHeight = 30;

  final List<PickupCodeEntry> identityCodes;
  final List<PickupCodeEntry> parcels;
  final String? busyEntryId;
  final Set<String>? installedPackages;
  final double maxHeight;
  final ValueChanged<PickupCodeEntry> onTap;

  int get _identityRows => (identityCodes.length / columns).ceil();

  int get _parcelsRows => (parcels.length / columns).ceil();

  int get _totalRows => _identityRows + _parcelsRows;

  /// 按剩余空间算砖高；夹在上下限之间。
  ///
  /// 头部与底部留白**从 scope 读**（大标题展开高度、玻璃坞余量都会变），
  /// 不手算状态栏 / 标题高度 —— 上一版就是手算漏层才把首行顶进标题底下。
  double _resolveTileHeight(BuildContext context) {
    final headerInset = HyperosBlurredHeaderScope.insetOf(context);
    final dockRelief = GlassDockScrollReliefScope.insetOf(context);
    final reserved = headerInset +
        dockRelief +
        _sectionLabelHeight * 2 +
        _rowGap * (_totalRows + 1) +
        24; // 列表左右内边距对应的上下呼吸（对齐 HyperosTokens.listPadding）
    final available = maxHeight - reserved;
    final perTile = available / (_totalRows == 0 ? 1 : _totalRows);
    return perTile.clamp(minTileHeight, maxTileHeight);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tileHeight = _resolveTileHeight(context);
    return HyperosListView(
      children: [
        HyperosSectionLabel(text: l10n.pickupCodeIdentitySectionTitle),
        _buildGrid(context, identityCodes, tileHeight),
        const SizedBox(height: _rowGap * 2),
        HyperosSectionLabel(text: l10n.pickupCodeParcelsSectionTitle),
        _buildGrid(context, parcels, tileHeight),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<PickupCodeEntry> entries,
    double tileHeight,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];
    for (var start = 0; start < entries.length; start += columns) {
      final chunk = entries.sublist(
        start,
        (start + columns).clamp(0, entries.length),
      );
      if (chunk.length == 1) {
        // 末行只有一砖：横跨两列满铺，不留出右下角的洞。
        rows.add(
          SizedBox(
            height: tileHeight,
            child: _PickupCodeTile(
              entry: chunk.first,
              title: pickupCodeEntryTitle(l10n, chunk.first),
              subtitle: pickupCodeEntryHint(l10n, chunk.first),
              busy: busyEntryId == chunk.first.id,
              dimmed: busyEntryId != null && busyEntryId != chunk.first.id,
              missing: _isMissing(chunk.first),
              onTap: () => onTap(chunk.first),
            ),
          ),
        );
      } else {
        rows.add(
          SizedBox(
            height: tileHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < columns; index++) ...[
                  if (index > 0) const SizedBox(width: _rowGap),
                  Expanded(
                    child: _PickupCodeTile(
                      entry: chunk[index],
                      title: pickupCodeEntryTitle(l10n, chunk[index]),
                      subtitle: pickupCodeEntryHint(l10n, chunk[index]),
                      busy: busyEntryId == chunk[index].id,
                      dimmed:
                          busyEntryId != null && busyEntryId != chunk[index].id,
                      missing: _isMissing(chunk[index]),
                      onTap: () => onTap(chunk[index]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      if (start + columns < entries.length) {
        rows.add(const SizedBox(height: _rowGap));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  /// 这条入口的兜底应用一个都没装 → 点了也没用，砖上要弱化。
  bool _isMissing(PickupCodeEntry entry) {
    final installed = installedPackages;
    if (installed == null || entry.appPackages.isEmpty) {
      return false;
    }
    return !entry.appPackages.any(installed.contains);
  }
}

/// 一颗入口砖（两列大卡）：首字 + 平台名 + 一行动作说明。整块可点。
///
/// ## 为什么图标用「平台首字」而不是 Material 图标
///
/// 四家平台在 Material 图标集里只有近似的购物袋 / 二维码，靠颜色区分——而淘宝
/// 红、拼多多红、菜鸟橙都是红橙色系，三个一样的二维码图标排在一起扫一眼分不
/// 出来。改成「菜 / 淘 / 拼 / 京 / 抖」单字方块：字本身就能区分平台，颜色只做
/// 辅助，深色模式下也不失辨识度。
///
/// ## [subtitle] 必须是**新信息**
///
/// 砖上已经有「平台名 + 分组标题」两层，subtitle 若再写「打开取件码」就是同一
/// 句话第三遍（用户点过名：灰字太多不简洁）。所以这里只放「这个平台跳过去
/// 具体到哪」——驿站自提 / 快递柜 / 商城订单——选哪个码的信息，删掉任何一层
/// 用户都要猜。
///
/// ## 状态
/// - `busy`：正在跳转，图标位置换成进度圈
/// - `dimmed`：别的砖在跳转，这一块淡下去
/// - `missing`：兜底应用一个都没装，整块降为 55% 并加一行「未安装」角标
class _PickupCodeTile extends StatelessWidget {
  const _PickupCodeTile({
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
        child: Material(
          color: HyperosColors.card(context),
          shape: const MiuixSquircleBorder(
            cornerRadius: MiuixCardDefaults.cornerRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 首字井：跳转时换成进度圈（居中保持同一占位）。
                  SizedBox(
                    width: 44,
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
                          : _PickupCodeGlyph(
                              title: title,
                              accent: accent,
                              missing: missing,
                            ),
                    ),
                  ),
                  const Spacer(),
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
                    ).copyWith(
                      color: secondaryText,
                    ),
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
