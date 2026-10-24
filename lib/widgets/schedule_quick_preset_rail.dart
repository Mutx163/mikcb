import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../domain/schedule_quick_presets.dart';
import '../l10n/app_localizations.dart';
import '../l10n/schedule_preset_localizer.dart';
import '../ui/hyperos/hyperos_miuix_spec.dart';
import '../ui/hyperos/hyperos_radius.dart';
import '../ui/hyperos/hyperos_theme.dart';
import '../ui/hyperos/hyperos_tokens.dart';
import '../utils/hex_color.dart';
import '../utils/theme_seed_accent.dart';

/// 模板 id → 图标。
///
/// 图标表达**活动类型**（一群人 / 讲台 / 会议室 / 面试），不表达品牌或情绪；
/// 十颗挤在同一行时，只有「轮廓差异足够大」才扫得过去，所以刻意混用圆形
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

/// 新建日程页顶部的「快捷模板」横向轨。
///
/// ## 为什么是横向轨，不是网格
///
/// 新建日程页是一张纵向表单。模板如果排成 2×5 网格，会在「启用开关」和
/// 「标题」之间插进近 200dp 高的整块区域，把真正要填的第一个字段挤出首屏——
/// 那是拿「省几次点击」换「每次都要滑一下」。单行轨只占约 92dp。
/// 十颗横向排，末颗露半张，天然提示还能滑（与 `HyperosChipRow` 在
/// `equalWidth: false` 时的口径一致）。
///
/// ## 用色口径照抄 `HyperosChipRow`
///
/// 本仓「从若干类别里挑一类」的控件只有胶囊一种长相：**未选中 = 中性浅底、
/// 选中 = 实心填色**。模板卡沿用这条，用户不必重新学一套选中语义。
/// 唯一扩展是「填的是模板自己的颜色，不是全局主题色」——十种活动各自有颜色，
/// 选中后卡片整体变那个颜色，比只描一圈彩边更容易在余光里认出来。
///
/// 墨色一律由**卡片实际底色**算（`onAccentInk`），不拿主题色去算：
/// 模板色与主题强调色是两套值，混用会在中性灰主题下算出深字压深底。
class ScheduleQuickPresetRail extends StatelessWidget {
  const ScheduleQuickPresetRail({
    super.key,
    required this.selectedPresetId,
    required this.onPresetTap,
    this.presets = kScheduleQuickPresets,
  });

  /// 当前**已套用且内容仍然吻合**的模板 id；null = 没有选中项。
  final String? selectedPresetId;

  /// 点一颗卡；已选中那颗再点一次 = 取消套用（由调用方处理）。
  final ValueChanged<ScheduleQuickPreset> onPresetTap;

  final List<ScheduleQuickPreset> presets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 文案缺失的条目直接不渲染，而不是留一张空标题的卡。漏配由
    // test/l10n/schedule_preset_localizer_test.dart 当面报出来。
    final visible = presets
        .where((preset) => scheduleQuickPresetTitle(l10n, preset.id).isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // 右侧留 20dp：`_MoreHintEdge` 的渐隐要压在这段空白上，否则它会盖住
          // 第 4 张卡的右边缘（看起来像卡坏了）。
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final preset in visible) ...[
                _PresetTile(
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
                const SizedBox(width: HyperosTokens.rowContentGap),
              ],
            ],
          ),
        ),
        const Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: _MoreHintEdge(),
        ),
      ],
    );
  }
}

/// 右边缘的渐隐提示：告诉用户「这一行还能往右滑」。
///
/// ## 为什么必须有
///
/// 十张卡在 360dp 屏上只能完全露出 3 张，第 4 张只露一个边角（实测：312dp
/// 可视 / 96dp 步长 = 3.25 张）。只靠「露半张」这个传统提示是不够的——
/// 露 25% 的时候，那一角看起来更像**渲染裁切**而不是「还有更多」。
///
/// 渐隐本身是「内容延伸出屏幕」的通用视觉语言，不需要文字解释，
/// 也不占高度（压在轨道右侧、宽度 20dp）。
///
/// ## 为什么不用 `ShaderMask` 而是画一块渐变
///
/// `ShaderMask` 会在滚动时重建整条轨道的着色器，滚动列表里那是最贵的做法之一；
/// 这里只需要在**固定位置**盖一块渐变，用 `IgnorePointer` + 渐变容器即可，
/// 滚动时零重建（它也吃不到手指事件，不会挡住第 4 张卡的点击）。
class _MoreHintEdge extends StatelessWidget {
  const _MoreHintEdge();

  /// 测试用来精确点名这块渐隐（按 IgnorePointer 找会因为树上到处都有而假通过）。
  static const Key hintKey = Key('schedule-preset-more-hint');

  static const double width = 20;

  @override
  Widget build(BuildContext context) {
    // 渐隐必须从「完全透明」过渡到**与它身下的底色相同**的颜色，
    // 否则会看到一条灰带的边界。这里拿卡片所在的表面色作终点。
    final surface = HyperosColors.card(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final end = isDark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : surface;
    return IgnorePointer(
      key: hintKey,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // 默认就是从左到右，不必再写 begin/end。
            // 前 40% 保持全透明：让第 4 张卡露出的那点边角**看得清**，
            // 只把最后 60% 渐隐成底色。
            gradient: LinearGradient(
              colors: [end.withValues(alpha: 0), end],
              stops: const [0.4, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
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

  /// 卡宽 88、卡高 100。
  ///
  /// 高度按「图标 22 + 标题最多两行 34 + 间隔 2 + 时长 13 + 内边距 24」留出
  /// 余量：中文标题两字只占一行，英文（"Interview" / "Commute"）在这点宽度里
  /// 放不下一行就得允许折成两行——**不允许折行就等于让英文用户看见
  /// "Intervie…"**。中文那一行靠 `Spacer` 压到底部，所以两种语言下时长行
  /// 都停在同一位置，卡片看起来仍然齐。
  static const double _tileWidth = 88;
  static const double _tileHeight = 100;

  @override
  Widget build(BuildContext context) {
    final accent = parseHexColorOrFallback(
      preset.colorHex,
      fallback: HyperosColors.primary(context),
    );
    // 选中 = 实心模板色（与胶囊同一套语言）；未选中 = 中性浅底。
    final fill = selected ? accent : HyperosColors.rowHighlight(context);
    final ink = selected
        ? onAccentInk(accent)
        : HyperosColors.primaryText(context);
    // 说明行在实心底上不能再用灰字（灰对彩底会糊成一团），改成墨色降透明度。
    final subInk = selected
        ? ink.withValues(alpha: 0.78)
        : HyperosColors.secondaryText(context);
    // 未选中态的图标仍用模板色：让用户在点之前就认得出「这张是聚餐」，
    // 而不是十张一模一样的灰卡。
    final iconInk = selected ? ink : accent;
    final radius = HyperosRadius.chipRadius(_tileHeight);

    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(
        width: _tileWidth,
        height: _tileHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    scheduleQuickPresetIconFor(preset.icon),
                    size: 22,
                    color: iconInk,
                  ),
                  const Spacer(),
                  // 对勾只在选中态出现。放在图标同一行右端，而不是盖在角上：
                  // 盖角会压到 84dp 窄卡的圆角，看起来像没对齐。
                  if (selected) Icon(Icons.check_rounded, size: 16, color: ink),
                ],
              ),
              const Spacer(),
              Text(
                title,
                // 两行上限的理由见 [_tileWidth] / [_tileHeight] 的注释。
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HyperosTypography.listTitle(context).copyWith(
                  fontSize: 14,
                  // 行高显式写死：`listTitle` 的 1.25 是给列表行排的，
                  // 字号一改行高就和字形对不上（表现为字没在卡里居中）。
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                durationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyperosTypography.listDetail(context).copyWith(
                  fontSize: 11,
                  height: 1.2,
                  color: subInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // `selected` 只发语义；button / 无障碍标签交给 MiuixPressable 自己发，
    // 免得 TalkBack 把同一个节点念两遍（与 `hyperos_chip_row.dart` 一致）。
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: MiuixPressable(
        onPressed: onTap,
        borderRadius: BorderRadius.circular(radius),
        semanticLabel: durationLabel.isEmpty ? title : '$title，$durationLabel',
        child: tile,
      ),
    );
  }
}
