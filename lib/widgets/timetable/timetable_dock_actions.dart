import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/timetable_settings.dart';
import '../home_menu_catalog.dart';

/// 玻璃坞点击动作的宿主参数（2026-10-20 从 `TimetableScreen` State 搬出）。
class TimetableDockActionHost {
  final bool isDayView;
  final int visibleWeek;
  final String? dockInlinePageId;
  final ValueChanged<String?> setInlinePageId;
  final ValueChanged<TimetableSettings> onSelectionClick;
  final Future<void> Function({
    required int week,
    required int dayOfWeek,
    required TimetableSettings settings,
    required bool animate,
  })
  toggleDayView;
  final Future<void> Function(
    TimetableSettings settings, {
    required bool animate,
  })
  closeDayView;
  final int Function(TimetableSettings settings, int fallbackDayOfWeek)
  resolveStoredDayOfWeek;
  final VoidCallback persistWeekView;
  final WidgetBuilder? Function(String id) inlineDockPageFor;
  final HomeMenuEntry? Function(String id) homeMenuEntryById;
  final void Function(Future<void> Function(BuildContext) open) pushAfterGlow;

  const TimetableDockActionHost({
    required this.isDayView,
    required this.visibleWeek,
    required this.dockInlinePageId,
    required this.setInlinePageId,
    required this.onSelectionClick,
    required this.toggleDayView,
    required this.closeDayView,
    required this.resolveStoredDayOfWeek,
    required this.persistWeekView,
    required this.inlineDockPageFor,
    required this.homeMenuEntryById,
    required this.pushAfterGlow,
  });
}

/// 底栏一格被点击后的动作分派：日/周切换、内嵌页切换或推新页。
void handleTimetableDockTap(
  String id,
  TimetableSettings settings,
  TimetableDockActionHost host,
) {
  final leavingInlinePage = host.dockInlinePageId != null &&
      (id == kGlassDockActionDay || id == kGlassDockActionWeek);
  if (leavingInlinePage) {
    // 从内嵌页点视图切换：先收页再切视图，避免两层状态叠加。
    host.setInlinePageId(null);
  }
  switch (id) {
    case kGlassDockActionDay:
      if (host.isDayView) {
        // 重复点日 Tab 无动作；从内嵌页收回落回日课表是一次真实切换
        // （落回异视图的路径 toggleDayView 内部已震，此处只补同视图）。
        if (leavingInlinePage) {
          host.onSelectionClick(settings);
        }
        return;
      }
      unawaited(host.toggleDayView(
        week: host.visibleWeek,
        dayOfWeek: host.resolveStoredDayOfWeek(
          settings,
          settings.timetableLastViewedDayOfWeek,
        ),
        settings: settings,
        animate: false,
      ));
    case kGlassDockActionWeek:
      if (!host.isDayView) {
        host.persistWeekView();
        // 重复点周 Tab 无动作；从内嵌页收回落回周课表是一次真实切换。
        if (leavingInlinePage) {
          host.onSelectionClick(settings);
        }
        return;
      }
      // 闪现收起：closeDayView 内部完成震动、状态清理与持久化。
      unawaited(host.closeDayView(settings, animate: false));
    default:
      // 内嵌优先：注册过的页面在首页栈内切换，玻璃坞保持悬浮；未登记
      // 的走普通推入。再点当前内嵌页与 日/周 Tab 同口径无动作，其余均
      // 是真实切换（开页/换页/推路由），统一在此给触觉反馈。
      if (host.inlineDockPageFor(id) != null) {
        if (host.dockInlinePageId == id) {
          return;
        }
        host.setInlinePageId(id);
        host.onSelectionClick(settings);
        return;
      }
      final entry = host.homeMenuEntryById(id);
      if (entry != null) {
        host.onSelectionClick(settings);
        host.pushAfterGlow(entry.open);
      }
  }
}

/// 底栏某一格**会推新页面**时：先把玻璃药丸上的按压光斑收掉，下一帧再推。
///
/// 2026-09-25 用户口径：「点击底栏的时候会有亮光，但是亮光对应衔接这个缩小
/// 动画的时候，就会形成闪一下的样子」。那颗亮光就是药丸的按压光斑（液态玻璃
/// 的 `pressGlow`）：**进光是瞬时的，抬手后靠 140ms 渐隐**，所以抬手那一刻
/// 它正好最亮。而缩放转场的**第 0 帧**把整屏烤成快照、之后 400ms 全靠回放这
/// 张图——「最亮的那一帧」被定格进快照，光斑在整个缩小过程里一直是亮的，
/// 落定后活首页交还、光斑早已收掉 ⇒ 那一下闪。
///
/// 归零必须**早于**快照那一帧，而重绘要等下一帧，所以推页顺延一帧（16.7ms，
/// 点击手感上察觉不到）。日/周切换与内嵌页换页**不走这里**：那些是首页内部
/// 状态，光斑的渐隐就是它跟手的手感，要原样保留。
void pushAfterTimetableDockGlowSettled({
  required VoidCallback releasePressGlow,
  required bool Function() isMounted,
  required BuildContext context,
  required Future<void> Function(BuildContext) open,
}) {
  releasePressGlow();
  // ⚠️ **必须显式 `scheduleFrame`**（2026-09-25 实测）：`addPostFrameCallback`
  // 自己**不排帧**，而此刻树上已经没有别的东西会标脏（推页被推迟了、光斑归零
  // 只改渲染对象不重建）⇒ 不会有帧被画出 ⇒ 帧末回调永远不跑，推页永远不发生
  // （首版就栽在这，回归用例直接把它照出来）。先排一帧，回调才有执行时机。
  SchedulerBinding.instance.scheduleFrame();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!isMounted()) {
      return;
    }
    unawaited(open(context));
  });
}
