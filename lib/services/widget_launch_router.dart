import 'package:flutter/material.dart';

import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import 'home_widget_binding_service.dart';
import 'partner_timetable_service.dart';

enum WidgetLaunchOutcome {
  /// 无 pending 点击，或卡片未绑定（跟随当前课表）→ 普通打开。
  none,

  /// 已切到卡片绑定的普通课表。
  switchedProfile,

  /// 已打开情侣覆盖层（绑定的是 TA 课表或情侣课表合并视图；不真的切过去——
  /// 考试提醒、超级岛等都挂在「当前课表」上，switchProfile 明确禁止切到
  /// TA 课表）。
  partnerOverlay,

  /// 绑定的 TA 课表已解绑/被删（或情侣课表已无 TA 数据）→ 回落普通打开。
  bindingMissing,
}

/// 桌面卡片分流需要的课表窄面（端口由消费方定义）。
///
/// 本文件在 services 层，不反向 import `providers/timetable_provider.dart`：
/// 分流真正需要的只有「初始化 / 情侣绑定判定 / 读设置 / 写设置 / 切课表」
/// 六个成员。宿主适配器 `WidgetLaunchProviderAccess` 见
/// `lib/providers/widget_launch_timetable_access.dart`，由调用点（main.dart、
/// 测试）构造注入。
abstract class WidgetLaunchTimetable {
  Future<void> initialize();

  bool get hasPartnerBinding;

  TimetableProfile? get partnerProfile;

  TimetableSettings get settings;

  Future<String?> updateTimetableSettings(TimetableSettings settings);

  Future<void> switchProfile(String profileId);
}

/// 桌面卡片点击 → App 内分流。
///
/// 原生把卡片点击（带 appWidgetId）作为 pending 递给 Flutter（冷启动由
/// 启动流程 drain，热启动经 miui_live 通道 onWidgetLaunchReceived 通知），
/// 这里按该卡片的绑定档案分流：
/// - 普通课表 → `switchProfile` 直达
/// - TA 课表 / 情侣课表（合并视图哨兵）→ 保持当前课表，只打开情侣覆盖层
/// - 未绑定 / 绑定已失效 → 与现在一样普通打开
class WidgetLaunchRouter {
  const WidgetLaunchRouter._();

  /// 热启动时课表页监听：外部入口请求显示情侣覆盖层的信号。
  /// 路由器会先把持久化设置置 true（覆盖冷启动路径），再 bump 此计数；
  /// 课表页只在「本地状态与持久化值发散」时跟随，避免与页内开关竞态。
  static final ValueNotifier<int> coupleOverlayRequestTick = ValueNotifier(0);

  static Future<WidgetLaunchOutcome> handle(
    BuildContext context, {
    required WidgetLaunchTimetable timetable,
  }) {
    return handleWith(
      timetable: timetable,
      onRequestPopToRoot: context.mounted
          ? () => Navigator.of(context).popUntil((route) => route.isFirst)
          : null,
    );
  }

  /// 分流核心：与 BuildContext 解耦，便于纯异步测试。
  /// [onRequestPopToRoot] 在「需要让覆盖层可见」时回调（覆盖层显示在
  /// 课表首页上；从深层页面进来时先回到根路由）。
  static Future<WidgetLaunchOutcome> handleWith({
    required WidgetLaunchTimetable timetable,
    HomeWidgetBindingService bindingService = const HomeWidgetBindingService(),
    void Function()? onRequestPopToRoot,
  }) async {
    final appWidgetId = await bindingService.consumePendingWidgetLaunch();
    if (appWidgetId == null) {
      return WidgetLaunchOutcome.none;
    }
    await timetable.initialize();

    final boundProfileId = await bindingService.getWidgetBinding(appWidgetId);
    if (boundProfileId == null) {
      return WidgetLaunchOutcome.none;
    }

    final isPartnerViewBinding = boundProfileId ==
        PartnerTimetableService.partnerProfileId ||
        boundProfileId == kHomeWidgetCoupleMergedBindingId;
    if (isPartnerViewBinding) {
      if (!timetable.hasPartnerBinding || timetable.partnerProfile == null) {
        return WidgetLaunchOutcome.bindingMissing;
      }
      if (!timetable.settings.coupleTimetableOverlayEnabled) {
        await timetable.updateTimetableSettings(
          timetable.settings.copyWith(coupleTimetableOverlayEnabled: true),
        );
      }
      onRequestPopToRoot?.call();
      coupleOverlayRequestTick.value++;
      return WidgetLaunchOutcome.partnerOverlay;
    }

    // switchProfile 自带守卫：课表不存在 / 是 TA 课表时静默不动。
    await timetable.switchProfile(boundProfileId);
    return WidgetLaunchOutcome.switchedProfile;
  }
}
