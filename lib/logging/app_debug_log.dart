import 'package:flutter/foundation.dart';

/// Unified debug console logging with Chinese messages.
void appDebugLog(String tag, String message) {
  // Always print for forensic tags so profile/release diagnostics can be
  // captured from logcat even when kDebugMode is false.
  const forensicTags = <String>{'LocationTimeApply', 'LocationTimeApplyUI'};
  if (!kDebugMode && !forensicTags.contains(tag)) {
    return;
  }
  debugPrint('[$tag] $message');
}
