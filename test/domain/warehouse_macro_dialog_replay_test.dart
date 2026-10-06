import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_macro_dialog_replay.dart';

/// 宏回放时把「录制的选项文字」还原成「脚本要的序号」。
///
/// 这条守的是一次真机故障：录制导入跑到单选弹窗，弹窗刚出现 10 毫秒就返回取消，
/// 用户看到的是「点完确认立刻变成导入已取消」。根因是宿主录制时按**文字**存、
/// 回放时按**文字**回，而脚本按**序号**解析。
void main() {
  const terms = ['2026-2027-1（当前学期）', '2027-2028-1', '2026-2027-2', '2025-2026-2'];
  const campus = ['永川校区', '巴南校区'];

  group('resolveRecordedSelectionIndex', () {
    test('回放回文字时还原成下标', () {
      expect(
        resolveRecordedSelectionIndex(
          recorded: '2026-2027-1（当前学期）',
          options: terms,
          fallbackIndex: 2,
        ),
        0,
      );
      expect(
        resolveRecordedSelectionIndex(
          recorded: '2025-2026-2',
          options: terms,
          fallbackIndex: 2,
        ),
        3,
      );
      expect(
        resolveRecordedSelectionIndex(
          recorded: '巴南校区',
          options: campus,
          fallbackIndex: 0,
        ),
        1,
      );
    });

    test('回放回序号时原样使用（含宿主包成字符串的情况）', () {
      expect(
        resolveRecordedSelectionIndex(recorded: 0, options: terms, fallbackIndex: 3),
        0,
      );
      // 宿主回放时可能把值包成字符串；`0 == '0'` 在 Dart 里是 false，
      // 所以文字相等那条路必须先 tryParse，否则这里会掉到 fallback。
      expect(
        resolveRecordedSelectionIndex(recorded: '3', options: terms, fallbackIndex: 0),
        3,
      );
    });

    test('文字前后有空格也认（回放经过 JSON 往返时的常见形状）', () {
      expect(
        resolveRecordedSelectionIndex(
          recorded: '  巴南校区  ',
          options: campus,
          fallbackIndex: 0,
        ),
        1,
      );
    });

    test('录制的答案已过期时退回脚本给的默认值，而不是判成取消', () {
      // 选项列表变了（学校加了新学期 → 当前学期顶到第一位，旧宏记的还是老位置）。
      // 判成取消的话用户看到的是「刚点确认就被取消」，完全无从下手。
      expect(
        resolveRecordedSelectionIndex(
          recorded: '2025-2026-2',
          options: ['2027-2028-1', '2026-2027-2', '2026-2027-1', '2025-2026-2'],
          fallbackIndex: 0,
        ),
        3,
      );
      expect(
        resolveRecordedSelectionIndex(
          recorded: '已经不存在的选项',
          options: terms,
          fallbackIndex: 2,
        ),
        2,
      );
    });

    test('没有录制答案时用脚本给的默认值', () {
      expect(
        resolveRecordedSelectionIndex(
          recorded: null,
          options: terms,
          fallbackIndex: 1,
        ),
        1,
      );
    });

    test('越界与非法值不静默变成某一票', () {
      expect(
        resolveRecordedSelectionIndex(
          recorded: 99,
          options: terms,
          fallbackIndex: 0,
        ),
        0,
        reason: '越界序号不是有效答案，按「没有答案」处理',
      );
      expect(
        resolveRecordedSelectionIndex(
          recorded: 99,
          options: terms,
          fallbackIndex: -1,
        ),
        isNull,
        reason: '连默认值都越界时只能返回 null，交给调用方按取消处理',
      );
      expect(
        resolveRecordedSelectionIndex(
          recorded: 1.5,
          options: terms,
          fallbackIndex: 0,
        ),
        0,
      );
    });
  });
}
