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
/// 本基线取搬移后的主文件行数。后续向主文件堆积被禁止；新功能应放进
/// 按功能域命名的 part 文件，或独立 widget/controller。正当增长确需上调基线时，
/// 在提交信息说明并优先考虑继续拆分（先例见 dependency_guards_test 的
/// timetable_provider 基线注释）。
void main() {
  test('timetable_screen 主文件行数棘轮：只减不增', () {
    final file = File('lib/screens/timetable_screen.dart');
    expect(file.existsSync(), isTrue, reason: '文件不存在，棘已空转');
    final lines = file.readAsLinesSync().length;
    // 2026-10-10 搬移两族后 = 8201。下一次拆分（下拉手势族 / 玻璃坞工具条 /
    // 弹出页路由族）预计可再降至 ~7000。
    const baselineLines = 8201;
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'timetable_screen.dart 继续膨胀（当前 \$lines > 基线 \$baselineLines）。'
          '新功能请放进按功能域命名的 part 文件或独立类；'
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
