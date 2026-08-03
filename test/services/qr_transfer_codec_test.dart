import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/qr_transfer/qr_transfer_codec.dart';
import 'package:university_timetable/services/qr_transfer/qr_transfer_session.dart';

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

String _replaceFrameField(String frameText, int index, String value) {
  final fields = frameText.split(QrTransferFrame.fieldSeparator);
  fields[index] = value;
  return fields.join(QrTransferFrame.fieldSeparator);
}

void main() {
  Uint8List utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

  test('小数据往返一致（k 较小）', () {
    final original = utf8Bytes('轻屿课表备份演示数据');
    final encoder = QrTransferEncoder.prepare(original);
    final decoder = QrTransferDecoder();

    _simulateTransfer(encoder, decoder, dropRate: 0.2);

    expect(decoder.isComplete, isTrue);
    expect(decoder.decodeRawPayload(), original);
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
    expect(frame.info.rawLength, encoder.info.rawLength);
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
      () => decoder.submitFrame('QRV2|bad|frame|0|0|x|0|1|'),
      throwsFormatException,
    );

    decoder.submitFrame(encoderA.nextFrame());
    expect(() => decoder.submitFrame(encoderB.nextFrame()), throwsStateError);
  });

  test('frameTextFor 与 nextFrame 序列一致且可重复生成', () {
    final original = utf8Bytes('预生成帧测试数据，验证 frameTextFor 的确定性。' * 20);
    final encoder = QrTransferEncoder.prepare(original);

    final sequential = <String>[
      encoder.nextFrame(),
      encoder.nextFrame(),
      encoder.nextFrame(),
    ];
    final bySeed = [
      encoder.frameTextFor(0),
      encoder.frameTextFor(1),
      encoder.frameTextFor(2),
    ];

    // 发送端可用 frameTextFor 预生成任意 seed 的帧，推进计数器不影响历史帧。
    expect(sequential, bySeed);
    expect(encoder.frameTextFor(0), bySeed[0]);
  });

  test('重复帧按 seed 去重，计入 duplicateSymbols 与 detectedSymbols', () {
    // 不可压缩随机数据保证 k > 1，避免第一帧就完成解码。
    final rng = Random(3);
    final original = Uint8List.fromList(
      List.generate(700, (_) => rng.nextInt(256)),
    );
    final encoder = QrTransferEncoder.prepare(original);
    expect(encoder.info.sourceSymbolCount, greaterThan(1));

    final decoder = QrTransferDecoder();
    final frame0 = encoder.nextFrame();
    final frame1 = encoder.nextFrame();

    // 摄像头停在同一帧画面时反复识别到相同文本：第二次应被静默跳过。
    final first = decoder.submitFrame(frame0);
    final repeated = decoder.submitFrame(frame0);
    expect(repeated.receivedSymbols, first.receivedSymbols);
    expect(repeated.decodedSymbols, first.decodedSymbols);
    expect(repeated.detectedSymbols, first.detectedSymbols + 1);
    expect(repeated.duplicateSymbols, first.duplicateSymbols + 1);
    expect(decoder.isComplete, isFalse);

    final second = decoder.submitFrame(frame1);
    expect(second.receivedSymbols, first.receivedSymbols + 1);
  });

  test('会话信息携带原始大小 rawLength', () {
    final original = utf8Bytes('原始大小随帧传输，接收端无需解压即可展示文件信息。' * 30);
    final encoder = QrTransferEncoder.prepare(original);
    final decoder = QrTransferDecoder();

    decoder.submitFrame(encoder.nextFrame());

    expect(decoder.sessionInfo?.rawLength, original.length);
    expect(decoder.progress.sourceSymbolCount, encoder.info.sourceSymbolCount);
  });

  test('恶意帧元数据与哈希字段被安全拒绝', () {
    final encoder = QrTransferEncoder.prepare(utf8Bytes('边界校验'));
    final frame = encoder.nextFrame();

    expect(
      () => QrTransferFrame.parse(
        _replaceFrameField(
          frame,
          1,
          '${QrTransferFrame.maxSourceSymbolCount + 1}',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => QrTransferFrame.parse(
        _replaceFrameField(frame, 2, '${QrTransferFrame.maxSymbolSize + 1}'),
      ),
      throwsFormatException,
    );
    expect(
      () => QrTransferFrame.parse(_replaceFrameField(frame, 3, '0')),
      throwsFormatException,
    );
    expect(
      () => QrTransferFrame.parse(_replaceFrameField(frame, 4, '0')),
      throwsFormatException,
    );
    expect(
      () => QrTransferFrame.parse(_replaceFrameField(frame, 5, 'bad-hash')),
      throwsFormatException,
    );
    expect(
      () => QrTransferFrame.parse(
        _replaceFrameField(
          frame,
          7,
          '${QrTransferFrame.maxSourceSymbolCount + 1}',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => QrTransferFrame.parse(
        '${frame}x' * QrTransferFrame.maxFrameTextLength,
      ),
      throwsFormatException,
    );
  });

  test('校验失败后不会误报完成，reset 后可重新接收', () {
    final original = Uint8List.fromList(
      List<int>.generate(2400, (index) => (index * 17) & 0xff),
    );
    final encoder = QrTransferEncoder.prepare(original);
    final decoder = QrTransferDecoder();
    final invalidHash = base64Url.encode(List<int>.filled(32, 0));
    StateError? checksumError;

    for (var i = 0; i < encoder.info.sourceSymbolCount * 5; i++) {
      try {
        decoder.submitFrame(
          _replaceFrameField(encoder.nextFrame(), 5, invalidHash),
        );
      } on StateError catch (error) {
        checksumError = error;
        break;
      }
    }

    expect(checksumError?.message, 'qr_transfer_checksum_failed');
    expect(decoder.isComplete, isFalse);

    final replacement = QrTransferEncoder.prepare(utf8Bytes('reset 后的新传输'));
    decoder.reset();
    _simulateTransfer(replacement, decoder);
    expect(decoder.isComplete, isTrue);
    expect(decoder.decodeRawPayload(), utf8Bytes('reset 后的新传输'));
  });

  test('完成后校验原始长度，长度篡改不会进入导入', () {
    final original = utf8Bytes('原始长度校验');
    final encoder = QrTransferEncoder.prepare(original);
    final decoder = QrTransferDecoder();
    StateError? lengthError;

    for (var i = 0; i < encoder.info.sourceSymbolCount * 5; i++) {
      try {
        decoder.submitFrame(
          _replaceFrameField(encoder.nextFrame(), 4, '${original.length + 1}'),
        );
      } on StateError catch (error) {
        lengthError = error;
        break;
      }
    }

    expect(decoder.isComplete, isTrue);
    expect(lengthError, isNull);
    expect(
      () => decoder.decodeRawPayload(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'qr_transfer_raw_length_mismatch',
        ),
      ),
    );
  });

  test('编码前预检拒绝超过原始数据上限的备份', () {
    final oversized = Uint8List(QrTransferLimits.maxRawPayloadBytes + 1);

    expect(
      () => QrTransferEncoder.preflight(oversized),
      throwsA(
        isA<QrTransferLimitException>().having(
          (error) => error.code,
          'code',
          'qr_transfer_raw_payload_too_large',
        ),
      ),
    );
  });

  test('gzip 输出硬上限阻止高压缩比 payload 扩张', () {
    final raw = Uint8List(256 * 1024);
    final compressed = Uint8List.fromList(gzip.encode(raw));

    expect(
      () => qrTransferDecompress(compressed, maxOutputBytes: 1024),
      throwsA(
        isA<QrTransferLimitException>().having(
          (error) => error.code,
          'code',
          'qr_transfer_decompression_output_too_large',
        ),
      ),
    );
    expect(qrTransferDecompress(compressed, maxOutputBytes: raw.length), raw);
  });

  test('后台解压支持取消，完成后返回原始数据', () async {
    final raw = Uint8List.fromList(List<int>.filled(128 * 1024, 0x41));
    final compressed = Uint8List.fromList(gzip.encode(raw));

    final cancelled = await QrTransferDecompressionJob.start(
      compressed,
      maxOutputBytes: raw.length,
    );
    cancelled.cancel();
    await expectLater(
      cancelled.future,
      throwsA(isA<QrTransferDecompressionCancelled>()),
    );

    final completed = await QrTransferDecompressionJob.start(
      compressed,
      maxOutputBytes: raw.length,
    );
    expect(await completed.future, raw);
  });

  test('未完成会话不会进入解压阶段', () {
    final decoder = QrTransferDecoder();

    expect(
      () => decoder.decodeRawPayload(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'qr_transfer_not_complete',
        ),
      ),
    );
  });

  test('会话超时后停止接收，reset 后可建立新会话', () {
    final rng = Random(99);
    final original = Uint8List.fromList(
      List.generate(700, (_) => rng.nextInt(256)),
    );
    final encoder = QrTransferEncoder.prepare(original);
    var now = DateTime.utc(2026, 8, 3);
    final decoder = QrTransferDecoder(now: () => now);

    decoder.submitFrame(encoder.nextFrame());
    now = now.add(
      QrTransferLimits.maxSessionDuration + const Duration(seconds: 1),
    );

    expect(
      () => decoder.submitFrame(encoder.nextFrame()),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'qr_transfer_session_expired',
        ),
      ),
    );
    expect(decoder.isComplete, isFalse);

    decoder.reset();
    expect(decoder.sessionInfo, isNull);
  });

  test('接收端限制唯一 seed，避免无限增长的会话', () {
    final decoder = QrTransferDecoder();
    final hash = base64Url.encode(List<int>.filled(32, 0));

    String frameFor(int seed) {
      return [
        QrTransferFrame.magic,
        '8192',
        '1',
        '8192',
        '8192',
        hash,
        '$seed',
        '1',
        base64Url.encode([seed & 0xff]),
      ].join(QrTransferFrame.fieldSeparator);
    }

    for (var seed = 0; seed < QrTransferLimits.maxUniqueSeedCount; seed++) {
      decoder.submitFrame(frameFor(seed));
      expect(decoder.isComplete, isFalse);
    }
    expect(
      () => decoder.submitFrame(frameFor(QrTransferLimits.maxUniqueSeedCount)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'qr_transfer_unique_seed_limit',
        ),
      ),
    );
  });
  test('发送端拒绝超过唯一 seed/frame 预算的帧', () {
    final encoder = QrTransferEncoder.prepare(utf8Bytes('frame budget'));

    expect(
      () => encoder.frameTextFor(QrTransferLimits.maxUniqueSeedCount),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'qr_transfer_frame_budget_exceeded',
        ),
      ),
    );
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
