import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/lan_edit_api_handlers.dart';

/// 2026-10-08 审核实测：局域网编辑入口直接拿**对端发来的**周数去构造，
/// 跳过了 `TimetableSettings.fromJson` 里的 `_atLeastOneWeek`（下界 1），
/// 于是「学期周数至少为 1」这道护栏在这条路上形同虚设 ——
/// 对端发 `{"semesterWeekCount": 0}` 就能把 0 写进课表，
/// 而 `List.generate(_atLeastOneWeek(n))`（`timetable_settings.dart:3629`）
/// 随后会按 0 生成，与存下来的值互相矛盾。
///
/// 上界同样要兜：`List.generate` 按周数生成整表，给个 10^9 是一次 OOM。
///
/// 直接打生产里那个收敛函数（`visibleForTesting` 暴露），
/// 不在测试里复刻一份算术 —— 复刻只会证明复刻本身是对的。
void main() {
  int safe(Object? raw) => LanEditApiHandlers.safeSemesterWeekCountForTesting(raw);

  test('对端发 0 → 钳到 1，不会把 0 写进课表', () {
    expect(safe(0), 1);
  });

  test('对端发负数 → 钳到 1', () {
    expect(safe(-5), 1);
  });

  test('对端发字符串 "20" → 不抛，退回默认 20', () {
    // 原先是 `as int?`：遇到字符串抛 TypeError，一次合法请求被打成 500。
    expect(safe('20'), 20);
  });

  test('对端发 1e9 → 钳到上限 60（List.generate 的上界兜底）', () {
    expect(safe(1000000000), 60);
  });

  test('对端发浮点 16.9 → 取整 16', () {
    expect(safe(16.9), 16);
  });

  test('正常值原样通过', () {
    expect(safe(16), 16);
  });

  test('缺字段 / null → 默认 20', () {
    expect(safe(null), 20);
  });

  test('类型完全不对（Map/List/bool）→ 默认 20', () {
    expect(safe(<String, dynamic>{}), 20);
    expect(safe(<int>[1, 2]), 20);
    expect(safe(true), 20);
  });

  test('上界正好等于 60 时原样通过', () {
    expect(safe(60), 60);
  });

  test('下界正好等于 1 时原样通过', () {
    expect(safe(1), 1);
  });
}