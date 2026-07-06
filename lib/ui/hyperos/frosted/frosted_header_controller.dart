import '../../../logging/app_debug_log.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../models/timetable_settings.dart';
import '../../../services/frosted_blur_service.dart';
import '../hyperos_header_diag.dart';
import 'frosted_capture.dart';

class _BackdropRequest {
  const _BackdropRequest({
    required this.source,
    required this.forceFullCapture,
    required this.allowBlur,
  });

  final String source;
  final bool forceFullCapture;
  final bool allowBlur;

  _BackdropRequest mergedWith(_BackdropRequest other) {
    return _BackdropRequest(
      source: other.source,
      forceFullCapture: forceFullCapture || other.forceFullCapture,
      allowBlur: other.allowBlur,
    );
  }
}

/// Schedules downsampled captures and supplies cached blur images for CFH headers.
class FrostedHeaderController extends ChangeNotifier {
  FrostedHeaderController();

  /// Fast crop refresh while scrolling (target ~60fps feel).
  static const _scrollUpdateThrottle = Duration(milliseconds: 16);

  /// Full viewport capture while scrolling (refresh lazy list tiles).
  static const _scrollFullThrottle = Duration(milliseconds: 140);

  /// Blur refresh while scrolling (keeps frosted look without per-frame cost).
  static const _scrollBlurThrottle = Duration(milliseconds: 100);

  static const _idleDebounce = Duration(milliseconds: 100);

  /// Keep in sync with [TimetableSettings.defaultFrostedSheetBlurSigma].
  static const _blurSigmaLogical =
      TimetableSettings.defaultFrostedSheetBlurSigma;

  GlobalKey? _boundaryKey;
  bool _captureEnabled = false;
  bool _isUserScrolling = false;
  bool _isCapturingSnapshot = false;
  DateTime? _lastPreviewAt;
  DateTime? _lastFullCaptureAt;
  DateTime? _lastBlurAt;
  Timer? _idleTimer;
  ui.Image? _blurredImage;
  ui.Image? _previewImage;
  ui.Image? _rawFull;
  double _lastScrollPixels = 0;
  double _captureScrollPixels = 0;
  bool _pendingUpdate = false;
  int _blurGeneration = 0;
  final Set<ui.Image> _pendingRelease = {};
  _BackdropRequest? _queuedBackdrop;
  bool _backdropDrainRunning = false;

  /// Always prefer blurred frosted frame; preview is a fallback while blur catches up.
  ui.Image? get displayImage =>
      resolveDisplayImage(preview: _previewImage, blurred: _blurredImage);

  bool get isPreviewActive =>
      resolvePreviewActive(preview: _previewImage, blurred: _blurredImage);

  bool get isCapturing => _isCapturingSnapshot;

  @visibleForTesting
  bool get debugIsUserScrolling => _isUserScrolling;

  @visibleForTesting
  static ui.Image? resolveDisplayImage({ui.Image? preview, ui.Image? blurred}) {
    return blurred ?? preview;
  }

  @visibleForTesting
  static bool resolvePreviewActive({ui.Image? preview, ui.Image? blurred}) {
    return blurred == null && preview != null;
  }

  @visibleForTesting
  static bool shouldScheduleBlur({
    required bool allowBlur,
    required bool throttleScrollBlur,
  }) {
    return allowBlur && !throttleScrollBlur;
  }

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
      _isUserScrolling = false;
      _blurGeneration++;
      _disposeCaches();
      _logDisplayMode();
    } else {
      scheduleFullRefresh(source: 'capture_enabled');
    }
  }

  void onScrollNotification(ScrollNotification notification) {
    if (!_captureEnabled) {
      return;
    }
    _lastScrollPixels = notification.metrics.pixels;
    if (notification is ScrollStartNotification) {
      _setUserScrolling(true);
      _scheduleThrottledUpdate(
        source: 'scroll',
        preferFullCapture: _needsFullRecaptureForScrollDelta(),
        allowBlur: true,
      );
    } else if (notification is ScrollUpdateNotification) {
      _scheduleThrottledUpdate(
        source: 'scroll',
        preferFullCapture: _needsFullRecaptureForScrollDelta(),
        allowBlur: true,
      );
    } else if (notification is ScrollEndNotification) {
      _onScrollEnd();
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
      _requestBackdropUpdate(
        source: source,
        forceFullCapture: true,
        allowBlur: true,
      );
    });
  }

  void _requestBackdropUpdate({
    required String source,
    required bool forceFullCapture,
    required bool allowBlur,
  }) {
    if (!_captureEnabled) {
      return;
    }
    final incoming = _BackdropRequest(
      source: source,
      forceFullCapture: forceFullCapture,
      allowBlur: allowBlur,
    );
    final queued = _queuedBackdrop;
    _queuedBackdrop = queued == null ? incoming : queued.mergedWith(incoming);
    if (_backdropDrainRunning) {
      return;
    }
    unawaited(_drainBackdropQueue());
  }

  Future<void> _drainBackdropQueue() async {
    if (_backdropDrainRunning) {
      return;
    }
    _backdropDrainRunning = true;
    try {
      while (_queuedBackdrop != null && _captureEnabled) {
        final request = _queuedBackdrop!;
        _queuedBackdrop = null;
        await _performBackdropUpdate(
          source: request.source,
          forceFullCapture: request.forceFullCapture,
          allowBlur: request.allowBlur,
        );
      }
    } finally {
      _backdropDrainRunning = false;
      if (_queuedBackdrop != null && _captureEnabled) {
        unawaited(_drainBackdropQueue());
      }
    }
  }

  void _setUserScrolling(bool scrolling) {
    if (_isUserScrolling == scrolling) {
      return;
    }
    _isUserScrolling = scrolling;
    _logDisplayMode();
    notifyListeners();
  }

  void _onScrollEnd() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _requestBackdropUpdate(
        source: 'scroll_end',
        forceFullCapture: false,
        allowBlur: true,
      );
    });
    _scheduleIdleCapture();
  }

  void _scheduleThrottledUpdate({
    required String source,
    required bool preferFullCapture,
    required bool allowBlur,
  }) {
    final now = DateTime.now();
    final last = _lastPreviewAt;
    if (last != null && now.difference(last) < _scrollUpdateThrottle) {
      _pendingUpdate = true;
      return;
    }
    _pendingUpdate = false;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _requestBackdropUpdate(
        source: source,
        forceFullCapture: preferFullCapture,
        allowBlur: allowBlur,
      );
    });
  }

  void _scheduleIdleCapture() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleDebounce, () {
      unawaited(_onScrollSettled());
    });
  }

  Future<void> _onScrollSettled() async {
    if (!_captureEnabled) {
      return;
    }
    _flushPendingScrollUpdate();
    _setUserScrolling(false);
    _requestBackdropUpdate(
      source: 'scroll_idle',
      forceFullCapture: true,
      allowBlur: true,
    );
  }

  void _flushPendingScrollUpdate() {
    if (!_pendingUpdate || !_captureEnabled) {
      return;
    }
    _pendingUpdate = false;
  }

  bool _needsFullRecaptureForScrollDelta() {
    final raw = _rawFull;
    final context = _boundaryKey?.currentContext;
    if (raw == null || context == null) {
      return true;
    }
    final stripHeight = FrostedCapture.headerStripHeightLogical(context);
    final maxScrollLogical =
        (raw.height / FrostedCapture.headerPixelRatio) - stripHeight;
    if (maxScrollLogical <= 0) {
      return true;
    }
    final delta = (_lastScrollPixels - _captureScrollPixels).abs();
    return delta > maxScrollLogical;
  }

  bool _shouldThrottleScrollBlur() {
    if (!_isUserScrolling) {
      return false;
    }
    final last = _lastBlurAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) < _scrollBlurThrottle;
  }

  bool _shouldThrottleFullCapture(String source) {
    if (!source.startsWith('scroll') || source == 'scroll_idle') {
      return false;
    }
    final last = _lastFullCaptureAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) < _scrollFullThrottle;
  }

  Future<void> _performBackdropUpdate({
    required String source,
    required bool forceFullCapture,
    bool allowBlur = true,
  }) async {
    if (!_captureEnabled) {
      return;
    }

    final key = _boundaryKey;
    if (key == null) {
      return;
    }

    var doFullCapture =
        forceFullCapture ||
        _rawFull == null ||
        _needsFullRecaptureForScrollDelta();
    if (doFullCapture && _shouldThrottleFullCapture(source)) {
      if (_rawFull == null) {
        return;
      }
      doFullCapture = false;
    }

    if (doFullCapture) {
      if (_isCapturingSnapshot) {
        if (_rawFull == null) {
          _pendingUpdate = true;
          return;
        }
        doFullCapture = false;
      } else {
        _isCapturingSnapshot = true;
        try {
          final snapshot = await FrostedCapture.fromBoundaryOpaque(key);
          if (!_captureEnabled) {
            _releaseImage(snapshot);
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
          final previousRaw = _rawFull;
          _rawFull = snapshot;
          _clearLiveImage(raw: previousRaw);
          _captureScrollPixels = _lastScrollPixels;
          _lastFullCaptureAt = DateTime.now();
        } finally {
          _isCapturingSnapshot = false;
          if (_pendingUpdate && _captureEnabled) {
            _pendingUpdate = false;
            _scheduleThrottledUpdate(
              source: 'scroll_pending_capture',
              preferFullCapture: _needsFullRecaptureForScrollDelta(),
              allowBlur: true,
            );
          }
        }
      }
    }

    final raw = _rawFull;
    final context = key.currentContext;
    if (raw == null || context == null) {
      if (doFullCapture) {
        return;
      }
      await _performBackdropUpdate(
        source: '${source}_no_raw',
        forceFullCapture: true,
        allowBlur: allowBlur,
      );
      return;
    }

    final scrollDelta = _lastScrollPixels - _captureScrollPixels;
    final stripHeightLogical = FrostedCapture.headerStripHeightLogical(context);
    final visibleHeightLogical = FrostedCapture.headerVisibleHeightLogical(
      context,
    );

    final stripWithBleed = await FrostedCapture.cropHeaderStripFromSnapshot(
      raw,
      context: context,
      stripHeightLogical: stripHeightLogical,
      visibleHeightLogical: visibleHeightLogical,
      scrollOffsetLogical: scrollDelta,
    );
    if (!_captureEnabled) {
      _releaseImage(stripWithBleed);
      return;
    }
    if (stripWithBleed == null) {
      await _performBackdropUpdate(
        source: '${source}_recapture',
        forceFullCapture: true,
        allowBlur: allowBlur,
      );
      return;
    }

    _lastPreviewAt = DateTime.now();

    final willBlur = shouldScheduleBlur(
      allowBlur: allowBlur,
      throttleScrollBlur: _shouldThrottleScrollBlur(),
    );
    final previewStrip = await FrostedCapture.cropTopToVisible(
      stripWithBleed,
      visibleHeightLogical: visibleHeightLogical,
    );
    if (!_captureEnabled) {
      _releaseImage(stripWithBleed);
      _releaseImage(previewStrip);
      return;
    }
    if (previewStrip == null) {
      _releaseImage(stripWithBleed);
      return;
    }

    final generation = ++_blurGeneration;
    if (_blurredImage == null) {
      _applyPreview(previewStrip);
    }

    if (willBlur) {
      _lastBlurAt = DateTime.now();
      unawaited(
        _blurStripAsync(
          stripWithBleed,
          generation: generation,
          source: source,
          fullCapture: doFullCapture,
          visibleHeightLogical: visibleHeightLogical,
          previewStrip: previewStrip,
        ),
      );
      return;
    }

    if (_blurredImage == null) {
      _applyPreview(previewStrip);
    }
    if (!identical(previewStrip, stripWithBleed)) {
      _releaseImage(stripWithBleed);
    }
  }

  void _applyPreview(ui.Image strip) {
    final previous = _previewImage;
    _previewImage = strip;
    _clearLiveImage(preview: previous);
    notifyListeners();
  }

  Future<void> _blurStripAsync(
    ui.Image stripWithBleed, {
    required int generation,
    required String source,
    required bool fullCapture,
    required double visibleHeightLogical,
    required ui.Image previewStrip,
  }) async {
    final sigmaPx = _blurSigmaLogical * FrostedCapture.headerPixelRatio;
    final blurredFull = await FrostedBlurService.blurImage(
      stripWithBleed,
      sigmaPx: sigmaPx,
      disposeSource: false,
    );

    if (!_captureEnabled || generation != _blurGeneration) {
      _releaseImage(blurredFull);
      _releaseImage(stripWithBleed);
      _flushPendingIfScrolling();
      return;
    }

    _releaseImage(stripWithBleed);

    if (blurredFull == null) {
      HyperosHeaderDiag.log('frosted_capture', {
        'ok': false,
        'source': source,
        'reason': 'blur_null',
      });
      notifyListeners();
      _flushPendingIfScrolling();
      return;
    }

    final blurred = await FrostedCapture.cropTopToVisible(
      blurredFull,
      visibleHeightLogical: visibleHeightLogical,
    );
    if (!_captureEnabled || generation != _blurGeneration) {
      _releaseImage(blurred);
      _releaseImage(blurredFull);
      _flushPendingIfScrolling();
      return;
    }
    if (blurred == null) {
      _releaseImage(blurredFull);
      _flushPendingIfScrolling();
      return;
    }
    if (!identical(blurred, blurredFull)) {
      _releaseImage(blurredFull);
    }

    final previousBlurred = _blurredImage;
    if (identical(_previewImage, previewStrip)) {
      _previewImage = null;
    }
    _blurredImage = blurred;
    _clearLiveImage(blurred: previousBlurred);
    if (!identical(_previewImage, previewStrip) &&
        !identical(_blurredImage, previewStrip)) {
      _releaseImage(previewStrip);
    }
    HyperosHeaderDiag.log('frosted_capture', {
      'ok': true,
      'source': source,
      'width': blurred.width,
      'height': blurred.height,
      'scrollPixels': _lastScrollPixels,
      'captureScroll': _captureScrollPixels,
      'fullCapture': fullCapture,
      'blurEngine': FrostedBlurService.lastBlurEngine,
      'preview': false,
    });
    notifyListeners();

    if (_pendingUpdate && _captureEnabled) {
      _pendingUpdate = false;
      _scheduleThrottledUpdate(
        source: 'scroll_pending',
        preferFullCapture: _needsFullRecaptureForScrollDelta(),
        allowBlur: true,
      );
    }
  }

  void _flushPendingIfScrolling() {
    if (!_pendingUpdate || !_captureEnabled || !_isUserScrolling) {
      return;
    }
    _pendingUpdate = false;
    _scheduleThrottledUpdate(
      source: 'scroll_pending',
      preferFullCapture: _needsFullRecaptureForScrollDelta(),
      allowBlur: true,
    );
  }

  void _logDisplayMode() {
    if (!kDebugMode) {
      return;
    }
    final mode = _isUserScrolling ? 'scroll_blur' : 'idle_blur';
    appDebugLog('FrostedHeader', '模式=$mode');
  }

  /// Drop [ui.Image] after the current frame so [RawImage] is not painting it.
  ///
  /// A per-frame strong-reference set prevents disposing the same image twice
  /// while it is still referenced, and is cleared each frame so disposed images
  /// can be GC'd (unlike [identityHashCode] bookkeeping, which could leak after
  /// the hash was reused by a newly allocated image).
  void _releaseImage(ui.Image? image) {
    if (image == null) {
      return;
    }
    if (!_pendingRelease.add(image)) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      image.dispose();
      _pendingRelease.remove(image);
    });
  }

  void _clearLiveImage({ui.Image? blurred, ui.Image? preview, ui.Image? raw}) {
    _releaseImage(blurred);
    _releaseImage(preview);
    _releaseImage(raw);
  }

  void _disposeCaches() {
    _queuedBackdrop = null;
    final blurred = _blurredImage;
    final preview = _previewImage;
    final raw = _rawFull;
    _blurredImage = null;
    _previewImage = null;
    _rawFull = null;
    _clearLiveImage(blurred: blurred, preview: preview, raw: raw);
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _blurGeneration++;
    _disposeCaches();
    super.dispose();
  }
}
