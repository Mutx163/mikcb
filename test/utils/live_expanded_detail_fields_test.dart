import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/live_expanded_detail_fields.dart';

void main() {
  group('liveExpandedDetailFieldsForStage', () {
    // 期望值来源：原生 LiveUpdateService.expandedDetailLineList 的渲染条件
    // （independent source：LiveUpdateService.kt 与
    // promotedExpandedDetailDefaultOrder），不是从 Dart 实现抄的。
    test('before-class page never renders stage/progress/status rows', () {
      final fields = liveExpandedDetailFieldsForStage(forDuringEnd: false);
      expect(fields, isNot(contains(LiveExpandedDetailField.stage)));
      expect(fields, isNot(contains(LiveExpandedDetailField.progress)));
      expect(fields, isNot(contains(LiveExpandedDetailField.status)));
      // 课前恒为提升态：提升态默认序去掉 stage 后剩余六字段的相对顺序。
      expect(
        fields.map((f) => f.value),
        ['time', 'location', 'teacher', 'shortName', 'next', 'note'],
      );
    });

    test('during/end page keeps all nine fields in promoted default order', () {
      final fields = liveExpandedDetailFieldsForStage(forDuringEnd: true);
      expect(fields, hasLength(LiveExpandedDetailField.values.length));
      // 提升态默认序（原生 promotedExpandedDetailDefaultOrder）+ stage 殿后
      //（stage 仅在非提升态渲染）。
      expect(
        fields.map((f) => f.value),
        [
          'progress',
          'status',
          'time',
          'location',
          'teacher',
          'shortName',
          'next',
          'note',
          'stage',
        ],
      );
    });
  });

  group('resolveExpandedDetailWorkOrder', () {
    test('null config means all visible fields on, in default order', () {
      final display = TimetableSettings.defaults().beforeClassDisplaySettings;
      final order = resolveExpandedDetailWorkOrder(
        display,
        forDuringEnd: false,
      );
      expect(
        order,
        liveExpandedDetailFieldsForStage(forDuringEnd: false),
      );
    });

    test('config entries outside the visible set are dropped', () {
      // 旧数据 / 课中页复制过来的名单可能带着 stage：课前渲染不出这一行，
      // 工作顺序必须把它剔掉，列表才与真机一致。
      final display = TimetableSettings.defaults()
          .copyWith(
            liveExpandedDetailFields: const [
              'stage',
              'time',
              'teacher',
              'note',
            ],
          )
          .beforeClassDisplaySettings;
      final order = resolveExpandedDetailWorkOrder(
        display,
        forDuringEnd: false,
      );
      expect(order.map((f) => f.value), ['time', 'teacher', 'note']);
    });

    test('fields omitted from a set config are treated as hidden', () {
      final display = TimetableSettings.defaults()
          .copyWith(liveExpandedDetailFields: const ['time', 'note'])
          .beforeClassDisplaySettings;
      final order = resolveExpandedDetailWorkOrder(
        display,
        forDuringEnd: false,
      );
      expect(order.map((f) => f.value), ['time', 'note']);
    });

    test('empty config means everything hidden (kept as explicit empty)', () {
      final display = TimetableSettings.defaults()
          .copyWith(liveExpandedDetailFields: const <String>[])
          .beforeClassDisplaySettings;
      expect(
        resolveExpandedDetailWorkOrder(display, forDuringEnd: false),
        isEmpty,
      );
    });

    test('during/end order follows config intersection, not storage enum', () {
      final display = TimetableSettings.defaults()
          .copyWith(
            // 默认跟随课前配置，先断开才能给课中页单独喂名单。
            liveDuringEndFollowBeforeClass: false,
            liveDuringEndExpandedDetailFields: const [
              'note',
              'progress',
              'time',
            ],
          )
          .duringEndDisplaySettings;
      final order = resolveExpandedDetailWorkOrder(
        display,
        forDuringEnd: true,
      );
      // 交集保留用户自定义顺序（列表顺序即行序），只是剔掉不可见字段。
      expect(order.map((f) => f.value), ['note', 'progress', 'time']);
    });
  });
}
