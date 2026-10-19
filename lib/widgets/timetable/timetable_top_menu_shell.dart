import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../ui/hyperos/hyperos.dart';
import '../home_menu_catalog.dart';
import '../home_top_menu.dart';
import '../home_top_menu_popup.dart';

/// 列表态菜单里「分享课表」的入口 id。
///
/// 目录里同一个 id 有通用条目（`home_menu_catalog.dart`），但分享要带上
/// 「当前可见周」与「当前是周/日视图」，只有首页知道，必须由宿主拦下来分发。
const String _kShareTimetableEntryId = 'shareTimetable';

/// 首页主体 + 顶栏「更多」玻璃弹层的宿主外壳。
///
/// 2026-10-19 从 `timetable_screen.dart` 的 `_wrapHomeWithTopMenu` 搬出。
/// 首页整屏都包在 [HyperosGlassBackdropHost] 里：玻璃坞 / 首页玻璃带 / 分区
/// 玻璃 / 弹层都从它取采样源渲染 OS4 玻璃；宿主同时注册进
/// `HyperosGlassBackdropRegistry`，于是压在首页之上的 sheet / dialog 里的玻璃
/// 也能采到首页画面（modal 路由看不到首页的 InheritedWidget）。
///
/// 本 widget 只摆位置、不持有状态：开合、锚点、条目、更新红点全部由调用方
/// 通过 props 注入；`glassController` 由调用方持有并负责 dispose。
class TimetableHomeTopMenuShell extends StatelessWidget {
  const TimetableHomeTopMenuShell({
    super.key,
    required this.content,
    required this.glassController,
    required this.showMenu,
    required this.anchor,
    required this.anchorContent,
    required this.entries,
    required this.hasAvailableUpdate,
    required this.onDismissRequest,
    required this.onSelected,
    required this.onDismissFinished,
    this.dockLayer,
    this.chromeBalls = const <Widget>[],
  });

  /// 首页正文（不含任何玻璃层）。
  final Widget content;

  /// 首页采样源控制器。
  final HyperosGlassBackdropController glassController;

  /// 列表态菜单是否展开。
  final bool showMenu;

  /// 弹层形变动画的锚点（扣在「更多」按钮上）。
  final MiuixGlassPopupAnchor anchor;

  /// 弹层动画期间显示的锚点内容（与常驻球**共用同一份**可见内容，
  /// 含更新红点与同一墨色，见调用方说明）。
  final Widget anchorContent;

  /// 当前排布下的菜单条目。
  final List<HomeMenuEntry> entries;

  /// 是否有可用更新（决定「更新」条目的点状角标）。
  final bool hasAvailableUpdate;

  final VoidCallback onDismissRequest;

  final ValueChanged<String> onSelected;

  /// 弹层退场动画真正结束（面板已摘除、锚点图标已交还）。
  final VoidCallback? onDismissFinished;

  /// 玻璃坞（药丸 + 圆钮）层；为 null 时不渲染。
  final Widget? dockLayer;

  /// 常驻玻璃球（可空列表）。
  final List<Widget> chromeBalls;

  @override
  Widget build(BuildContext context) {
    final dock = dockLayer;
    return Stack(
      fit: StackFit.expand,
      children: [
        HyperosGlassBackdropHost(controller: glassController, child: content),
        // ⚠️ 玻璃坞（药丸 + 圆钮）同样画在宿主**之外** —— 与下面那两颗常驻球
        // 同一条规则，理由也一样：宿主捕获的是"玻璃之下的页面"，捕获子树不能含
        // 玻璃自身。坞层原先长在宿主子树末尾，于是每次录帧都把它自己的画面烘进
        // 快照，坞层再拿这张"含自己"的图算材质 —— 展开 / 收起内嵌页那几帧里
        // 圆钮的明暗会颤几下才收敛（真机反馈：「圆钮展开收起之后闪」）。
        //
        // ⚠️ 必须同时用 [HyperosGlassBackdropScope] 把坞层钉在本屏采样源上：
        // 它在宿主之外拿不到宿主下发的 scope，只能靠全局注册表"栈顶"取采样源，
        // 而栈顶会随 push / pop 换人（与常驻球完全同一处境，见下面的说明）。
        if (dock != null)
          Positioned.fill(
            child: HyperosGlassBackdropScope(
              controller: glassController,
              child: dock,
            ),
          ),
        // 常驻玻璃球画在宿主**之外**（不自采样）；整屏 IgnorePointer 让点击
        // 穿透到下面的真实按钮。
        //
        // ⚠️ 必须同时用 [HyperosGlassBackdropScope] **把球钉在本屏采样源上**：
        // 球在宿主之外，拿不到宿主下发的 scope，只能靠全局注册表"栈顶"取采样源
        // —— 而栈顶会随 push / pop 换人（设置页自己的采样源会顶上来），页面回来
        // 后球还绑在别人的（已释放的）采样源上，就只剩半套材质、另一半回落实底
        // （真机反馈："进设置再回来，爱心变成一半一半透明的、一半是实底"）。
        // 与页内玻璃同一个口径：**本屏的玻璃只采本屏的画面**。
        if (chromeBalls.isNotEmpty)
          Positioned.fill(
            child: HyperosGlassBackdropScope(
              controller: glassController,
              child: IgnorePointer(child: Stack(children: chromeBalls)),
            ),
          ),
        // ⚠️ 菜单的动画必须**不受"本页是否在前台"影响**：`Overlay` 会给被不透明
        // 路由盖住、但仍 `maintainState` 的那一层整体加 `TickerMode(enabled:
        // false)`（`overlay.dart` 的 `_Theater` 构建），而菜单的动画计时器挂在
        // 本页子树下 —— 于是"点菜单项 → 关菜单 + 跳新页面"同时发生时，收起动画
        // 会被当场静音、**卡在半透明状态**（真机反馈："跳转前那一刻菜单变成
        // 透明的"）。菜单是浮层级的瞬时动画，显式放开 TickerMode。
        TickerMode(
          enabled: true,
          child: HomeTopMenuPopup(
            show: showMenu,
            backdrop: glassController.backdrop,
            anchor: anchor,
            anchorContent: anchorContent,
            entries: entries,
            hasAvailableUpdate: hasAvailableUpdate,
            onDismissRequest: onDismissRequest,
            onSelected: onSelected,
            onDismissFinished: onDismissFinished,
          ),
        ),
      ],
    );
  }
}

/// 顶栏菜单里六项「宿主专属」动作的启动器。
///
/// 这些动作依赖首页上下文（当前可见周、日视图选中日期、读 provider 后的时间
/// 方案、版本检查、分享快照），不适合放进通用目录条目，所以由调用方注入。
class TimetableTopMenuLaunchers {
  const TimetableTopMenuLaunchers({
    required this.openAddCoursePicker,
    required this.openCourseForm,
    required this.openScheduleForm,
    required this.openExamForm,
    required this.openUpdate,
    required this.shareTimetable,
  });

  /// 八宫格形态与未知 id 的兜底：打开添加课程三宫格弹层。
  final Future<void> Function() openAddCoursePicker;

  /// `addCourse:course`：带当前可见周与日视图选中日期进添加课程页。
  final Future<void> Function() openCourseForm;

  /// `addCourse:schedule`：进添加日程页。
  final Future<void> Function() openScheduleForm;

  /// `addCourse:exam`：进添加考试页。
  final Future<void> Function() openExamForm;

  /// `update`：先做版本检查再进更新详情。
  final Future<void> Function() openUpdate;

  /// `shareTimetable`：带当前可见周与周/日视图分享课表图。
  final Future<void> Function() shareTimetable;
}

/// 顶栏菜单选中项分发：八宫格底部弹层与列表（OS4 玻璃弹层）两种形态共用入口。
///
/// 只做「按 id 选启动器」，不碰菜单开合时序 —— 「先收菜单、收完再执行」由
/// 调用方在调用本函数**之前**完成（见 `_dispatchTopMenuSelection`）。
Future<void> dispatchTimetableTopMenuSelection(
  BuildContext context,
  String selectedId,
  TimetableTopMenuLaunchers launchers,
) async {
  switch (selectedId) {
    // 这六项依赖首页宿主上下文：添加课程要带周次/日期，更新入口要先做版本
    // 检查再进详情页，分享要带当前可见周与周/日视图。其余全部走目录分发。
    case kAddCourseSubmenuParentId:
      await launchers.openAddCoursePicker();
    case kAddCourseSubmenuCourseId:
      await launchers.openCourseForm();
    case kAddCourseSubmenuScheduleId:
      await launchers.openScheduleForm();
    case kAddCourseSubmenuExamId:
      await launchers.openExamForm();
    case kUpdateEntryId:
      await launchers.openUpdate();
    case _kShareTimetableEntryId:
      await launchers.shareTimetable();
    default:
      final entry = homeMenuEntryById(selectedId);
      if (entry != null) {
        await entry.open(context);
      }
  }
}
