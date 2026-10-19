import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../../models/wallpaper_history.dart';
import '../../ui/hyperos/hyperos.dart';

/// 「最近使用」缩略图条的固定高度。
///
/// 卡内是「缩略图（Expanded）+ 6px + 标签/确认按钮」三段，高度定死才不会因为
/// 其中一张卡进了确认态（标签位换成两颗 24px 按钮）而把整条撑高、邻卡错位。
const double _recentWallpaperStripHeight = 116;

/// 卡内标签位的高度：常态是标签（最多两行 11px），确认态是那颗按钮行。
///
/// 定高的意义是缩略图在两种状态间**尺寸不变** —— 不定高的话 `Expanded` 会把
/// 高度差吃掉，进确认态那一帧缩略图会肉眼可见地缩一下。
const double _recentCardLabelHeight = 26;


/// 「最近使用」整段：标题 + 缩略图条 + 移除确认条。
///
/// **确认按钮为什么画在条外面、而不是塞进卡里**（第一版塞进去过，被否掉）：
///
/// * **塞不进。** 78 宽的卡里平分两颗按钮只剩约 37 宽，要放到 24px 高才不至于
///   把卡片标签顶掉 —— 而 24×37 远小于最小点击区，真机上按不准。
/// * **几何必然出错。** 卡片的 `MiuixPressable` 会按自己的 14 圆角裁剪子树，
///   于是按钮自己的圆角和外侧被父级裁出来的圆角**对不上**：两颗按钮的外侧下角
///   是父级的 14、内侧与上侧是按钮自己的 8，看起来就是"某个角圆得不一样"。
/// * **画在条外面就没有这些约束**：两颗都是设置页其他地方同款的
///   [HyperosButton]（高度约 40、点得准、圆角与其他按钮一致），条只负责
///   "哪张被选中了"这一件事。
///
/// 确认态**不弹覆盖层**：这个流程有两个宿主，其中「外观编辑」页底部那颗
/// 「调整壁纸」是底部弹层；而弹层是根覆盖层自插条目，任何再往上的弹层都会被
/// 压在它背面（真机实锤，材质面板那边为同一件事做过 `_withHostSheetClosed`）。
/// 弹确认框在两个宿主里必然分叉，"确认条就地长在列表下面"则两边天然一致。
class RecentWallpaperSection extends StatefulWidget {
  const RecentWallpaperSection({super.key, 
    required this.entries,
    required this.selectedKey,
    required this.l10n,
    required this.horizontalInset,
    required this.onSelect,
    required this.onBlockedRemove,
    required this.onConfirmRemove,
  });

  final List<WallpaperHistoryEntry> entries;

  /// 当前正在用的那张的键；它不可移除。
  final String? selectedKey;

  final AppLocalizations l10n;

  /// 宿主给的左右内缩（见 `_HomeBackdropFlow.backdropRowHorizontalInset`）：
  /// 设置页那一处是 16（卡片自己的行内缩），弹窗那一处是 0（面板已经给了 16）。
  final double horizontalInset;

  final ValueChanged<WallpaperHistoryEntry> onSelect;

  /// 「你按的那张正被使用、不能移除」的解释。角标不会出现在它上面，所以这条路
  /// 只可能来自长按 —— 那也正是唯一能让用户问出"为什么这张没有 ×"的时刻。
  final void Function(BuildContext context, WallpaperHistoryEntry entry)
  onBlockedRemove;

  final void Function(BuildContext context, WallpaperHistoryEntry entry)
  onConfirmRemove;

  @override
  State<RecentWallpaperSection> createState() =>
      RecentWallpaperSectionState();
}

class RecentWallpaperSectionState extends State<RecentWallpaperSection> {
  /// 已发起移除、正等确认的那一条的键；null = 没有。
  String? _armedKey;

  @override
  void didUpdateWidget(RecentWallpaperSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 删掉之后（或历史被外部改动之后）不能让一个已经不存在的 key 继续挂着：
    // 那会留下一条永远按不掉、也永远删不掉的确认条。
    final key = _armedKey;
    if (key != null && !widget.entries.any((entry) => entry.key == key)) {
      _armedKey = null;
    }
  }

  void _disarm() {
    if (_armedKey == null) {
      return;
    }
    setState(() => _armedKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalInset,
        14,
        widget.horizontalInset,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homePageWallpaperRecentTitle,
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homePageWallpaperRecentSubtitle,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _recentWallpaperStripHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final isCurrent = entry.key == widget.selectedKey;
                final armed = entry.key == _armedKey;
                return _WallpaperThumbnailCard(
                  // 按壁纸键给每张卡一个稳定的 key：确认态会让角标此消彼长
                  // （被选中的那张自己收起角标），几何测试只靠"第几个 ×"
                  // 根本指不准是哪一张。
                  key: ValueKey<String>('wallpaper-recent-card:${entry.key}'),
                  label: l10n.homePageWallpaperRecentImageLabel,
                  selected: isCurrent,
                  removable: !isCurrent,
                  armed: armed,
                  onTap: () {
                    // 已发起移除的那张，单击是**取消**而不是切壁纸：它此刻的
                    // 语义是"要不要删"，顺手把壁纸也换了就是一次操作两个后果。
                    if (armed) {
                      _disarm();
                      return;
                    }
                    widget.onSelect(entry);
                  },
                  onRequestRemove: () {
                    if (armed) {
                      _disarm();
                      return;
                    }
                    setState(() => _armedKey = entry.key);
                  },
                  // 不可移除的那张：长按只解释一句为什么不行（没有 × 角标）。
                  onBlockedRemove: () => widget.onBlockedRemove(context, entry),
                  thumbnail: Image.file(
                    File(entry.key),
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                    // 列表构建后文件被删/损坏时不崩帧。
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
          if (_armedKey != null) ...[
            const SizedBox(height: 14),
            Text(
              l10n.wallpaperHistoryRemoveConfirmHint,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.error(context),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: HyperosButton(
                    label: l10n.deleteAction,
                    variant: HyperosButtonVariant.destructive,
                    onPressed: () {
                      final entry = _armedEntry();
                      _disarm();
                      if (entry != null) {
                        widget.onConfirmRemove(context, entry);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosButton(
                    label: l10n.cancelAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _disarm,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 当前已发起移除的那一条（条目可能已经不在列表里 → null）。
  WallpaperHistoryEntry? _armedEntry() {
    final key = _armedKey;
    if (key == null) {
      return null;
    }
    for (final entry in widget.entries) {
      if (entry.key == key) {
        return entry;
      }
    }
    return null;
  }
}

/// 壁纸缩略图卡（「最近使用」条里的一张）：78 宽，选中态描边 + 高亮标签。
///
/// 两种附加形态（与常态互斥，见 [RecentWallpaperSection]）：
/// * [armed]：已发起移除 —— 缩略图压暗 + 警示色描边、角标收起。此时单击与长按
///   都改走"取消"，确认改由条下面那条确认条承担；
/// * [removable] 为 false：正在用的那张，没有角标，长按只解释一句为什么不给删。
class _WallpaperThumbnailCard extends StatelessWidget {
  const _WallpaperThumbnailCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.thumbnail,
    this.removable = true,
    this.armed = false,
    this.onRequestRemove,
    this.onBlockedRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget thumbnail;

  /// 是否允许移除。正在用的那张传 false（不给角标，也进不了确认态）。
  final bool removable;

  /// 本卡是否正处在"已发起移除、等确认"的状态。
  final bool armed;

  /// 请求移除（角标 / 长按都走它）。armed 时它变成"取消"。
  final VoidCallback? onRequestRemove;

  /// 不可移除时对"用户仍想删"的回应（解释为什么不行）。
  final VoidCallback? onBlockedRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = HyperosColors.primary(context);
    final danger = HyperosColors.error(context);
    return SizedBox(
      width: 78,
      child: Stack(
        children: [
          MiuixPressable(
            onPressed: onTap,
            onLongPress: armed
                ? onRequestRemove
                : (removable ? onRequestRemove : onBlockedRemove),
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: armed
                            ? danger
                            : (selected ? primary : Colors.transparent),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      // 已发起移除时在缩略图上压一层半透明黑：让"这张要被移除
                      // 了"在图本身也读得出来，而不只是靠那颗红边。
                      //
                      // 刻意用「叠一层」而不是 `Opacity` / `ColorFiltered`：
                      // `Opacity` 会把图往卡片底色上混（读作"发白"而不是"被压
                      // 暗"），`ColorFiltered(srcATop, 黑)` 则直接把不透明区域
                      // 涂成纯黑。
                      child: Stack(
                        key: const ValueKey<String>('wallpaper-card-thumbnail'),
                        fit: StackFit.expand,
                        children: [
                          thumbnail,
                          if (armed)
                            const ColoredBox(color: Color(0x99000000)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 标签位**定高**（= 两行 11px）：条高定死之后，卡内三段的分配
                // 才是确定的，缩略图不会因为标签一行 / 两行之差而每张各高一点。
                SizedBox(
                  height: _recentCardLabelHeight,
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: armed
                            ? danger
                            : (selected
                                  ? primary
                                  : HyperosColors.secondaryText(context)),
                        fontWeight: selected || armed
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 角标画在按压区**之外**：压在卡内的话，点它会连带把壁纸切了。
          // armed 时收起 —— 确认条已经接管，它留着只会让人以为还能再点一次。
          if (removable && !armed)
            Positioned(
              top: 4,
              right: 4,
              child: _WallpaperRemoveBadge(
                onPressed: onRequestRemove,
                tooltip: l10n.wallpaperHistoryRemoveBadgeTooltip,
              ),
            ),
        ],
      ),
    );
  }
}

/// 缩略图右上角的「×」角标（小米相册那套「角标移除」）。
///
/// 刻意做成**看得见的入口**而不是只有长按：移除是不可逆的（图片文件一起删），
/// 藏在隐藏手势后面等于让用户自己发现 + 试错。
class _WallpaperRemoveBadge extends StatelessWidget {
  const _WallpaperRemoveBadge({required this.onPressed, this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final badge = MiuixPressable(
      onPressed: onPressed,
      borderRadius: BorderRadius.circular(10),
      // 不加白底：压在照片上时白圆反而更抢眼，半透明黑 + 白 × 才是图库里
      // 那个"角标"该有的分量。
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF000000).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 15,
          color: Colors.white,
        ),
      ),
    );
    // 无障碍 / 悬停说明：角标本身只有一颗 15px 的 ×，不配一句说明读屏用户
    // 只能听出"按钮"。
    final label = tooltip;
    if (label == null || label.isEmpty) {
      return badge;
    }
    return Tooltip(message: label, child: badge);
  }
}