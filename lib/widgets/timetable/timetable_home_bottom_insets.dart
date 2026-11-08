// 首页底部避让的常量与纯计算。
//
// 单独成文件的原因：`timetable_screen.dart` 与它的日视图 part 合起来算一个
// 「逻辑单元」，行数棘轮只减不增（god_file_unit_guard_test.dart）；这类纯几何
// 计算不该继续占该单元的额度，功能增长一律落到独立文件。
import 'dart:math' as math;

/// 首页内容与底部障碍（药丸 / 浮钮）之间额外留出的一小段呼吸间隙。
///
/// 避让量本身只等于障碍的物理占用：不加这一段，滑到底时最后一项的底边正好
/// 压在药丸顶边上（周网格更是无缝贴住），远看像内容被切掉一角。留一段空白，
/// 「滑到底」才读得成自然停靠。
const double kHomeBottomBreathingGap = 12;

/// 列表最后一项与「回今日」浮钮顶边之间的视觉间隙（同样含呼吸间隙）。
const double kBackToTodayButtonGap = kHomeBottomBreathingGap;

/// 首页内容（周网格 / 日议程）的底部避让量 = 坞物理占用 + 呼吸间隙。
///
/// 与坞内嵌页的避让分开：内嵌页是一整段列表，多留的空隙会改变它的段落节奏；
/// 首页要「滑到底时最后一项不着落在药丸顶边上」，才加这一段。经典形态
/// （避让为 0）不加：页面底部本来就不被底栏遮挡。
double homeBottomScrollInset(double dockInset) =>
    dockInset <= 0 ? dockInset : dockInset + kHomeBottomBreathingGap;

/// 日课表列表为「回今日」浮钮留出的底部滚动余量。
///
/// 与玻璃坞避让叠加使用：坞避让负责「别被药丸盖住」，这里补「别被浮钮盖住」
/// 的那一段（浮钮比药丸高出的间隙 + 钮高 + 一个视觉间隙）。浮钮不显示时返回
/// 0——不为一颗看不见的按钮白留一条空白，也不改变今天那天的滚动手感。
double backToTodayScrollInset({
  required bool buttonVisible,
  required double buttonTop,
  required double homeInset,
}) {
  if (!buttonVisible) {
    return 0;
  }
  return math.max(0, buttonTop + kBackToTodayButtonGap - homeInset);
}
