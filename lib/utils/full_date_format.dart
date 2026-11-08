// `yyyy-MM-dd` 的日期展示口径（本地时间，不补时区）。
//
// 单独成文件的原因：设置域逻辑单元有行数棘轮（god_file_unit_guard_test.dart，
// 只减不增）；这种无状态格式化不该继续占该域的额度。
String formatFullDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
