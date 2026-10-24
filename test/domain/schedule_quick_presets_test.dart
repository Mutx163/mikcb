import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/schedule_quick_presets.dart';
import 'package:university_timetable/utils/course_color_palette.dart';

/// 快捷日程模板的纯逻辑测试：数据表自洽 + 时刻换算的边界。
///
/// 期望值全部由人按「一天里塞得下 / 塞不下」推出来，不是从实现里抄的。
/// 组件层的选中态/文案联动在 `test/domain/schedule_quick_preset_rail_*`
/// 之外另测（见 `test/l10n/schedule_preset_localizer_test.dart`）。
void main() {
  group('模板表自洽', () {
    test('id 唯一（重复 id 会让取消套用认错卡）', () {
      final ids = kScheduleQuickPresets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复 id：$ids');
    });

    test('每条时长都是正的，且不超过一天', () {
      for (final preset in kScheduleQuickPresets) {
        expect(
          preset.durationMinutes,
          greaterThan(0),
          reason: '${preset.id} 时长为 0 或负数，套用后是零长度日程',
        );
        expect(
          preset.durationMinutes,
          lessThanOrEqualTo(24 * 60),
          reason: '${preset.id} 超过一整天，模板必然落到钳制分支',
        );
      }
    });

    test('颜色都取自快捷色板（否则「外观」卡上会显示成没选中）', () {
      final palette = kCourseColorQuickPickHexes.toSet();
      for (final preset in kScheduleQuickPresets) {
        expect(
          palette.contains(preset.colorHex),
          isTrue,
          reason:
              '${preset.id} 的颜色 ${preset.colorHex} 不在 kCourseColorQuickPickHexes 里，'
              '套用后外观卡那一行没有任何一颗是选中态',
        );
      }
    });

    test('颜色两两不同（同色的卡在可选态里分不出谁是谁）', () {
      final colors = kScheduleQuickPresets.map((p) => p.colorHex).toList();
      expect(colors.toSet().length, colors.length);
    });

    test('byId 命中已有 id、未知 id 返回 null', () {
      expect(scheduleQuickPresetById('groupMeeting')?.durationMinutes, 60);
      expect(scheduleQuickPresetById('no-such-preset'), isNull);
    });
  });

  group('resolveSchedulePresetWindow：当天塞得下', () {
    test('09:00 + 60 分钟 = 09:00–10:00', () {
      final w = resolveSchedulePresetWindow(
        startMinutes: 9 * 60,
        durationMinutes: 60,
      );
      expect(w.startMinutes, 540);
      expect(w.endMinutes, 600);
    });

    test('开始时刻原样保留（模板不挪用户已选的时间）', () {
      final w = resolveSchedulePresetWindow(
        startMinutes: 14 * 60 + 35,
        durationMinutes: 90,
      );
      expect(w.startMinutes, 14 * 60 + 35);
      expect(w.endMinutes, 14 * 60 + 35 + 90);
    });

    test('结束恰好压在 23:59 也算塞得下，不走前移分支', () {
      // 22:59 + 60 = 23:59，正好是当天最后一分钟。
      final w = resolveSchedulePresetWindow(
        startMinutes: 22 * 60 + 59,
        durationMinutes: 60,
      );
      expect(w.startMinutes, 22 * 60 + 59);
      expect(w.endMinutes, 23 * 60 + 59);
    });
  });

  group('resolveSchedulePresetWindow：当天塞不下 → 整段前移', () {
    test('23:00 + 120 分钟：前移到 21:59–23:59，时长仍是 2 小时', () {
      final w = resolveSchedulePresetWindow(
        startMinutes: 23 * 60,
        durationMinutes: 120,
      );
      expect(w.endMinutes, 23 * 60 + 59, reason: '结束不能越过当天最后一分钟');
      expect(
        w.endMinutes - w.startMinutes,
        120,
        reason: '时长必须保真——把尾巴压平等于模板没套上',
      );
      expect(w.startMinutes, 21 * 60 + 59);
    });

    test('塞不下的位置比原来早（用户能看见开始时刻被前移）', () {
      final w = resolveSchedulePresetWindow(
        startMinutes: 23 * 60 + 30,
        durationMinutes: 90,
      );
      expect(w.startMinutes, lessThan(23 * 60 + 30));
      expect(w.endMinutes, 23 * 60 + 59);
      expect(w.endMinutes - w.startMinutes, 90);
    });

    test('结束永远晚于开始（同一天保存不会被「结束须晚于开始」拦下）', () {
      // 扫一遍当天的开始时刻 × **模板表里真实存在的每一种时长**，都不能出现
      // end <= start。时长取自数据表而不是手写一份常量：表里加一条新模板
      // （比如 300 分钟的工作坊），这个探针自动把它纳入。
      final durations = <int>{
        for (final preset in kScheduleQuickPresets) preset.durationMinutes,
        // 再补几个表里没有的边界值，防止将来换成极端时长时漏测。
        1, 240, 600,
      };
      for (var start = 0; start < 24 * 60; start += 7) {
        for (final duration in durations) {
          final w = resolveSchedulePresetWindow(
            startMinutes: start,
            durationMinutes: duration,
          );
          expect(
            w.endMinutes,
            greaterThan(w.startMinutes),
            reason: 'start=$start duration=$duration 算出了倒挂区间 '
                '${w.startMinutes}→${w.endMinutes}',
          );
          expect(w.startMinutes, inInclusiveRange(0, 23 * 60 + 59));
          expect(w.endMinutes, inInclusiveRange(0, 23 * 60 + 59));
        }
      }
    });
  });

  group('resolveSchedulePresetWindow：脏输入兜底', () {
    test('负数开始时刻夹到 00:00', () {
      final w = resolveSchedulePresetWindow(
        startMinutes: -30,
        durationMinutes: 60,
      );
      expect(w.startMinutes, 0);
      expect(w.endMinutes, 60);
    });

    test('超过一天的开始时刻夹到 23:59', () {
      final w = resolveSchedulePresetWindow(
        startMinutes: 25 * 60,
        durationMinutes: 60,
      );
      expect(w.startMinutes, inInclusiveRange(0, 23 * 60 + 59));
      expect(w.endMinutes, 23 * 60 + 59);
    });

    test('时长为 0 或负数时退化成零长度区间，不返回倒挂', () {
      for (final duration in [0, -60]) {
        final w = resolveSchedulePresetWindow(
          startMinutes: 9 * 60,
          durationMinutes: duration,
        );
        expect(w.startMinutes, 540);
        expect(w.endMinutes, 540, reason: 'duration=$duration 产生了一段长度');
      }
    });
  });
}
