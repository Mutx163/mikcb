import 'dart:typed_data';

/// 一次二维码传输会话的固定元信息，随每一帧在头部传输。
///
/// 解码端在收到任意一帧后即可根据该信息构造 LT 解码器。
class QrTransferSessionInfo {
  /// LT 源码符号数（压缩后载荷切分出的符号个数）。
  final int sourceSymbolCount;

  /// 单个符号的字节大小。
  final int symbolSize;

  /// 压缩后载荷的真实字节数（最后一帧符号需要截断到该长度）。
  final int payloadLength;

  /// 原始（未压缩）数据的字节数，随帧传输供接收端展示文件信息。
  final int rawLength;

  /// 压缩后载荷的 SHA-256 摘要（base64url），解码完成后校验。
  final String payloadSha256;

  const QrTransferSessionInfo({
    required this.sourceSymbolCount,
    required this.symbolSize,
    required this.payloadLength,
    required this.rawLength,
    required this.payloadSha256,
  });
}

/// 解码进度，供接收端 UI 展示。
class QrTransferDecodeProgress {
  /// 摄像头识别到且属于当前会话的有效帧数（含重复帧）。
  final int detectedSymbols;

  /// 已提交过相同 seed 的重复帧数（不计入 [receivedSymbols]）。
  final int duplicateSymbols;

  /// 已提交的（去重后的）有效帧数。
  final int receivedSymbols;

  /// 对解码有实际贡献（线性无关）的帧数。
  final int innovativeSymbols;

  final int sourceSymbolCount;
  final int decodedSymbols;
  final bool isComplete;

  const QrTransferDecodeProgress({
    this.detectedSymbols = 0,
    this.duplicateSymbols = 0,
    required this.receivedSymbols,
    required this.innovativeSymbols,
    required this.sourceSymbolCount,
    required this.decodedSymbols,
    required this.isComplete,
  });

  /// 已解出符号占源码符号的比例，0.0 ~ 1.0。
  double get fraction => sourceSymbolCount == 0
      ? 1.0
      : (decodedSymbols / sourceSymbolCount).clamp(0.0, 1.0);
}

/// 解码完成后的载荷结果。
class QrTransferDecodeResult {
  final Uint8List payload;
  final QrTransferSessionInfo info;

  const QrTransferDecodeResult({required this.payload, required this.info});
}
