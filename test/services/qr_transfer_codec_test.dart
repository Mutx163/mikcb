import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/qr_transfer/qr_transfer_codec.dart';

/// 模拟一轮「发送端逐帧播放，接收端扫码」：
/// 打乱帧序、丢弃一部分帧、重复若干帧（模拟反复扫同一屏），
/// 返回解码完成的帧数，供测试断言。
int _simulateTransfer(
  QrTransferEncoder encoder,
  QrTransferDecoder decoder, {
  double dropRate = 0.0,
}) {
  final rng = Random(42);
  final frames = <String>[];
  // 生成约 3 倍源码符号数的帧，保证丢包后仍足够解码。
  final frameBudget = encoder.info.sourceSymbolCount * 3;
  for (var i = 0; i < frameBudget; i++) {
    frames.add(encoder.nextFrame());
  }

  final shuffled = List<String>.of(frames)..shuffle(rng);
  var submitted = 0;
  for (final frame in shuffled) {
    if (rng.nextDouble() < dropRate) {
      continue;
    }
    decoder.submitFrame(frame);
    submitted++;
    if (decoder.isComplete) {
      break;
    }
  }
  // 模拟重复扫到同一帧。
  if (!decoder.isComplete && frames.isNotEmpty) {
    for (final frame in frames.take(64)) {
      decoder.submitFrame(frame);
      if (decoder.isComplete) {
        break;
      }
    }
  }
  return submitted;
}

void main() {
  Uint8List utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

  test('小数据往返一致（k 较小）', () {
    final original = utf8Bytes('轻屿课表备份演示数据');
    final encoder = QrTransferEncoder.prepare(original);
    final decoder = QrTransferDecoder();

    _simulateTransfer(encoder, decoder, dropRate: 0.2);

    expect(decoder.isComplete, isTrue);
    final restored = qrTransferDecompress(decoder.decodedPayload!);
    expect(restored, original);
  });

  test('模拟真实备份 JSON（几十 KB）丢包乱序仍可还原', () {
    final courses = List.generate(
      60,
      (i) => {
        'text': '课程${i.toString().padLeft(2, '0')}',
        'location': '教学楼${i % 5 + 1}',
        'teacher': '教师${i % 8 + 1}',
        'weeks': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      },
    );
    final original = utf8Bytes(
      const JsonEncoder.withIndent('  ').convert({
        'app': 'mikcb',
        'schemaVersion': 1,
        'profileName': '大二下',
        'currentWeek': 5,
        'courses': courses,
      }),
    );

    final encoder = QrTransferEncoder.prepare(original);
    expect(encoder.info.sourceSymbolCount, greaterThan(1));

    final decoder = QrTransferDecoder();
    final submitted = _simulateTransfer(encoder, decoder, dropRate: 0.3);

    expect(decoder.isComplete, isTrue);
    expect(decoder.progress.receivedSymbols, lessThanOrEqualTo(submitted + 64));
    expect(decoder.progress.innovativeSymbols, greaterThan(0));
    final restored = qrTransferDecompress(decoder.decodedPayload!);
    expect(restored, original);
  });

  test('无丢包时也能按序解码', () {
    final original = utf8Bytes('按序传输：第一个二维码扫完立即扫第二个');
    final encoder = QrTransferEncoder.prepare(original);
    final decoder = QrTransferDecoder();

    _simulateTransfer(encoder, decoder);

    expect(decoder.isComplete, isTrue);
    expect(qrTransferDecompress(decoder.decodedPayload!), original);
  });

  test('帧文本可放入二维码且可解析', () {
    final original = utf8Bytes('二维码容量检查' * 20);
    final encoder = QrTransferEncoder.prepare(original);
    final frameText = encoder.nextFrame();

    // 帧文本必须远小于 QR 版本 40 的 2953 字符上限。
    expect(frameText.length, lessThan(1500));
    final frame = QrTransferFrame.parse(frameText);
    expect(frame.info.sourceSymbolCount, encoder.info.sourceSymbolCount);
    expect(frame.info.symbolSize, encoder.info.symbolSize);
    expect(frame.info.payloadLength, encoder.info.payloadLength);
    expect(frame.info.payloadSha256, encoder.info.payloadSha256);
  });

  test('非法帧与跨会话帧被拒绝', () {
    // 用不可压缩的随机数据保证 k > 1，避免第一帧就完成解码。
    Uint8List randomBytes(int length, [int seed = 7]) {
      final rng = Random(seed);
      return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
    }

    final encoderA = QrTransferEncoder.prepare(randomBytes(2000, 1));
    final encoderB = QrTransferEncoder.prepare(randomBytes(2000, 2));
    final decoder = QrTransferDecoder();

    // 坏帧在任何会话建立前就必须被拒绝。
    expect(() => decoder.submitFrame('not a qr frame'), throwsFormatException);
    expect(
      () => decoder.submitFrame('QRV1|bad|frame|0|x|0|1|'),
      throwsFormatException,
    );

    decoder.submitFrame(encoderA.nextFrame());
    expect(() => decoder.submitFrame(encoderB.nextFrame()), throwsStateError);
  });

  test('大文件跨多符号粒度往返一致', () {
    final builder = StringBuffer();
    for (var i = 0; i < 4000; i++) {
      builder.write('第$i行：这是一段比较长的课程备注与考试安排描述文本。\n');
    }
    final original = utf8Bytes(builder.toString());
    expect(original.length, greaterThan(100000));

    final encoder = QrTransferEncoder.prepare(original);
    final decoder = QrTransferDecoder();

    _simulateTransfer(encoder, decoder, dropRate: 0.25);

    expect(decoder.isComplete, isTrue);
    expect(qrTransferDecompress(decoder.decodedPayload!), original);
  });
}
