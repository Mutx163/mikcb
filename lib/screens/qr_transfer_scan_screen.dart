import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../services/qr_transfer/qr_transfer_codec.dart';
import '../services/qr_transfer/qr_transfer_session.dart';

@visibleForTesting
String qrTransferErrorKeyFor(String error) {
  return switch (error) {
    'qr_transfer_session_mismatch' => 'qr_transfer_session_mismatch',
    'qr_transfer_checksum_failed' => 'qr_transfer_checksum_failed',
    'qr_transfer_raw_length_mismatch' => 'qr_transfer_raw_length_mismatch',
    'qr_transfer_decompression_failed' => 'qr_transfer_decompression_failed',
    'qr_transfer_decompression_output_too_large' =>
      'qr_transfer_decompression_output_too_large',
    'qr_transfer_session_expired' => 'qr_transfer_session_expired',
    'qr_transfer_frame_budget_exceeded' => 'qr_transfer_frame_budget_exceeded',
    'qr_transfer_unique_seed_limit' => 'qr_transfer_unique_seed_limit',
    'qr_transfer_adjacency_edge_budget_exceeded' =>
      'qr_transfer_adjacency_edge_budget_exceeded',
    _ => 'qr_transfer_decode_failed',
  };
}

/// 接收端扫码页面。
///
/// 持续识别对方屏幕上的二维码流，实时反馈接收与解码进度；
/// 全部数据解出并通过校验后回调 [onComplete] 返回原始字节。
///
/// 界面为 HyperOS 风格：顶部 Miuix 顶栏、取景框带扫描线动画、
/// 底部毛玻璃进度面板；重复识别到同一帧符号由
/// [QrTransferDecoder.submitFrame] 按 seed 去重，不会做无谓消元。
/// 面板会实时展示采样/解码帧率、接收速度、已用时间、新增/重复帧数、
/// 单块大小与文件数据等信息，便于诊断传输瓶颈。
class QrTransferScanScreen extends StatefulWidget {
  final Future<void> Function(Uint8List) onComplete;

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

  /// 会话开始时间：收到第一帧属于本传输的有效二维码时记录，
  /// 用于计算已用时间与各项帧率/速度指标。
  DateTime? _sessionStart;

  /// 每秒刷新一次面板上的时间与帧率显示（即使没有新帧到达）。
  Timer? _statsTimer;

  QrTransferDecodeProgress _progress = const QrTransferDecodeProgress(
    receivedSymbols: 0,
    innovativeSymbols: 0,
    sourceSymbolCount: 0,
    decodedSymbols: 0,
    isComplete: false,
  );
  String? _errorMessageKey;
  bool _finished = false;
  QrTransferDecompressionJob? _decompressionJob;
  int _transferGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_finished && _sessionStart != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _transferGeneration++;
    _decompressionJob?.cancel();
    _decompressionJob = null;
    _statsTimer?.cancel();
    _scannerController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (!mounted || _finished) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null) {
        continue;
      }
      try {
        final progress = _decoder.submitFrame(text);
        if (!mounted) {
          return;
        }
        _sessionStart ??= DateTime.now();
        setState(() {
          _progress = progress;
          _errorMessageKey = null;
        });
        if (progress.isComplete) {
          unawaited(_finish());
          return;
        }
      } on FormatException {
        // 非本协议二维码，静默忽略。
        continue;
      } on StateError catch (error) {
        final messageKey = _errorKeyFor(error.message.toString());
        if (messageKey == 'qr_transfer_session_mismatch') {
          if (!mounted || _errorMessageKey == messageKey) {
            continue;
          }
          setState(() {
            _errorMessageKey = messageKey;
          });
        } else {
          unawaited(_stopWithError(messageKey));
        }
      }
    }
  }

  String _errorKeyFor(String error) => qrTransferErrorKeyFor(error);

  Future<void> _stopWithError(String messageKey) async {
    if (_finished) {
      return;
    }
    _finished = true;
    try {
      await _scannerController.stop();
    } catch (_) {
      // The page is already entering an error state; camera teardown is best
      // effort and must not prevent the user from restarting the transfer.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessageKey = messageKey;
    });
  }

  Future<void> _finish() async {
    if (_finished) {
      return;
    }
    _finished = true;
    try {
      await _scannerController.stop();
    } catch (_) {
      // Stopping the camera is best effort after a successful decode.
    }
    if (!mounted) {
      return;
    }

    final generation = ++_transferGeneration;
    QrTransferDecompressionJob? job;
    try {
      job = await _decoder.startRawPayloadDecompression();
      if (!mounted || generation != _transferGeneration) {
        job.cancel();
        return;
      }
      _decompressionJob = job;
      final payload = await job.future;
      if (!mounted || generation != _transferGeneration) {
        return;
      }
      final info = _decoder.sessionInfo;
      if (info == null || payload.length != info.rawLength) {
        throw StateError('qr_transfer_raw_length_mismatch');
      }
      Navigator.of(context).pop();
      await widget.onComplete(payload);
    } on QrTransferDecompressionCancelled {
      return;
    } on StateError catch (error) {
      if (!mounted || generation != _transferGeneration) {
        return;
      }
      setState(() {
        _errorMessageKey = _errorKeyFor(error.message.toString());
      });
    } on Object {
      if (!mounted || generation != _transferGeneration) {
        return;
      }
      setState(() {
        _errorMessageKey = 'qr_transfer_decompression_failed';
      });
    } finally {
      if (identical(_decompressionJob, job)) {
        _decompressionJob = null;
      }
    }
  }

  Future<void> _resetTransfer() async {
    if (!mounted) {
      return;
    }
    _transferGeneration++;
    _decompressionJob?.cancel();
    _decompressionJob = null;
    _decoder.reset();
    setState(() {
      _finished = false;
      _errorMessageKey = null;
      _sessionStart = null;
      _progress = const QrTransferDecodeProgress(
        receivedSymbols: 0,
        innovativeSymbols: 0,
        sourceSymbolCount: 0,
        decodedSymbols: 0,
        isComplete: false,
      );
    });
    try {
      await _scannerController.start();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _finished = true;
        _errorMessageKey = 'qr_transfer_decode_failed';
      });
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
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildViewfinder(),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: _buildProgressPanel(l10n),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_finished && _errorMessageKey == null)
            _buildFinishedOverlay(l10n),
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

  String _errorText(AppLocalizations l10n) {
    return switch (_errorMessageKey) {
      'qr_transfer_session_mismatch' => l10n.qrTransferSessionMismatch,
      'qr_transfer_checksum_failed' => l10n.qrTransferChecksumFailed,
      'qr_transfer_raw_length_mismatch' => l10n.qrTransferRawLengthMismatch,
      'qr_transfer_decompression_failed' => l10n.qrTransferDecompressionFailed,
      'qr_transfer_decompression_output_too_large' =>
        l10n.qrTransferResourceLimit,
      'qr_transfer_session_expired' => l10n.qrTransferSessionExpired,
      'qr_transfer_frame_budget_exceeded' => l10n.qrTransferResourceLimit,
      'qr_transfer_unique_seed_limit' => l10n.qrTransferResourceLimit,
      'qr_transfer_adjacency_edge_budget_exceeded' =>
        l10n.qrTransferResourceLimit,
      _ => l10n.qrTransferDecodeFailed,
    };
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
                  HyperosLinearProgress(value: fraction),
                  const SizedBox(height: 12),
                  Text(
                    l10n.qrTransferReceiveProgress(
                      _progress.receivedSymbols,
                      _progress.decodedSymbols,
                      _progress.sourceSymbolCount,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  _buildStatsGrid(l10n),
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
                    _errorText(l10n),
                    style: TextStyle(color: HyperosColors.error(context)),
                  ),
                  const SizedBox(height: 10),
                  HyperosButton(
                    label: l10n.qrTransferRestart,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _resetTransfer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 会话开始至今的时长；未建立会话时为 0。
  Duration get _elapsed {
    final start = _sessionStart;
    if (start == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(start);
  }

  /// 传输信息网格：采样/解码帧率、接收速度、已用时间、
  /// 新增/重复帧、单块大小、数据块数，以及文件数据。
  Widget _buildStatsGrid(AppLocalizations l10n) {
    final p = _progress;
    final info = _decoder.sessionInfo;
    final elapsedMs = _elapsed.inMilliseconds;
    final seconds = elapsedMs / 1000.0;
    final sampleFps = seconds > 0 ? p.detectedSymbols / seconds : 0.0;
    final decodeFps = seconds > 0 ? p.receivedSymbols / seconds : 0.0;
    final speedBps = seconds > 0
        ? p.innovativeSymbols * (info?.symbolSize ?? 0) / seconds
        : 0.0;

    final blocks = [
      _StatTile(
        label: l10n.qrTransferSampleFps,
        value: '${sampleFps.toStringAsFixed(1)} fps',
      ),
      _StatTile(
        label: l10n.qrTransferDecodeFps,
        value: '${decodeFps.toStringAsFixed(1)} fps',
      ),
      _StatTile(
        label: l10n.qrTransferReceiveSpeed,
        value: _formatSpeed(speedBps),
      ),
      _StatTile(label: l10n.qrTransferElapsed, value: _formatElapsed(_elapsed)),
      _StatTile(
        label: l10n.qrTransferNewFrames,
        value: '${p.innovativeSymbols}',
        valueColor: Colors.greenAccent,
      ),
      _StatTile(
        label: l10n.qrTransferDuplicateFrames,
        value: '${p.duplicateSymbols}',
        valueColor: Colors.orangeAccent,
      ),
      _StatTile(
        label: l10n.qrTransferBlockSize,
        value: _formatBytes(info?.symbolSize ?? 0),
      ),
      _StatTile(
        label: l10n.qrTransferBlockCount,
        value: '${p.sourceSymbolCount}',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: blocks[i]),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < blocks.length ? blocks[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ],
        if (info != null) ...[
          const SizedBox(height: 8),
          _StatTile(
            label: l10n.qrTransferFileData,
            value: l10n.qrTransferFileDataDetail(
              _formatBytes(info.rawLength),
              _formatBytes(info.payloadLength),
            ),
          ),
        ],
      ],
    );
  }

  /// 将字节/秒格式化为易读的速度文本。
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  /// 将字节数格式化为易读的容量文本。
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// 将时长格式化为 mm:ss 或 hh:mm:ss。
  String _formatElapsed(Duration duration) {
    String two(int v) => v.toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${two(duration.inHours)}:'
          '${two(duration.inMinutes % 60)}:'
          '${two(duration.inSeconds % 60)}';
    }
    return '${two(duration.inMinutes)}:${two(duration.inSeconds % 60)}';
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

/// 接收面板中的一个指标卡片：标签（小字）+ 数值（大字）。
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    const half = _cornerThickness / 2;

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
