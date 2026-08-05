import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/qr_transfer/qr_transfer_codec.dart';
import 'package:university_timetable/services/qr_transfer/qr_transfer_frame_worker.dart';

void main() {
  test('worker matrices match their generated frame text exactly', () async {
    final payload = Uint8List.fromList(
      List<int>.generate(900, (index) => (index * 73 + 19) & 0xff),
    );
    final referenceEncoder = QrTransferEncoder.prepare(payload);
    final worker = await QrTransferFrameWorker.start(payload);
    addTearDown(worker.dispose);

    expect(
      worker.info.sourceSymbolCount,
      referenceEncoder.info.sourceSymbolCount,
    );
    expect(worker.info.symbolSize, referenceEncoder.info.symbolSize);
    expect(worker.info.payloadLength, referenceEncoder.info.payloadLength);
    expect(worker.info.rawLength, referenceEncoder.info.rawLength);
    expect(worker.info.payloadSha256, referenceEncoder.info.payloadSha256);

    final frames = await worker.generate(startSeed: 0, count: 3);
    expect(frames.map((frame) => frame.seed), [0, 1, 2]);
    for (final frame in frames) {
      final expected = qrTransferMatrixForText(
        frame.frameText,
        seed: frame.seed,
      );
      expect(frame.moduleCount, expected.moduleCount);
      expect(frame.modules, orderedEquals(expected.modules));
    }
  });

  test('worker input remains compatible with the QR frame protocol', () async {
    final payload = Uint8List.fromList(utf8.encode('后台 QR worker 协议回归'));
    final worker = await QrTransferFrameWorker.start(payload);
    addTearDown(worker.dispose);

    final matrix = (await worker.generate(startSeed: 7, count: 1)).single;

    expect(matrix.seed, 7);
    expect(QrTransferFrame.parse(matrix.frameText).seed, 7);
  });
}
