import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos.dart';

/// 「壁纸模糊」强度滑杆行：壁纸弹层第二页与「课表页面」设置共用**同一份**。
///
/// ## 为什么单独成一个文件
///
/// 它有两个宿主（外观编辑页的壁纸弹层、课表页面设置的壁纸卡旁），而两个宿主
/// 所在的文件都顶着行数棘轮：
///
/// * `screens/settings/settings_appearance_editor.dart` 只剩 2 行余量；
/// * 设置域总行数只剩 6 行余量，而 `settings_home_backdrop_flow.dart` 就在那个
///   统计范围内 —— 控件写在那里同样会顶爆。
///
/// 放到 `lib/widgets/` 后，两个宿主各只加一行调用。本文件不受任何行数棘轮约束
/// （`lib/widgets` 只会被 `delete_write_failure_guard_test` 扫，而它只管
/// "调 provider 写方法必须 await + 有出口" —— 本控件不碰 provider）。
///
/// ## 三个交互约束
///
/// 1. **`tapToEdit: false`**：壁纸弹层是根覆盖层自插条目（MiuixWindowBottomSheet），
///    点标题弹出的数字输入框会被压在面板**背面**，点不到 —— 2026-09-19 真机实锤，
///    `settings_appearance_editor.dart` 里那族滑杆都为此关了它。
/// 2. **写回走宿主的去抖通道**，自己不起 `Timer`：裸 `Duration` 会被
///    `animation_duration_guard_test` 抓（它只认已登记的白名单）。
/// 3. **0 档显示「关闭」而不是「0」**：这一档是"完全没有模糊"，不是"模糊量为 0"
///    —— 前者用户能理解，后者会让人以为还有一点点糊。
///
/// 读数是整数（`toStringAsFixed(0)`）：档位本身就是 0…24 的整数，而给每一档起名字
/// 要补 6 份多语言词，与 `_glassPresetSliderTile` 当时的取舍同一条理由。
class WallpaperBlurTile extends StatelessWidget {
  const WallpaperBlurTile({
    required this.sigma,
    required this.onChanged,
    super.key,
  });

  /// 当前强度（逻辑 px）。调用方负责夹在
  /// [TimetableSettings.minHomePageWallpaperBlurSigma] /
  /// [TimetableSettings.maxHomePageWallpaperBlurSigma] 之间。
  final double sigma;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const min = TimetableSettings.minHomePageWallpaperBlurSigma;
    const max = TimetableSettings.maxHomePageWallpaperBlurSigma;
    // 存量值可能越界（旧存档 / 手改 JSON）：拇指与数字都夹到收口带，
    // 与出图侧同口径 —— 否则就是「拖了数字不动」那一类半失效。
    final shown = sigma.clamp(min, max).toDouble();
    return HyperosSliderTile(
      // 面板内禁开二级弹层（见类注释第 1 条）。
      tapToEdit: false,
      title: l10n.homePageWallpaperBlurTitle,
      value: shown,
      // 显式给 min：目前它就等于 HyperosSliderTile 的默认值 0，所以 lint 会报
      // redundant —— 但它必须绑在收口常量上，将来那道下限若不再是 0（例如真机验完
      // 最弱档发现 1~2 读成"糊得脏"、把下限抬到 3），这里要自动跟着走，
      // 而拇指/数字/出图三处一旦不同口径就是「拖了没变化」。
      // ignore: avoid_redundant_argument_values
      min: min,
      max: max,
      // 每格 1：强度就是整数档，档数跟着上限走，别写死。
      divisions: max.round(),
      valueLabel: shown <= min
          ? l10n.homePageWallpaperBlurOff
          : shown.toStringAsFixed(0),
      onChanged: onChanged,
    );
  }
}
