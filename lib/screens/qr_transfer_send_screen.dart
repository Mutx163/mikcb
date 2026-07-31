import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/qr_transfer/qr_transfer_codec.dart';

/// 发送端全屏二维码流页面。
///
/// 把传入的备份字节流式编码成逐帧二维码播放，对方手机摄像头
/// 对准屏幕即可完成接收；码流可无限延续，直到用户手动停止。
class QrTransferSendScreen extends StatefulWidget {
  /// 待传输的原始字节（备份 JSON 的 UTF-8 编码）。
  final Uint8List payloadBytes;

  /// 界面标题，例如「发送当前课表」。
  final String title;

  const QrTransferSendScreen({
    super.key,
    required this.payloadBytes,
    required this.title,
  });

  @override
  State<QrTransferSendScreen> createState() => _QrTransferSendScreenState();
}

class _QrTransferSendScreenState extends State<QrTransferSendScreen> {
  static const Duration _frameInterval = Duration(milliseconds: 2500);

  late final QrTransferEncoder _encoder;
  Timer? _frameTimer;
  late String _currentFrameText;

  @override
  void initState() {
    super.initState();
    _encoder = QrTransferEncoder.prepare(widget.payloadBytes);
    _currentFrameText = _encoder.nextFrame();
    _frameTimer = Timer.periodic(_frameInterval, (_) => _advanceFrame());
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    super.dispose();
  }

  void _advanceFrame() {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentFrameText = _encoder.nextFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // LT 码通常需要略多于源码符号数的编码符号即可解出，按 1.2 倍估算。
    final estimatedTotalFrames = (_encoder.info.sourceSymbolCount * 1.2).ceil();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: _currentFrameText,
                        version: QrVersions.auto,
                        gapless: true,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Text(
                    l10n.qrTransferFrameProgress(
                      _encoder.emittedFrameCount,
                      estimatedTotalFrames,
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.qrTransferSendHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.stop),
                      label: Text(l10n.qrTransferStop),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: l10n.closeAction,
          ),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
