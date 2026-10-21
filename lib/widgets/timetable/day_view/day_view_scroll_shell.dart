import 'package:flutter/material.dart';

import '../../../models/timetable_settings.dart';
import '../../course_grid_surface_host.dart';

/// 日视图一页的滚动壳：**摘要卡吸顶 + 议程内容从它底下滑过**（2026-10-21）。
///
/// ## 为什么需要这一层
///
/// 改前是 `Column(摘要卡 / SizedBox(12) / Expanded(列表))` —— 两块彼此独立：
/// 摘要卡永远不动，列表只是它下面那块框里的滚动体，而**框的顶边比摘要卡下沿
/// 还低 12px**。内容滚到框顶就被 `Viewport` 的硬边裁掉、永远够不到卡片底下，
/// 那 12px 缝就一直是空的（用户口径：「为什么不是下面卡片直接插到顶部卡片
/// 下面，而是看到了有一定的空隙」）。
///
/// 合成一条 `CustomScrollView` 后两件事同时成立：
/// 1. 那 12px 从「两块之间的死空白」变成吸顶头**自己的下内边距**。静止时间距
///    不变（观感逐像素一致），一滑就滑进这条带子、再钻进卡片底下；
/// 2. `Viewport` 默认 `SliverPaintOrder.firstIsTop`（SDK
///    `rendering/viewport.dart`：排在前面的 sliver 画在上面），摘要卡因此真的
///    压在滚过去的卡片之上，那圈投影才有机会把卡片边缘压暗。
///
/// ## 为什么单独成文件
///
/// 这段壳的嵌套（内容 key / 玻璃 backdrop 组 / 滚动上报 / 吸顶头）纯属装配，
/// 与日视图的业务数据无关。留在 `timetable_day_view_part.dart` 里只会让那个
/// 已经卡在行数棘轮上的 part 继续膨胀 —— `god_file_unit_guard_test` 盯的就是
/// 这件事，它的原话是「新功能请放进独立 widget/controller」。
///
/// ## 这里**没有**任何渐隐 / 遮罩（刻意的）
///
/// 卡片着色器输出 alpha 恒为 1（`shaders/course_card_glass.frag`：卡内
/// `coverage` = 1），被盖住的像素本来就看不见，不需要淡出；而 `Opacity` /
/// `ShaderMask` 会把子树搬进独立离屏层，实时磨砂就采不到身后内容了
/// （`CourseSurface` 的类注释铁律，`glass_no_hostile_wrapper_test` 守着它）。
/// 所以这条壳全程零遮罩 —— 玻璃观感零风险。
class TimetableDayViewScrollShell extends StatelessWidget {
  /// 整页内容的身份 key（`day-content-<week>-<day>`）。
  final Key contentKey;

  /// 滚动区域的身份 key（`day-column-<week>-<day>`）。
  ///
  /// 必须罩住**整块**滚动区域：既有测试拿它取中点来起下拉手势
  ///（`home_pull_quick_import_gate_test`），落在吸顶头上就拉不动了。
  final Key columnKey;

  /// 摘要卡（吸顶）。它的**下内边距就是**摘要卡与议程内容之间的呼吸间距。
  final Widget summary;

  /// 议程内容，按 sliver 给（有课天是列表、空白天是一个占满剩余高度的块）。
  final List<Widget> slivers;

  /// 这块滚动体的 key 字符串（`day-agenda-<week>-<day>`），同时用作
  /// `PageStorageKey` 与滚动上报的索引 —— 预览那套按它起步。
  final String scrollKey;

  final ScrollController? controller;
  final ScrollPhysics physics;
  final TimetableSettings settings;

  /// 把纵向滚动位置报给宿主（缩尺预览用）。原样透传，本组件不解释它。
  final Widget Function(String key, Widget child) reportScroll;

  const TimetableDayViewScrollShell({
    super.key,
    required this.contentKey,
    required this.columnKey,
    required this.summary,
    required this.slivers,
    required this.scrollKey,
    required this.controller,
    required this.physics,
    required this.settings,
    required this.reportScroll,
  });

  /// 摘要卡与议程内容之间的呼吸间距（改前是两块之间的 `SizedBox(12)`）。
  static const double headerBreathing = 12;

  /// 摘要卡左右内缩（与议程卡同宽，卡片宽度不因吸顶而变化）。
  static const double sideInset = 14;

  @override
  Widget build(BuildContext context) {
    // `CourseGridSurfaceHost` 要罩住摘要卡**与**列表两者：它提供玻璃卡的
    // 共享 backdrop 组，只罩列表会让摘要卡掉出组外、多一份壁纸采样。
    return KeyedSubtree(
      key: contentKey,
      child: CourseGridSurfaceHost(
        settings: settings,
        child: reportScroll(
          scrollKey,
          KeyedSubtree(
            key: columnKey,
            child: CustomScrollView(
              // 与改前同一个滚动 key：`PageStorage` 的存档与预览那套
              //（`_previewControllerFor`）都还认这一串。
              key: PageStorageKey<String>(scrollKey),
              controller: controller,
              physics: physics,
              slivers: [
                PinnedHeaderSliver(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      sideInset,
                      0,
                      sideInset,
                      headerBreathing,
                    ),
                    child: summary,
                  ),
                ),
                ...slivers,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
