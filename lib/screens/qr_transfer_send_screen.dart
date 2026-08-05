import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../services/qr_transfer/qr_transfer_codec.dart';
import '../services/qr_transfer/qr_transfer_frame_worker.dart';
import '../services/qr_transfer/qr_transfer_session.dart';

/// 发送端全屏二维码流页面。
///
/// 把传入的备份字节流式编码成逐帧二维码播放，对方手机摄像头
/// 对准屏幕即可完成接收；码流可无限延续，直到用户手动停止。
///
/// 性能要点：LT 编码 + base64 + QR 矩阵计算全部**提前**完成（见
/// [QrTransferEncoder.frameTextFor] 与 [_qrCache]），帧切换时 UI 线程
/// 只做一次赋值，因此可以把帧间隔压到 250ms 而不卡顿。
///
/// 帧率取值：摄像头通常 100~300ms 即可稳定识别一帧，250ms（4 FPS）在
/// 识别余量与吞吐之间取平衡；LT 码本身抗丢帧，偶尔漏扫一帧不影响解码。
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
  /// 帧间隔。摄像头通常 100~300ms 即可识别一帧，250ms（4 FPS）在
  /// 识别余量与吞吐之间取平衡；LT 码本身抗丢帧，偶尔漏扫一帧也不影响解码。
  static const Duration _frameInterval = QrTransferLimits.frameInterval;

  /// 提前预计算的帧数：当前帧之前先把未来四帧的 QR 矩阵算好，
  /// 把耗时移出 setState 关键路径，并为 250ms 帧间隔留足缓冲。
  static const int _precomputeLookahead = 4;

  /// 缓存最近若干帧的矩阵，避免旧帧无限堆积内存。
  static const int _cacheRetention = 32;

  QrTransferFrameWorker? _worker;
  QrTransferSessionInfo? _sessionInfo;
  QrTransferEncoder? _fallbackEncoder;
  Timer? _frameTimer;
  int _currentSeed = 0;
  int _nextSeedToRequest = 0;
  bool _frameRequestInFlight = false;
  Object? _preparationError;
  final Map<int, QrTransferMatrix> _qrCache = {};
  String? _errorMessageKey;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeQrStream());
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    unawaited(_worker?.dispose());
    super.dispose();
  }

  Future<void> _initializeQrStream() async {
    try {
      final worker = await QrTransferFrameWorker.start(widget.payloadBytes);
      if (!mounted) {
        await worker.dispose();
        return;
      }
      _worker = worker;
      _sessionInfo = worker.info;
      await _requestFramesThrough(_precomputeLookahead);
      if (!mounted) {
        return;
      }
      _frameTimer = Timer.periodic(_frameInterval, (_) => _advanceFrame());
      setState(() {});
    } on Object catch (error, stackTrace) {
      debugPrint('QR background worker failed: $error\n$stackTrace');
      final worker = _worker;
      _worker = null;
      unawaited(worker?.dispose());
      await _initializeQrStreamOnMain();
    }
  }

  Future<void> _initializeQrStreamOnMain() async {
    if (!mounted) {
      return;
    }
    try {
      _fallbackEncoder = QrTransferEncoder.prepare(widget.payloadBytes);
      _sessionInfo = _fallbackEncoder!.info;
      await _requestFramesThrough(_precomputeLookahead);
      if (!mounted) {
        return;
      }
      _frameTimer = Timer.periodic(_frameInterval, (_) => _advanceFrame());
      setState(() {});
    } on Object catch (error, stackTrace) {
      debugPrint('QR preparation failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _preparationError = error;
      });
    }
  }

  void _advanceFrame() {
    if (!mounted) {
      return;
    }
    final nextSeed = _currentSeed + 1;
    if (nextSeed >= QrTransferLimits.maxUniqueSeedCount) {
      _frameTimer?.cancel();
      setState(() {
        _errorMessageKey = 'qr_transfer_frame_budget_exceeded';
      });
      return;
    }
    if (!_qrCache.containsKey(nextSeed)) {
      unawaited(_requestFramesThrough(nextSeed + _precomputeLookahead));
      return;
    }
    setState(() {
      _currentSeed = nextSeed;
    });
    _trimCache();
    unawaited(_requestFramesThrough(nextSeed + _precomputeLookahead));
  }

  Future<void> _requestFramesThrough(int maxSeed) async {
    final cappedMaxSeed = maxSeed < QrTransferLimits.maxUniqueSeedCount
        ? maxSeed
        : QrTransferLimits.maxUniqueSeedCount - 1;
    if (!mounted ||
        _frameRequestInFlight ||
        _preparationError != null ||
        cappedMaxSeed < _nextSeedToRequest) {
      return;
    }
    final worker = _worker;
    final fallbackEncoder = _fallbackEncoder;
    if (worker == null && fallbackEncoder == null) {
      return;
    }

    final startSeed = _nextSeedToRequest;
    final requestedCount = cappedMaxSeed - startSeed + 1;
    final batchCount = requestedCount > 16 ? 16 : requestedCount;
    _frameRequestInFlight = true;
    try {
      final frames = worker != null
          ? await worker.generate(startSeed: startSeed, count: batchCount)
          : _generateFallbackFrames(
              fallbackEncoder!,
              startSeed: startSeed,
              count: batchCount,
            );
      if (!mounted) {
        return;
      }
      for (final frame in frames) {
        _qrCache[frame.seed] = frame;
      }
      _nextSeedToRequest = startSeed + frames.length;
      if (mounted) {
        setState(() {});
      }
    } on Object catch (error, stackTrace) {
      debugPrint('QR frame batch failed: $error\n$stackTrace');
      _frameTimer?.cancel();
      _frameTimer = null;
      if (mounted) {
        setState(() {
          _preparationError = error;
        });
      }
    } finally {
      _frameRequestInFlight = false;
      if (mounted &&
          _preparationError == null &&
          _nextSeedToRequest <= cappedMaxSeed &&
          identical(worker, _worker)) {
        unawaited(_requestFramesThrough(cappedMaxSeed));
      }
    }
  }

  List<QrTransferMatrix> _generateFallbackFrames(
    QrTransferEncoder encoder, {
    required int startSeed,
    required int count,
  }) {
    return List<QrTransferMatrix>.generate(
      count,
      (offset) => qrTransferMatrixForText(
        encoder.frameTextFor(startSeed + offset),
        seed: startSeed + offset,
      ),
      growable: false,
    );
  }

  /// 只保留当前帧附近的矩阵，符号流理论上无限，缓存必须收敛。
  void _trimCache() {
    final cutoff = _currentSeed - _cacheRetention;
    if (cutoff <= 0) {
      return;
    }
    _qrCache.removeWhere((seed, _) => seed < cutoff);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // LT 码通常需要略多于源码符号数的编码符号即可解出，按 1.2 倍估算。
    final sourceSymbolCount = _sessionInfo?.sourceSymbolCount ?? 0;
    final estimatedTotalFrames = sourceSymbolCount == 0
        ? 0
        : (sourceSymbolCount * 1.2).ceil();
    final emittedFrames = _currentSeed + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _DarkGradientBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(l10n),
                Expanded(child: _buildQrCard()),
                _buildBottomPanel(l10n, emittedFrames, estimatedTotalFrames),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return MiuixSmallTopAppBar(
      title: widget.title,
      titleColor: Colors.white,
      color: Colors.transparent,
      navigationIcon: HyperosIconButton(
        icon: Icons.close,
        color: Colors.white,
        onPressed: () => Navigator.pop(context),
        tooltip: l10n.closeAction,
      ),
    );
  }

  Widget _buildQrCard() {
    final matrix = _qrCache[_currentSeed];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.16),
                  blurRadius: 48,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: RepaintBoundary(
              child: _preparationError != null
                  ? const Center(
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Colors.black54,
                        size: 48,
                      ),
                    )
                  : matrix == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black54),
                    )
                  : Semantics(
                      label: 'QR code',
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: CustomPaint(
                          painter: _QrTransferMatrixPainter(matrix),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(
    AppLocalizations l10n,
    int emittedFrames,
    int estimatedTotalFrames,
  ) {
    final progress = estimatedTotalFrames <= 0
        ? 0.0
        : (emittedFrames / estimatedTotalFrames).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.qrTransferFrameProgress(
                        emittedFrames,
                        estimatedTotalFrames,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                HyperosLinearProgress(value: progress, minHeight: 4),
                const SizedBox(height: 12),
                Text(
                  l10n.qrTransferSendHint,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (_errorMessageKey != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.qrTransferResourceLimit,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ],
                const SizedBox(height: 16),
                HyperosButton(
                  label: l10n.qrTransferStop,
                  variant: HyperosButtonVariant.destructive,
                  expand: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrTransferMatrixPainter extends CustomPainter {
  const _QrTransferMatrixPainter(this.matrix);

  final QrTransferMatrix matrix;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.shortestSide;
    if (edge <= 0 || matrix.moduleCount <= 0) {
      return;
    }
    final moduleSize = edge / matrix.moduleCount;
    final paint = Paint()..color = Colors.black;
    for (var row = 0; row < matrix.moduleCount; row++) {
      for (var column = 0; column < matrix.moduleCount; column++) {
        if (!matrix.isDark(row, column)) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            column * moduleSize,
            row * moduleSize,
            moduleSize,
            moduleSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrTransferMatrixPainter oldDelegate) {
    return oldDelegate.matrix != matrix;
  }
}

/// 发送页暗色底：顶部略亮、向下过渡到纯黑，让白色二维码卡片更突出。
class _DarkGradientBackground extends StatelessWidget {
  const _DarkGradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.7),
          radius: 1.4,
          colors: const [Color(0xFF232C3A), Color(0xFF14171D), Colors.black],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
