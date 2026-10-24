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

  group('反向换代保留兜底：不闪空帧（2026-10-24 补）', () {
    test('keepFallback=true 时旧终点仍可读；硬换代则读不到', () {
      final cache = FlightTargetCache();
      cache.bump();
      cache.record('c1', const Rect.fromLTWH(10, 100, 364, 120));
      expect(cache.targets, hasLength(1));

      // 中途反向：保留兜底 ⇒ 立刻仍有终点可用（不会闪一帧「一张卡都不飞」）
      cache.bump(keepFallback: true);
      expect(
        cache['c1'],
        isNotNull,
        reason: '反向必须保留旧终点作兜底。作废的话，那一帧 endRects 全空 + '
            '面板高度 0 ⇒ 整屏只剩周网格，闪一下。',
      );
      expect(cache.targets, hasLength(1));

      // 新一轮真的量到之后，当代值覆盖兜底
      cache.record('c1', const Rect.fromLTWH(10, 40, 364, 120));
      expect(cache['c1']!.top, 40, reason: '当代值必须覆盖兜底');

      // 正向换日：硬作废（旧位置属于另一天，硬用会飞错地方）
      cache.bump();
      expect(
        cache['c1'],
        isNull,
        reason: '正向换代必须硬作废：旧矩形属于另一天，沿用会让卡片飞向错误位置',
      );
      expect(cache.targets, isEmpty);
    });

    test('兜底不会跨过两次硬换代残留', () {
      final cache = FlightTargetCache();
      cache.bump();
      cache.record('c1', const Rect.fromLTWH(1, 1, 1, 1));
      cache.bump(keepFallback: true); // 反向
      cache.bump(); // 又一次正向硬换代
      expect(cache['c1'], isNull, reason: '硬换代必须把兜底也清掉');
    });
  });
}
