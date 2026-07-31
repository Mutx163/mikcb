import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fountain_codes/fountain_codes.dart';

import 'qr_transfer_session.dart';

/// 二维码帧的文本协议：
///
/// ```text
/// QRV1|<k>|<t>|<payloadLen>|<payloadSha256B64>|<seed>|<degree>|<symbolB64>
/// ```
///
/// - `k` / `t`：LT 码的源码符号数与符号字节大小，解码端据此构造解码器；
/// - `payloadLen`：gzip 后载荷的真实字节数，解码后据此截断；
/// - `payloadSha256B64`：载荷 SHA-256，解码完成后校验；
/// - `seed`：本帧的 LT 编码种子，解码端据此确定性地重建邻居；
/// - `degree`：本帧的度数，必须随帧传输（解码端不做采样）；
/// - `symbolB64`：本帧符号的 base64url 文本。
class QrTransferFrame {
  static const String magic = 'QRV1';
  static const String fieldSeparator = '|';
  static const int expectedFieldCount = 8;

  final QrTransferSessionInfo info;
  final int seed;
  final int degree;
  final Uint8List symbolBytes;

  const QrTransferFrame({
    required this.info,
    required this.seed,
    required this.degree,
    required this.symbolBytes,
  });

  /// 将一帧编码为可放入二维码的纯文本。
  String encode() {
    return [
      magic,
      info.sourceSymbolCount,
      info.symbolSize,
      info.payloadLength,
      info.payloadSha256,
      seed,
      degree,
      base64Url.encode(symbolBytes),
    ].join(fieldSeparator);
  }

  /// 解析二维码识别出的文本；格式不合法时抛出 [FormatException]。
  factory QrTransferFrame.parse(String text) {
    final fields = text.split(fieldSeparator);
    if (fields.length != expectedFieldCount || fields.first != magic) {
      throw const FormatException('invalid_qr_transfer_frame');
    }

    final sourceSymbolCount = _parseIntField(fields[1]);
    final symbolSize = _parseIntField(fields[2]);
    final payloadLength = _parseIntField(fields[3]);
    final seed = _parseIntField(fields[5]);
    final degree = _parseIntField(fields[6]);

    if (sourceSymbolCount <= 0 ||
        symbolSize <= 0 ||
        payloadLength < 0 ||
        seed < 0 ||
        degree <= 0) {
      throw const FormatException('invalid_qr_transfer_frame');
    }

    final Uint8List symbolBytes;
    try {
      symbolBytes = base64Url.decode(fields[7]);
    } on FormatException {
      throw const FormatException('invalid_qr_transfer_frame');
    }
    if (symbolBytes.length != symbolSize) {
      throw const FormatException('invalid_qr_transfer_frame');
    }

    return QrTransferFrame(
      info: QrTransferSessionInfo(
        sourceSymbolCount: sourceSymbolCount,
        symbolSize: symbolSize,
        payloadLength: payloadLength,
        payloadSha256: fields[4],
      ),
      seed: seed,
      degree: degree,
      symbolBytes: symbolBytes,
    );
  }

  static int _parseIntField(String text) {
    final value = int.tryParse(text);
    if (value == null) {
      throw const FormatException('invalid_qr_transfer_frame');
    }
    return value;
  }
}

/// 二维码传输发送端：压缩 → LT 编码 → 逐帧产出二维码文本。
class QrTransferEncoder {
  /// 根据 gzip 后载荷大小选择符号大小，让每帧文本稳定落在二维码
  /// 的易识别区间（约 400 ~ 1500 字符），同时控制帧数不过多。
  ///
  /// 符号越大，每帧携带的数据越多、总帧数越少；但帧文本变长会推高
  /// QR 版本，屏幕上的模块变小、识别变难。256B/512B 是面对面扫码
  /// 传输的甜点区间（对应约 V12 / V20 版本）。
  static int pickSymbolSize(int payloadLength) {
    if (payloadLength <= 2048) return 256;
    if (payloadLength <= 16384) return 512;
    if (payloadLength <= 65536) return 1024;
    return 2048;
  }

  final Uint8List rawBytes;
  final Uint8List compressedPayload;
  final QrTransferSessionInfo info;
  final LTCodec _codec;
  int _seed = -1;

  QrTransferEncoder._({
    required this.rawBytes,
    required this.compressedPayload,
    required this.info,
    required LTCodec codec,
  }) : _codec = codec;

  /// 用原始（未压缩）字节构建编码器；空数据不允许传输。
  factory QrTransferEncoder.prepare(Uint8List rawBytes) {
    if (rawBytes.isEmpty) {
      throw ArgumentError.value(rawBytes, 'rawBytes', 'must not be empty');
    }

    final compressedPayload = Uint8List.fromList(gzip.encode(rawBytes));
    final symbolSize = pickSymbolSize(compressedPayload.length);
    final sourceSymbolCount =
        (compressedPayload.length + symbolSize - 1) ~/ symbolSize;
    final info = QrTransferSessionInfo(
      sourceSymbolCount: sourceSymbolCount,
      symbolSize: symbolSize,
      payloadLength: compressedPayload.length,
      payloadSha256: base64Url.encode(sha256.convert(compressedPayload).bytes),
    );
    final codec = LTCodec(
      config: FountainConfig(k: sourceSymbolCount, t: symbolSize),
    )..setSourceData(compressedPayload);

    return QrTransferEncoder._(
      rawBytes: rawBytes,
      compressedPayload: compressedPayload,
      info: info,
      codec: codec,
    );
  }

  /// 产出下一帧文本。seed 持续递增，符号流在理论上可无限延续，
  /// 发送端按自己的节奏播放即可。
  String nextFrame() {
    _seed++;
    return frameTextFor(_seed);
  }

  /// 生成指定 seed 的帧文本（不推进内部计数器）。
  ///
  /// LT 编码对同一 seed 是确定性的，因此发送端可以借此**预先**生成
  /// 未来几帧的文本（再交给 QR 矩阵计算），把耗时移出 setState 的
  /// 关键路径——帧间隔缩短后仍能保持 UI 流畅。
  String frameTextFor(int seed) {
    final symbol = _codec.encode(0, seed);
    return QrTransferFrame(
      info: info,
      seed: symbol.esiOrSeed,
      degree: symbol.meta['degree'] ?? 1,
      symbolBytes: symbol.bytes,
    ).encode();
  }

  /// 当前已产出的帧数。
  int get emittedFrameCount => _seed + 1;
}

/// 二维码传输接收端：解析帧文本 → LT 解码 → 截断 + SHA-256 校验。
class QrTransferDecoder {
  QrTransferSessionInfo? _info;
  LTCodec? _codec;
  int _receivedSymbols = 0;
  int _innovativeSymbols = 0;
  final Set<int> _submittedSeeds = {};
  QrTransferDecodeResult? _result;

  /// 会话信息；收到第一帧后可用。
  QrTransferSessionInfo? get sessionInfo => _info;

  /// 是否已解出全部数据。
  bool get isComplete => _result != null;

  /// 已解出的载荷（未解出前为 null）。
  Uint8List? get decodedPayload => _result?.payload;

  QrTransferDecodeProgress get progress {
    final codec = _codec;
    final status = codec?.status();
    return QrTransferDecodeProgress(
      receivedSymbols: _receivedSymbols,
      innovativeSymbols: _innovativeSymbols,
      sourceSymbolCount: _info?.sourceSymbolCount ?? 0,
      decodedSymbols: status?.rank ?? 0,
      isComplete: isComplete,
    );
  }

  /// 提交一帧；返回最新进度。帧无法解析或与当前会话不匹配时抛异常。
  QrTransferDecodeProgress submitFrame(String frameText) {
    if (_result != null) {
      return progress;
    }

    final frame = QrTransferFrame.parse(frameText);
    // 先建立/校验会话：跨会话的帧即使 seed 相同也必须先报不匹配。
    final codec = _ensureCodec(frame.info);
    // 摄像头停在同一帧画面时可能反复识别出相同符号；重复提交只会
    // 触发无意义的高斯消元，按 seed 去重跳过（帧率高后收益明显）。
    if (!_submittedSeeds.add(frame.seed)) {
      return progress;
    }
    _receivedSymbols++;

    final symbol = Symbol(
      segmentId: 0,
      esiOrSeed: frame.seed,
      bytes: frame.symbolBytes,
      meta: {'degree': frame.degree},
    );
    final submitResult = codec.submit(symbol);
    if (submitResult.isInnovative) {
      _innovativeSymbols++;
    }

    if (submitResult.isComplete) {
      _finish();
    }
    return progress;
  }

  /// 完成时从 LT 码解码结果中截取真实载荷并做 SHA-256 校验。
  void _finish() {
    final codec = _codec;
    final info = _info;
    if (codec == null || info == null) {
      return;
    }
    final decoded = codec.getDecodedData();
    if (decoded == null) {
      throw StateError('decoder completed but produced no data');
    }
    final payload = Uint8List.sublistView(decoded, 0, info.payloadLength);
    final actualSha256 = base64Url.encode(sha256.convert(payload).bytes);
    if (actualSha256 != info.payloadSha256) {
      throw StateError('qr_transfer_checksum_failed');
    }
    _result = QrTransferDecodeResult(payload: payload, info: info);
  }

  LTCodec _ensureCodec(QrTransferSessionInfo info) {
    final existing = _codec;
    if (existing != null) {
      _validateSession(info);
      return existing;
    }
    _info = info;
    final codec = LTCodec(
      config: FountainConfig(k: info.sourceSymbolCount, t: info.symbolSize),
    );
    _codec = codec;
    return codec;
  }

  void _validateSession(QrTransferSessionInfo info) {
    final current = _info;
    if (current == null) {
      return;
    }
    final matches =
        current.sourceSymbolCount == info.sourceSymbolCount &&
        current.symbolSize == info.symbolSize &&
        current.payloadLength == info.payloadLength &&
        current.payloadSha256 == info.payloadSha256;
    if (!matches) {
      throw StateError('qr_transfer_session_mismatch');
    }
  }
}

/// 从已解出的 gzip 载荷还原原始字节。
Uint8List qrTransferDecompress(Uint8List compressedPayload) {
  return Uint8List.fromList(gzip.decode(compressedPayload));
}
