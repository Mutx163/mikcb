import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../services/frosted_blur_service.dart';
import '../hyperos_header_diag.dart';
import 'frosted_capture.dart';

/// Schedules downsampled captures and supplies cached blur images for CFH headers.
class FrostedHeaderController extends ChangeNotifier {
  FrostedHeaderController();

  /// Fast recrop from cached full snapshot while scrolling.
  static const _scrollRecropThrottle = Duration(milliseconds: 32);

  /// Full viewport capture while scrolling (fallback when cache misses).
  static const _scrollFullThrottle = Duration(milliseconds: 120);

  static const _idleDebounce = Duration(milliseconds: 200);

  /// Keep in sync with [HyperosBlurredHeader.blurSigma].
  static const _blurSigmaLogical = 10.0;

  GlobalKey? _boundaryKey;
  bool _captureEnabled = false;
  bool _isCapturing = false;
  DateTime? _lastRecropAt;
  DateTime? _lastFullCaptureAt;
  Timer? _idleTimer;
  ui.Image? _blurredImage;
  ui.Image? _rawFull;
  double _lastScrollPixels = 0;
  double _captureScrollPixels = 0;
  bool _pendingRecrop = false;

  ui.Image? get blurredImage => _blurredImage;
  bool get isCapturing => _isCapturing;

  void attach({required GlobalKey boundaryKey}) {
    _boundaryKey = boundaryKey;
  }

  set captureEnabled(bool value) {
    if (_captureEnabled == value) {
      return;
    }
    _captureEnabled = value;
    if (!value) {
      _idleTimer?.cancel();
      _rawFull?.dispose();
      _rawFull = null;
    } else {
      scheduleFullRefresh(source: 'capture_enabled');
    }
  }

  void onScrollNotification(ScrollNotification notification) {
    if (!_captureEnabled) {
      return;
    }
    _lastScrollPixels = notification.metrics.pixels;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      _scheduleThrottledRecrop(source: 'scroll');
    }
    if (notification is ScrollEndNotification) {
      _scheduleIdleCapture();
    }
  }

  void scheduleRefresh({required String source}) {
    scheduleFullRefresh(source: source);
  }

  void scheduleFullRefresh({required String source}) {
    if (!_captureEnabled) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_captureFullAndBlur(source: source));
    });
  }

  void _scheduleThrottledRecrop({required String source}) {
    final now = DateTime.now();
    final last = _lastRecropAt;
    if (last != null && now.difference(last) < _scrollRecropThrottle) {
      _pendingRecrop = true;
      return;
    }
    _pendingRecrop = false;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_recropAndBlur(source: source));
    });
  }

  void _scheduleIdleCapture() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleDebounce, () {
      scheduleFullRefresh(source: 'scroll_idle');
    });
  }

  Future<void> _recropAndBlur({required String source}) async {
    if (!_captureEnabled || _isCapturing) {
      _pendingRecrop = true;
      return;
    }
    final key = _boundaryKey;
    final raw = _rawFull;
    final context = key?.currentContext;
    if (key == null || raw == null || context == null) {
      await _captureFullAndBlur(source: '${source}_no_cache');
      return;
    }

    final scrollDelta = _lastScrollPixels - _captureScrollPixels;
    final stripHeightLogical = FrostedCapture.headerStripHeightLogical(context);
    final visibleHeightLogical = FrostedCapture.headerVisibleHeightLogical(
      context,
    );
    _isCapturing = true;
    try {
      final strip = await FrostedCapture.cropHeaderStripFromSnapshot(
        raw,
        stripHeightLogical: stripHeightLogical,
        visibleHeightLogical: visibleHeightLogical,
        scrollOffsetLogical: scrollDelta,
      );
      if (!_captureEnabled) {
        strip?.dispose();
        return;
      }
      if (strip == null) {
        await _captureFullAndBlur(source: '${source}_recapture');
        return;
      }

      final blurred = await _blurStrip(strip);
      if (blurred == null) {
        return;
      }

      _lastRecropAt = DateTime.now();
      _applyBlurredImage(blurred, source: source, fullCapture: false);
    } finally {
      _isCapturing = false;
      if (_pendingRecrop && _captureEnabled) {
        _pendingRecrop = false;
        _scheduleThrottledRecrop(source: 'scroll_pending');
      }
    }
  }

  Future<void> _captureFullAndBlur({required String source}) async {
    if (!_captureEnabled || _isCapturing) {
      return;
    }
    final now = DateTime.now();
    final last = _lastFullCaptureAt;
    if (last != null &&
        now.difference(last) < _scrollFullThrottle &&
        source.startsWith('scroll')) {
      return;
    }

    final key = _boundaryKey;
    if (key == null) {
      return;
    }

    _isCapturing = true;
    try {
      final snapshot = await FrostedCapture.fromBoundary(key);
      if (!_captureEnabled) {
        snapshot?.dispose();
        return;
      }
      if (snapshot == null) {
        HyperosHeaderDiag.log('frosted_capture', {
          'ok': false,
          'source': source,
          'reason': 'snapshot_null',
        });
        return;
      }

      _rawFull?.dispose();
      _rawFull = snapshot;
      _captureScrollPixels = _lastScrollPixels;

      final context = key.currentContext;
      if (context == null) {
        return;
      }

      final stripHeightLogical = FrostedCapture.headerStripHeightLogical(
        context,
      );
      final visibleHeightLogical = FrostedCapture.headerVisibleHeightLogical(
        context,
      );

      final strip = await FrostedCapture.cropHeaderStripFromSnapshot(
        snapshot,
        stripHeightLogical: stripHeightLogical,
        visibleHeightLogical: visibleHeightLogical,
      );
      if (!_captureEnabled) {
        strip?.dispose();
        return;
      }
      if (strip == null) {
        HyperosHeaderDiag.log('frosted_capture', {
          'ok': false,
          'source': source,
          'reason': 'strip_null',
        });
        return;
      }

      final blurred = await _blurStrip(strip);
      if (blurred == null) {
        return;
      }

      _lastFullCaptureAt = DateTime.now();
      _lastRecropAt = _lastFullCaptureAt;
      _applyBlurredImage(blurred, source: source, fullCapture: true);
    } finally {
      _isCapturing = false;
    }
  }

  Future<ui.Image?> _blurStrip(ui.Image strip) async {
    final sigmaPx = _blurSigmaLogical * FrostedCapture.headerPixelRatio;
    final blurred = await FrostedBlurService.blurImage(strip, sigmaPx: sigmaPx);
    if (!_captureEnabled) {
      blurred?.dispose();
      return null;
    }
    if (blurred == null) {
      HyperosHeaderDiag.log('frosted_capture', {
        'ok': false,
        'reason': 'blur_null',
      });
      return null;
    }
    return blurred;
  }

  void _applyBlurredImage(
    ui.Image blurred, {
    required String source,
    required bool fullCapture,
  }) {
    _blurredImage?.dispose();
    _blurredImage = blurred;
    HyperosHeaderDiag.log('frosted_capture', {
      'ok': true,
      'source': source,
      'width': blurred.width,
      'height': blurred.height,
      'scrollPixels': _lastScrollPixels,
      'captureScroll': _captureScrollPixels,
      'fullCapture': fullCapture,
      'blurEngine': FrostedBlurService.lastBlurEngine,
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _blurredImage?.dispose();
    _blurredImage = null;
    _rawFull?.dispose();
    _rawFull = null;
    super.dispose();
  }
}
