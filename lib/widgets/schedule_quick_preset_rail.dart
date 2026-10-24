import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../domain/schedule_quick_presets.dart';
import '../l10n/app_localizations.dart';
import '../l10n/schedule_preset_localizer.dart';
import '../ui/hyperos/hyperos_theme.dart';
import '../utils/hex_color.dart';
import '../utils/theme_seed_accent.dart';

/// 模板 id → 图标。
///
/// 图标表达**活动类型**（一群人 / 讲台 / 会议室 / 面试），不表达品牌或情绪。
/// 十颗挤在一屏里时，只有「轮廓差异足够大」才扫得过去，所以刻意混用圆形
/// （groups / defense）、方形（meeting_room / clinic）与细长（commute）轮廓，
/// 而不是全挑同一族的 `*_outlined`。
const Map<String, IconData> kScheduleQuickPresetIcons = <String, IconData>{
  'groups': Icons.groups_2_outlined,
  'lecture': Icons.campaign_outlined,
  'meeting': Icons.meeting_room_outlined,
  'defense': Icons.co_present_outlined,
  'interview': Icons.assignment_ind_outlined,
  'dining': Icons.restaurant_rounded,
  'workout': Icons.fitness_center_rounded,
  'study': Icons.menu_book_rounded,
  'clinic': Icons.medical_services_outlined,
  'commute': Icons.commute_rounded,
};

/// 名字 → 图标；未知名字回落通用日程图标，不抛
/// （与 `pickup_code_icons.dart` 的 `pickupCodeIconFor` 同口径）。
IconData scheduleQuickPresetIconFor(String name) {
  return kScheduleQuickPresetIcons[name] ?? Icons.event_available_outlined;
}

/// 新建日程页顶部的「快捷模板」，一排紧凑胶囊，**十项全部可见、不需要滑动**。
///
/// ## 为什么是换行胶囊，不是横向滚动的大卡片
///
/// 第一版做成了 88×100dp 的卡片横向滚动：360dp 屏上只能完全露出 3 张，第 4 张
/// 露个边角（用户反馈「按钮太大个」）。滚动轨的根本问题是**看不见的东西等于
/// 不存在**——十项里藏了七项，还得靠右缘渐隐去提示「右边还有」。
///
/// 换成 `Wrap` 之后没有隐藏内容，也就不需要任何滚动提示。中文下 10 项排 3 行、
/// 高度约 110dp：比原来的 100dp 只高一点点，但**从「看到 3 个」变成「看到 10 个」**。
///
/// ## 尺寸怎么定的
///
/// 胶囊高 32、图标 14、文字 13sp、左右内边距 7、间距 6。中文一颗约 62dp：
/// 393dp 屏（可用 337dp）一行放 5 颗，**10 颗正好 2 行 5+5**，整块约 70dp。
///
/// 这组数是量出来的、不是估的：颗宽 65 时只能每行 4 颗、10 颗排成 4+4+2，
/// 末行两颗孤零零地挂在左边；压到 62 才让 10 能被 5 整除。`test/domain/
/// schedule_quick_preset_rail_test.dart` 里有一条「排布」用例把这个形状钉住。
///
/// 外语文案更宽（英文 `Interview` 一颗约 100dp），行数自然变多——这是文字宽度
/// 的客观结果，不做截断换密度。宁可多一行，也不要让用户读到 `Intervie…`。
///
/// ## 为什么去掉时长文字
///
/// 卡片时代每格都印着「2 小时」。胶囊装不下，而它其实是**冗余信息**：点完
/// 之后时间字段里立刻显示真实起止时刻，那比「2 小时」更准也更靠得住。
/// 时长仍在无障碍标签里念给读屏用户（见 `semanticLabel`）。
///
/// ## 用色口径照抄 `HyperosChipRow`
///
/// 未选中 = 中性浅底 + 模板色图标；选中 = **实心模板色** + 由该底色算出的
/// 墨色。十种活动各有颜色，选中后整颗变那个颜色，比只描一圈彩边更容易在
/// 余光里认出来。
///
/// 墨色一律由**实际底色**算（`onAccentInk`），不拿主题强调色算：模板色与
/// 主题色是两套值，混用会在中性灰主题下算出深字压深底。
class ScheduleQuickPresetRail extends StatelessWidget {
  const ScheduleQuickPresetRail({
    super.key,
    required this.selectedPresetId,
    required this.onPresetTap,
    this.presets = kScheduleQuickPresets,
  });

  /// 当前**已套用且内容仍然吻合**的模板 id；null = 没有选中项。
  final String? selectedPresetId;

  /// 点一颗胶囊；已选中那颗再点一次 = 取消套用（由调用方处理）。
  final ValueChanged<ScheduleQuickPreset> onPresetTap;

  final List<ScheduleQuickPreset> presets;

  /// 胶囊高度。取值口径见类注释「尺寸怎么定的」。
  static const double chipHeight = 32;

  /// 同排与换行后的间距。竖向略小于横向：胶囊本身不高，等间距会让行与行
  /// 之间显得松，读起来像两组而不是一组。
  static const double _gapX = 6;
  static const double _gapY = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 文案缺失的条目直接不渲染，而不是留一颗空标题的胶囊。漏配由
    // test/l10n/schedule_preset_localizer_test.dart 当面报出来。
    final visible = presets
        .where((preset) => scheduleQuickPresetTitle(l10n, preset.id).isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: _gapX,
      runSpacing: _gapY,
      children: [
        for (final preset in visible)
          _PresetChip(
            key: ValueKey('schedule-quick-preset-${preset.id}'),
            preset: preset,
            title: scheduleQuickPresetTitle(l10n, preset.id),
            durationLabel: scheduleQuickPresetDurationLabel(
              l10n,
              preset.durationMinutes,
            ),
            selected: preset.id == selectedPresetId,
            onTap: () => onPresetTap(preset),
          ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    super.key,
    required this.preset,
    required this.title,
    required this.durationLabel,
    required this.selected,
    required this.onTap,
  });

  final ScheduleQuickPreset preset;
  final String title;
  final String durationLabel;
  final bool selected;
  final VoidCallback onTap;

  static const double _height = ScheduleQuickPresetRail.chipHeight;

  /// 胶囊最小宽度。
  ///
  /// 只给下限、**不给上限**：上限会拿测试环境的回退字体宽度去截断真机文字
  /// （回退字体每字符占 1em，英文 7 字符就量出 91dp；真机 MiSans 约六成）。
  /// 那种「在测试里看起来整齐、在真机上被省略号砍掉」的做法是本末倒置。
  ///
  /// 宽度交给 `IntrinsicWidth` 按内容量：中文每颗约 59dp，英文每颗约
  /// 70～95dp，各自排成 2～3 行——**文字完整**优先于行数好看。
  static const double _minChipWidth = 52;

  @override
  Widget build(BuildContext context) {
    final accent = parseHexColorOrFallback(
      preset.colorHex,
      fallback: HyperosColors.primary(context),
    );
    // 选中 = 实心模板色（与 `HyperosChipRow` 同一套语言）；
    // 未选中 = 中性浅底。
    final fill = selected ? accent : HyperosColors.rowHighlight(context);
    final ink = selected
        ? onAccentInk(accent)
        : HyperosColors.primaryText(context);
    // 未选中态图标仍用模板色：让用户在点之前就分得出「这颗是聚餐」，
    // 而不是十颗一模一样的灰胶囊。
    final iconInk = selected ? ink : accent;
    // 胶囊全圆（高 / 2）。别用 `HyperosRadius.clampCornerRadius` 那套留 6px
    // 直边的收口——那是给卡片那类大面子的规矩，胶囊本来就该是圆的
    // （与 `hyperos_chip_row.dart` 同一条口径，那边踩过「按钮不圆」的反馈）。
    final radius = BorderRadius.circular(_height / 2);

    final chip = DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      child: SizedBox(
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                scheduleQuickPresetIconFor(preset.icon),
                size: 14,
                color: iconInk,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyperosTypography.listTitle(context).copyWith(
                  fontSize: 13,
                  // 行高显式写死：`listTitle` 的 1.25 是给列表行排的，
                  // 字号一改行高就和字形对不上（胶囊里表现为字没垂直居中）。
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: ink,
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // **必须把胶囊收成内容宽度**：`MiuixPressable` 会把子节点撑到父级给的
    // 最大宽度，放进 `Wrap` 后就变成「每颗都占半行」——英文实测每颗 125dp、
    // 十项排成 5 行（中文因为字少，碰巧没暴露）。
    // 包一层 `IntrinsicWidth` 让它按文字实际宽度收紧，Wrap 才能正确并排。
    // `IntrinsicWidth` 是「按内容量宽度」的唯一可靠写法：
    // 只给 `ConstrainedBox(maxWidth:)` 时，子节点仍会**撑满**那个上限
    // （实测中英日韩每颗都恰好顶到同一个值），看起来像固定宽。
    final sized = IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _minChipWidth),
        child: chip,
      ),
    );

    // `selected` 只发语义；button / 无障碍标签交给 MiuixPressable 自己发，
    // 免得 TalkBack 把同一个节点念两遍（与 `hyperos_chip_row.dart` 一致）。
    //
    // 时长写进 label 而不是印在胶囊上：视觉上省高度，读屏用户仍然听得到。
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: MiuixPressable(
        onPressed: onTap,
        borderRadius: radius,
        semanticLabel: durationLabel.isEmpty
            ? title
            : '$title，$durationLabel',
        child: sized,
      ),
    );
  }
}
