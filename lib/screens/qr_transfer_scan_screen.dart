import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../services/qr_transfer/qr_transfer_codec.dart';
import '../services/qr_transfer/qr_transfer_session.dart';

/// 接收端扫码页面。
///
/// 持续识别对方屏幕上的二维码流，实时反馈接收与解码进度；
/// 全部数据解出并通过校验后回调 [onComplete] 返回原始字节。
///
/// 界面为 HyperOS 风格：顶部 Miuix 顶栏、取景框带扫描线动画、
/// 底部毛玻璃进度面板；重复识别到同一帧符号由
/// [QrTransferDecoder.submitFrame] 按 seed 去重，不会做无谓消元。
class QrTransferScanScreen extends StatefulWidget {
  final ValueChanged<Uint8List> onComplete;

  const QrTransferScanScreen({super.key, required this.onComplete});

  @override
  State<QrTransferScanScreen> createState() => _QrTransferScanScreenState();
}

class _QrTransferScanScreenState extends State<QrTransferScanScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final QrTransferDecoder _decoder = QrTransferDecoder();

  /// 取景框扫描线动画。
  late final AnimationController _scanLineController;

  QrTransferDecodeProgress _progress = const QrTransferDecodeProgress(
    receivedSymbols: 0,
    innovativeSymbols: 0,
    sourceSymbolCount: 0,
    decodedSymbols: 0,
    isComplete: false,
  );
  String? _lastHandledFrame;
  String? _errorMessageKey;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_finished) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null || text == _lastHandledFrame) {
        continue;
      }
      _lastHandledFrame = text;
      try {
        final progress = _decoder.submitFrame(text);
        if (!mounted) {
          return;
        }
        setState(() {
          _progress = progress;
          _errorMessageKey = null;
        });
        if (progress.isComplete) {
          _finish();
          return;
        }
      } on FormatException {
        // 非本协议二维码，静默忽略。
        continue;
      } on StateError {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessageKey = 'qr_transfer_session_mismatch';
        });
      }
    }
  }

  Future<void> _finish() async {
    _finished = true;
    await _scannerController.stop();
    if (!mounted) {
      return;
    }
    setState(() {});
    final payload = _decoder.decodedPayload;
    if (payload != null) {
      widget.onComplete(qrTransferDecompress(payload));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetect,
            errorBuilder: (context, error) =>
                const ColoredBox(color: Colors.black),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(l10n),
                Expanded(child: _buildViewfinder()),
                _buildProgressPanel(l10n),
              ],
            ),
          ),
          if (_finished) _buildFinishedOverlay(l10n),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return MiuixSmallTopAppBar(
      title: l10n.qrTransferScanTitle,
      titleColor: Colors.white,
      color: Colors.black.withValues(alpha: 0.45),
      navigationIcon: HyperosIconButton(
        icon: Icons.arrow_back,
        color: Colors.white,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildViewfinder() {
    return Center(
      child: SizedBox(
        width: 272,
        height: 272,
        child: AnimatedBuilder(
          animation: _scanLineController,
          builder: (context, _) {
            final scanLineY = 14 + _scanLineController.value * (272 - 28);
            return Stack(
              children: [
                const CustomPaint(
                  painter: _QrViewfinderPainter(),
                  child: SizedBox.expand(),
                ),
                Positioned(
                  top: scanLineY,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressPanel(AppLocalizations l10n) {
    final fraction = _progress.fraction;
    final hasSession = _progress.sourceSymbolCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasSession) ...[
                  HyperosLinearProgress(value: fraction, minHeight: 4),
                  const SizedBox(height: 12),
                  Text(
                    l10n.qrTransferReceiveProgress(
                      _progress.receivedSymbols,
                      _progress.decodedSymbols,
                      _progress.sourceSymbolCount,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ] else ...[
                  Text(
                    l10n.qrTransferScanHint,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                if (_errorMessageKey != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.qrTransferSessionMismatch,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedOverlay(AppLocalizations l10n) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.qrTransferReceiveComplete,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 取景框四角 + 细边框画笔（HyperOS 扫码样式）。
class _QrViewfinderPainter extends CustomPainter {
  const _QrViewfinderPainter();

  static const double _cornerLength = 26;
  static const double _cornerThickness = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.22);
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _cornerThickness
      ..color = Colors.white.withValues(alpha: 0.9);

    final w = size.width;
    final h = size.height;
    final half = _cornerThickness / 2;

    // 细边框
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(half, half, w - _cornerThickness, h - _cornerThickness),
        const Radius.circular(20),
      ),
      borderPaint,
    );

    // 左上角
    _drawCorner(
      canvas,
      cornerPaint,
      Path()
        ..moveTo(half, _cornerLength)
        ..lineTo(half, half)
        ..lineTo(_cornerLength, half),
    );
    // 右上角
    _drawCorner(
      canvas,
      cornerPaint,
      Path()
        ..moveTo(w - _cornerLength, half)
        ..lineTo(w - half, half)
        ..lineTo(w - half, _cornerLength),
    );
    // 左下角
    _drawCorner(
      canvas,
      cornerPaint,
      Path()
        ..moveTo(half, h - _cornerLength)
        ..lineTo(half, h - half)
        ..lineTo(_cornerLength, h - half),
    );
    // 右下角
    _drawCorner(
      canvas,
      cornerPaint,
      Path()
        ..moveTo(w - _cornerLength, h - half)
        ..lineTo(w - half, h - half)
        ..lineTo(w - half, h - _cornerLength),
    );
  }

  void _drawCorner(Canvas canvas, Paint paint, Path path) {
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QrViewfinderPainter oldDelegate) => false;
}
