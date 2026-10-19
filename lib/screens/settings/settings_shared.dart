import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/service_message_localizer.dart';
import '../../models/settings/timetable_settings_live.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/app_toast.dart';
import '../../utils/hex_color.dart';

/// 设置域共享件：设置页根列表与各设置子页都要用的小组件与 helper。
///
/// 这里只放「被 ≥2 个设置子页共享、且不含任何子页私有状态」的东西；
/// 某个子页专用的组件留在那个子页的文件里。
///
/// 2026-10-19 自 `timetable_settings_screen.dart` 原样搬出（彼时它们是宿主库
/// 顶层符号，16 个 part 分身经同库可见性使用）。私有名转公开：
/// `_MiuixSettingsSwitchPreference`→[MiuixSettingsSwitchPreference]、
/// `_MiuixSettingsPreference`→[MiuixSettingsPreference]、
/// `_settingsIconBadge`→[settingsIconBadge]、`_colorFromHex`→[colorFromHex]、
/// `_liveDisplaySummary`→[liveDisplaySummary]。搬迁零行为变化。

/// 直播时间校准（提前/延后秒数）的本地化文案。
String formatLiveTimeCorrection(AppLocalizations l10n, int seconds) {
  if (seconds == 0) {
    return l10n.liveTimeCorrectionNone;
  }
  if (seconds > 0) {
    return l10n.liveTimeCorrectionDelay(seconds);
  }
  return l10n.liveTimeCorrectionAdvance(seconds.abs());
}

/// 设置「改一下就存」入口的落盘失败兜底。
///
/// [TimetableProvider.updateTimetableSettings] 在落盘失败时会先把内存、课表
/// 镜像和周次回滚，再把原始异常 rethrow 出来。设置页这些自动保存入口全都没接
/// 这个异常——不接的话它会变成无人监听的失败 Future（最终被 `main.dart` 的
/// `runZonedGuarded` 吃掉），用户看到的是「设置已改了」，其实一个字节都没存
/// 进去，重启 App 又变回去，全程没有任何提示。
///
/// 这里统一给出一句本地化提示，并（经 [resetDraft]）把页面草稿拉回 provider
/// 回滚后的真实值，避免界面停在「看着已保存、实际没保存」的状态。
void reportSettingsPersistFailure<T extends StatefulWidget>(
  State<T> state, {
  VoidCallback? resetDraft,
}) {
  if (!state.mounted) {
    return;
  }
  final context = state.context;
  showAppToast(
    context,
    message: AppLocalizations.of(context)!.saveFailed,
    kind: AppToastKind.error,
  );
  resetDraft?.call();
}

/// 设置保存被底层规则拒绝（不是落盘失败）时的统一提示。
///
/// [TimetableProvider.updateTimetableSettings] 除了落盘异常，还会用
/// `encodeServiceMessage` 返回一个编码过的消息键，例如把每天节数调到低于
/// 已有课程用到的最大节次时返回 `section_count_below_usage|requiredMaxSection=12`。
/// 那是给界面翻译用的载荷，不是能直接给人看的文案——漏掉翻译就会把内部代码
/// 原样弹给用户。
void reportSettingsPersistRejected<T extends StatefulWidget>(
  State<T> state,
  String message,
) {
  if (!state.mounted) {
    return;
  }
  final context = state.context;
  showAppToast(
    context,
    message: localizeServiceMessage(AppLocalizations.of(context)!, message),
  );
}

/// 语言下拉里的 locale 标签归一：`zh-Hans` → `zh_Hans`，且必须落在
/// [AppLocalizations.supportedLocales] 内（先试完整标签，再退语言码）。
String normalizeLocaleTagForDropdown(String tag) {
  final normalized = tag.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final canonical = normalized.replaceAll('-', '_');
  final supportedTags = AppLocalizations.supportedLocales
      .map(
        (locale) => locale.countryCode?.isNotEmpty == true
            ? '${locale.languageCode}_${locale.countryCode}'
            : locale.languageCode,
      )
      .toSet();
  if (supportedTags.contains(canonical)) {
    return canonical;
  }
  final languageCode = canonical.split('_').first;
  if (supportedTags.contains(languageCode)) {
    return languageCode;
  }
  return '';
}

/// 十六进制颜色串的容错解析（坏串回退到品牌蓝）。
Color colorFromHex(String hexColor) {
  return parseHexColorOrFallback(hexColor, fallback: const Color(0xFF2563EB));
}

/// 直播显示设置的摘要行文案（勾选项用「·」串联，超过两项收进 more 文案）。
String liveDisplaySummary(BuildContext context, LiveDisplaySettings settings) {
  final l10n = AppLocalizations.of(context)!;
  final parts = <String>[];
  if (settings.showCourseName) {
    parts.add(
      settings.useShortName
          ? l10n.liveDisplaySummaryShortName
          : l10n.liveDisplaySummaryCourseName,
    );
  }
  if (settings.showLocation) {
    parts.add(l10n.liveDisplaySummaryLocation);
  }
  if (settings.showCountdown) {
    parts.add(l10n.liveDisplaySummaryCountdownShort);
  } else if (settings.showStageText) {
    parts.add(l10n.liveDisplaySummaryStageText);
  }
  if (settings.enableMiuiIslandLabelImage) {
    parts.add(l10n.liveDisplaySummaryLeftLabelImage);
  }
  if (parts.isEmpty) {
    return l10n.liveDisplaySummaryMinimal;
  }
  if (parts.length <= 2) {
    return parts.join('·');
  }
  return l10n.liveDisplaySummaryMore(parts.first, parts.length);
}

/// 设置首页图标 Badge：彩色圆角背景 + 白色图标（与 HyperosIconBadge 一致）。
Widget settingsIconBadge(MiuixVectorIcon icon, Color accent) {
  return Container(
    width: HyperosTokens.iconBadgeSize,
    height: HyperosTokens.iconBadgeSize,
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(HyperosTokens.iconBadgeRadius),
    ),
    alignment: Alignment.center,
    child: MiuixIcon(
      vector: icon,
      size: HyperosTokens.iconGlyphSize,
      tint: Colors.white,
    ),
  );
}

/// 开发者区开关行，与导航行共享标题字重和按压反馈。
class MiuixSettingsSwitchPreference extends StatelessWidget {
  const MiuixSettingsSwitchPreference({
    super.key,
    required this.startAction,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Widget startAction;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return HyperosPressableRow(
      onTap: () => onChanged(!value),
      holdHighlightThroughTransition: true,
      child: MiuixBasicComponent(
        // 上游把标题字重硬编码为 w500（比本 App 其余设置行的
        // HyperosTypography.title w400 重一档），且 1.2.0 的 MiuixBasicComponent
        // 不再接受 titleFontWeight。改用它的 content 参数复刻默认排版、只把基准
        // 字重降回 w400 —— 与默认路径同用 MiuixText（仍随系统字重分级平移），
        // 因此观感与 fork 版一致。
        content: [
          MiuixText(
            title,
            fontSize: MiuixTheme.of(context).textStyles.headline1.fontSize,
            fontWeight: FontWeight.w400,
            color: MiuixBasicComponentDefaults.titleColor(context).resolve(true),
          ),
        ],
        startAction: startAction,
        endActions: [MiuixSwitch(value: value, onChanged: onChanged)],
        role: MiuixBasicComponentRole.switchControl,
      ),
    );
  }
}

/// 带正确按压反馈的 Miuix 设置行。
///
/// 外层 [HyperosPressableRow] 处理按压高亮（根据 isFirst/isLast 裁剪圆角），
/// 内层 [MiuixArrowPreference] 只负责显示。
class MiuixSettingsPreference extends StatelessWidget {
  const MiuixSettingsPreference({
    super.key,
    required this.startAction,
    required this.title,
    this.endActions,
    required this.onClick,
  });

  final Widget startAction;
  final String title;
  final List<Widget>? endActions;
  final VoidCallback? onClick;

  @override
  Widget build(BuildContext context) {
    return HyperosPressableRow(
      onTap: onClick,
      holdHighlightThroughTransition: true,
      // 上游把标题字重硬编码为 Medium(w500)，比全 App 其余设置行所用的
      // HyperosTypography.title(w400) 重一档；而 1.2.0 的
      // MiuixArrowPreference / MiuixBasicComponent 不再接受 titleFontWeight。
      // 本行标题是这棵子树里**唯一**的 Miuix 文本（行尾值用本仓库的 Text +
      // HyperosTypography.listDetail，不走 MiuixText），因此在这里把字重偏移
      // 下调一档即可精确还原 w400：标题最终字重 = w500 + (delta - 100)
      // = w400 + delta，仍随系统字重分级平移；startAction 是图标，不受影响。
      child: MiuixTheme(
        data: MiuixTheme.of(context).copyWith(
          fontWeightAdjustment:
              MiuixTheme.of(context).fontWeightAdjustment - 100,
        ),
        child: MiuixArrowPreference(
          startAction: startAction,
          title: title,
          // MiuixArrowPreference 会把 endActions 放进 mainAxisSize.min 的 Row，
          // 里面的 Text 拿到的是无边界宽度，值过长时会溢出而不是省略。
          // 逐个包 Flexible 让它们服从右侧受限宽度，并默认单行省略。
          endActions: _constrainEndActions(endActions),
          enabled: onClick != null,
        ),
      ),
    );
  }

  /// 把每个末尾操作包成可收缩的 [Flexible]，并让其中的 [Text] 默认单行省略，
  /// 避免超长详情值撑破 [MiuixArrowPreference] 的末尾槽位。
  List<Widget>? _constrainEndActions(List<Widget>? actions) {
    if (actions == null || actions.isEmpty) {
      return actions;
    }
    return [
      for (final action in actions)
        Flexible(
          child: DefaultTextStyle.merge(
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            child: action,
          ),
        ),
    ];
  }
}
