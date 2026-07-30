import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bundled_assets.dart';

/// Returns a positive cache dimension or null (0/negative → no constraint).
int? _sanitizeCacheDimension(int? value) =>
    (value != null && value > 0) ? value : null;

/// Displays a bundled image from [BundledAssets] or loads it on demand.
///
/// Prefer warming assets in [BundledAssets.warmUp] at startup so the first
/// frame already shows the real bitmap.
class BundledAssetImage extends StatelessWidget {
  const BundledAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final cached = BundledAssets.bytesFor(assetPath);
    if (cached != null) {
      return Image.memory(
        cached,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: _sanitizeCacheDimension(cacheWidth),
        cacheHeight: _sanitizeCacheDimension(cacheHeight),
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }

    return _BundledAssetImageLoader(
      assetPath: assetPath,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }
}

class _BundledAssetImageLoader extends StatefulWidget {
  const _BundledAssetImageLoader({
    required this.assetPath,
    this.width,
    this.height,
    required this.fit,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  State<_BundledAssetImageLoader> createState() =>
      _BundledAssetImageLoaderState();
}

class _BundledAssetImageLoaderState extends State<_BundledAssetImageLoader> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      if (!mounted) {
        return;
      }
      final bytes = data.buffer.asUint8List();
      BundledAssets.remember(widget.assetPath, bytes);
      setState(() {
        _bytes = bytes;
      });
    } catch (_) {
      // Leave empty; never substitute a fake icon for a missing asset.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    return Image.memory(
      bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: _sanitizeCacheDimension(widget.cacheWidth),
      cacheHeight: _sanitizeCacheDimension(widget.cacheHeight),
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
