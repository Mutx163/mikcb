import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/hyperos_motion.dart';

/// 任务行的完成勾选钮（原 `task_list_screen.dart` 的私有 `_TaskCheckbox`，
/// 2026-10-20 提出，作业列表页与日视图待办带共用）。
///
/// 未完成是描边圆环、完成是实心主色底白勾。**自绘而不是用 `MiuixCheckbox`**：
/// 后者的未选中态是一枚实心灰圆，放在任务行首位只像一个无意义的灰点
/// （原实现注释记录了这个判断）。
///
/// 点击先给一次轻震感再回调；回调是 `VoidCallback`，**调用方自己负责**
/// await 落盘并接住失败——这个钮不持有 provider，也不该知道写盘会失败。
class TaskCheckbox extends StatelessWidget {
  final bool value;
  final VoidCallback onChanged;

  /// 视觉尺寸；日视图待办带比列表页略小，故可调。
  final double size;

  const TaskCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged();
      },
      child: Padding(
        // 扩大点击热区到约 30dp。
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: 180.scaledMs,
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? colors.primary : Colors.transparent,
            border: Border.all(
              color: value
                  ? colors.primary
                  : colors.mutedForeground.withValues(alpha: 0.45),
              width: 2,
            ),
          ),
          child: value
              ? Icon(
                  Icons.check_rounded,
                  size: size * 0.68,
                  color: colors.primaryForeground,
                )
              : null,
        ),
      ),
    );
  }
}
