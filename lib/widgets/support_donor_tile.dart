import 'package:flutter/material.dart';

import '../services/support_creator_service.dart';
import '../ui/hyperos/hyperos.dart';

/// 鸣谢名单单行：首字圆形头像 + 昵称/留言（左）+ 金额/日期（右）。
///
/// 头像底色与字色按昵称哈希从精选色相轮转取得，且均为不透明色——
/// 液态玻璃卡上半透明水洗会透出壁纸发黑，故不用 alpha 混合。
class SupportDonorTile extends StatelessWidget {
  const SupportDonorTile({
    super.key,
    required this.donor,
    required this.isFirst,
    required this.isLast,
  });

  final SupportDonorEntry donor;
  final bool isFirst;
  final bool isLast;

  static const _avatarSize = 38.0;

  /// 头像缩进分隔线对齐正文左缘：16(行内边距) + 38(头像) + 12(间距)。
  static const dividerIndent = _avatarSize + 28.0;

  /// 精选色相（分布参照课程色板 Tailwind v3 骨架），按昵称哈希轮转。
  static const _avatarHues = [
    4.0, 25.0, 40.0, 95.0, 145.0, 172.0, //
    197.0, 217.0, 243.0, 262.0, 292.0, 330.0,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (avatarBg, avatarInk) = _avatarColors(donor.name, isDark: isDark);

    final amount = (donor.amount ?? '').trim();
    final rawDate = (donor.date ?? '').trim();
    // 原始格式 "2026-08-30 14:42:22"，右栏只保留日期部分。
    final date = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    final message = (donor.message ?? '').trim();
    final chars = donor.name.characters;
    final initial = chars.isEmpty ? '♥' : chars.first.toUpperCase();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, isFirst ? 12 : 10, 16, isLast ? 14 : 10),
      child: Row(
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: typo.body.md.copyWith(
                fontWeight: FontWeight.w600,
                color: avatarInk,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                    height: 1.3,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: typo.body.xs.copyWith(
                      color: colors.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (amount.isNotEmpty || date.isNotEmpty) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amount.isNotEmpty)
                  Text(
                    amount,
                    style: typo.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                      height: 1.3,
                      // 金额右栏纵向对齐：¥8.88 与 ¥20 数字位宽一致。
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (date.isNotEmpty) ...[
                  if (amount.isNotEmpty) const SizedBox(height: 2),
                  Text(
                    date,
                    style: typo.body.xs2.copyWith(
                      color: colors.mutedForeground,
                      height: 1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _avatarColors(String name, {required bool isDark}) {
    // Dart 的 % 对正模数恒返回非负值，无需 abs（abs 会撞上 min-int 溢出）。
    final hue = _avatarHues[name.hashCode % _avatarHues.length];
    final bg = HSLColor.fromAHSL(
      1,
      hue,
      isDark ? 0.42 : 0.68,
      isDark ? 0.26 : 0.90,
    ).toColor();
    final ink = HSLColor.fromAHSL(
      1,
      hue,
      isDark ? 0.60 : 0.55,
      isDark ? 0.82 : 0.36,
    ).toColor();
    return (bg, ink);
  }
}
