import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/luminance_sample_gate.dart';

/// 壁纸亮度采样的限次重试闸门（2026-10-08）。
///
/// 三处采样（首页墨色 / 设置页周预览 / 壁纸位置页极性）原先各写一份「先记已采过、
/// 再等结果」，失败后永久卡在"命中缓存"分支上——墨色与极性一直停在主题默认色，
/// 直到换壁纸或冷启动。闸门守两件事：
///
/// 1. **失败不能当成采过**：同一份 key 失败后要放行下一次；
/// 2. **但不能无限试**：解不开的图不能让每帧都重新解码一张大图 —— 同 key 有上限。
void main() {
  group('LuminanceSampleGate', () {
    test('第一次就该采；成功之后同一份 key 不再采', () {
      final gate = LuminanceSampleGate();

      expect(gate.needsSample('k1'), isTrue, reason: '第一次当然要采');

      gate.record('k1', succeeded: true);

      expect(
        gate.needsSample('k1'),
        isFalse,
        reason: '采到了就是命中缓存，不该反复解码同一张图',
      );
    });

    test('失败要放行重试，但同一份 key 最多试 maxRetries 次', () {
      final gate = LuminanceSampleGate();

      // 三次尝试：每次都先放行、再记失败。
      for (var attempt = 1; attempt <= 3; attempt++) {
        expect(
          gate.needsSample('k1'),
          isTrue,
          reason: '第 $attempt 次应当放行——失败被当成「采过了」就是这次要治的病',
        );
        gate.record('k1', succeeded: false);
      }

      expect(
        gate.needsSample('k1'),
        isFalse,
        reason: '试满 maxRetries 次就该认输：解不开的图不能每帧重解码一张大图',
      );
    });

    test('中间成功一次就永久命中，不再受失败计数影响', () {
      final gate = LuminanceSampleGate();

      gate.record('k1', succeeded: false);
      gate.record('k1', succeeded: false);
      gate.record('k1', succeeded: true);

      expect(gate.needsSample('k1'), isFalse);
    });

    test('换了一份 key（换图 / 视口 / 对齐）重新计数', () {
      final gate = LuminanceSampleGate(maxRetries: 2);

      gate.record('k1', succeeded: false);
      gate.record('k1', succeeded: false);
      expect(gate.needsSample('k1'), isFalse, reason: '试满了');

      expect(
        gate.needsSample('k2'),
        isTrue,
        reason: '另一份 key 是另一张图/另一种裁剪，必须重新采',
      );

      gate.record('k2', succeeded: false);
      expect(
        gate.needsSample('k2'),
        isTrue,
        reason: 'k2 才失败一次，不该被 k1 的失败额度连坐',
      );
    });

    test('reset 之后重新放行（背景整个没了再回来）', () {
      final gate = LuminanceSampleGate(maxRetries: 1);

      gate.record('k1', succeeded: true);
      expect(gate.needsSample('k1'), isFalse);

      gate.reset();

      expect(gate.needsSample('k1'), isTrue);
    });
  });
}
