import 'package:flutter/foundation.dart';

/// Unified debug console logging with Chinese messages.
void appDebugLog(String tag, String message) {
  if (!kDebugMode) {
    return;
  }
  debugPrint('[$tag] $message');
}
