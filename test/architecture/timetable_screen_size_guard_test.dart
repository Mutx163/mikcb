import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 架构棘：`timetable_screen.dart` 行数只减不增（2026-10-10 立）。
///
/// 该文件是全仓最大、改动最频繁的业务文件（近 90 天 244 次提交），长期无任何
/// 规模护栏。2026-10-10 已把「版本更新下载族」与「日视图议程族」两个功能域
/// 原样搬入 part 文件（extension 形态，行为零变化）：
/// - `timetable_update_download_part.dart`
/// - `timetable_day_view_part.dart`
///
/// 本棘轮只量主文件；「把代码搬进 part」不算瘦身 —— 逻辑单元总量、part 数量
/// 与 provider 分片的宿主私有访问数由 `god_file_unit_guard_test.dart` 另守。
/// 新功能应放进独立 widget/controller，part 只作零行为搬迁的过渡。
/// 正当增长确需上调基线时，在提交信息说明并优先考虑继续拆分（先例见
/// dependency_guards_test 的 timetable_provider 基线注释）。
void main() {
  test('timetable_screen 主文件行数棘轮：只减不增', () {
    final file = File('lib/screens/timetable_screen.dart');
    expect(file.existsSync(), isTrue, reason: '文件不存在，棘已空转');
    final lines = file.readAsLinesSync().length;
    // 2026-10-10 搬移两族后 = 8201；2026-10-14 审核修复 +13 → 8214。
    // 2026-10-19 按真实值收紧到 8156；同日再把首页物理/空位标记/弹层路由
    // 搬进 widgets/timetable/，并清掉 2 个失效 import 与 5 个尾部空行，
    // 主文件降到 7693；随后星期栏指示条（净 -121）、回本周浮钮（净 -160）、
    // 回今日浮钮（净 -142）、星期栏本体（净 -310）、玻璃坞（净 -291）、
    // 剩余库级类（净 -169）、build 期 chrome 解析（净 -126）、顶栏 chrome
    // 构建（净 -49）先后搬出 → 6325。
    // 2026-10-19 晚：拆 models↔l10n 唯一真循环，本文件仅 +1 行 import
    // （course_week_localizations 的 CourseWeekDescriptions 扩展），
    // 属「换依赖方向」而非功能增长，按规矩说明后基线 6325 → 6326。
    // 深夜 M4-B：星期栏墨色弹层、切换课表弹层、顶栏玻璃菜单外壳、课程操作
    // sheet 族先后搬出（净 -550）→ 5776。
    // M5-A：首页下拉药丸、情侣空闲摘要、周页滚动壳搬出（净 -411）→ 5365。
    // M5-A2：build 期首页栈（壁纸/玻璃带/顶栏）与周网格日列搬出（净 -260）
    // → 5105。
    // M5-A3：周 pager 与玻璃坞/内嵌页外壳搬出（净 -151）→ 4954。
    // M5-A4：周页与周网格骨架搬出（净 -165）→ 4789。
    // M5-A5：首页下拉 surface（含 pager 装配）搬出（净 -60）→ 4729。
    // M5-A6：情侣日课表条目组装下沉 domain（净 -91）→ 4638。
    // M5-A7：日视图锚点展开壳搬出（净 -55）→ 4583。
    // M5-A8：壁纸亮度采样控制器搬出（净 -227）→ 4356。
    // 下一次目标（下拉/日视图转场控制器）预计可再降至 ~4100。
    const baselineLines = 4356;
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'timetable_screen.dart 继续膨胀（当前 \$lines > 基线 \$baselineLines）。'
          '新功能请放进独立 widget/controller；不要再往 part 里摊。'
          '若确属正当增长，请先做一次等量拆分再同步本基线，并在提交信息说明。',
    );
  });

  test('棘不是空转：part 文件确实存在且非空', () {
    for (final part in [
      'lib/screens/timetable_update_download_part.dart',
      'lib/screens/timetable_day_view_part.dart',
    ]) {
      final f = File(part);
      expect(f.existsSync(), isTrue, reason: '\$part 不存在');
      expect(
        f.readAsLinesSync().length,
        greaterThan(50),
        reason: '\$part 小于 50 行，搬移可能被整体撤销而未同步本棘',
      );
    }
  });
}
