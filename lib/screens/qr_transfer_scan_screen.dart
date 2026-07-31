import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/qr_transfer/qr_transfer_codec.dart';
import '../services/qr_transfer/qr_transfer_session.dart';

/// 接收端扫码页面。
///
/// 持续识别对方屏幕上的二维码流，实时反馈接收与解码进度；
/// 全部数据解出并通过校验后回调 [onComplete] 返回原始字节。
class QrTransferScanScreen extends StatefulWidget {
  final ValueChanged<Uint8List> onComplete;

  const QrTransferScanScreen({super.key, required this.onComplete});

  @override
  State<QrTransferScanScreen> createState() => _QrTransferScanScreenState();
}

class _QrTransferScanScreenState extends State<QrTransferScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final QrTransferDecoder _decoder = QrTransferDecoder();

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
  void dispose() {
    _scannerController.dispose();
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
            child: Column(
              children: [
                _buildTopBar(l10n),
                const Spacer(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              l10n.qrTransferScanTitle,
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

  Widget _buildProgressPanel(AppLocalizations l10n) {
    final fraction = _progress.fraction;
    final hasSession = _progress.sourceSymbolCount > 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasSession) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.qrTransferReceiveProgress(
                _progress.receivedSymbols,
                _progress.decodedSymbols,
                _progress.sourceSymbolCount,
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ] else ...[
            Text(
              l10n.qrTransferScanHint,
              style: const TextStyle(color: Colors.white),
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
    );
  }

  Widget _buildFinishedOverlay(AppLocalizations l10n) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
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
    );
  }
}
