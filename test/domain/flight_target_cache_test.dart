import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/timetable/flight_target_cache.dart';

/// 飞行终点缓存的**代数**语义（2026-10-23）。
///
/// 为什么这条测试重要：历史上 `FlightTargetCache.clear()` 定义了但**全仓没有
/// 一个调用点**。于是「滚动议程列表 → 关掉日视图 → 打开另一天」时，表里还留着
/// 上一轮的屏幕矩形；新那天某节课若还没量到，就会拿「同 id 课程上一次的位置」
/// 当终点 —— 卡片朝一个早已不存在的位置飞过去，落地再跳回来。
///
/// 现在改成「开一轮转场 bump 一代替换掉 clear 的职责」：读取只认当代的值。
/// 这条测试钉的就是「旧代读不到」。
void main() {
  group('代数：旧一轮的终点绝不能复用', () {
    test('bump 之后，上一轮写入的值读不到', () {
      final cache = FlightTargetCache();
      cache.bump(); // 第 1 轮
      cache.record('course-a', const Rect.fromLTWH(10, 20, 300, 80));
      expect(cache['course-a'], isNotNull);
      expect(cache.targets.keys, contains('course-a'));

      cache.bump(); // 第 2 轮（换日 / 重开转场）
      expect(
        cache['course-a'],
        isNull,
        reason: '新一轮开始时，上一轮的位置必须作废 —— 否则卡片会朝旧位置飞',
      );
      expect(
        cache.targets,
        isEmpty,
        reason: '整张表都该是「本轮已量到的」，不是「历史上量到过的」',
      );
    });

    test('同一轮里重复写入：值没变返回 false（不要每帧重建）', () {
      final cache = FlightTargetCache()..bump();
      expect(cache.record('a', const Rect.fromLTWH(0, 0, 100, 50)), isTrue);
      expect(
        cache.record('a', const Rect.fromLTWH(0.2, 0.2, 100.1, 50.1)),
        isFalse,
        reason: '亚像素级抖动不该触发重建（否则滚动一次就是几十次 setState）',
      );
      expect(
        cache.record('a', const Rect.fromLTWH(0, 40, 100, 50)),
        isTrue,
        reason: '位置真的变了要返回 true',
      );
    });

    test('新一轮第一次写入总是 true（即使与旧代值相同）', () {
      final cache = FlightTargetCache()..bump();
      const rect = Rect.fromLTWH(5, 5, 200, 60);
      expect(cache.record('a', rect), isTrue);
      cache.bump();
      expect(
        cache.record('a', rect),
        isTrue,
        reason: '新代必须重新上报，否则调用方以为「已经量过了」而不重建',
      );
    });

    test('clear 只放内存，不影响代数', () {
      final cache = FlightTargetCache()..bump();
      cache.record('a', const Rect.fromLTWH(0, 0, 10, 10));
      final generation = cache.generation;
      cache.clear();
      expect(cache.targets, isEmpty);
      expect(cache.generation, generation);
      expect(cache.record('a', const Rect.fromLTWH(0, 0, 10, 10)), isTrue);
    });
  });
}
