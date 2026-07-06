import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug-only diagnostics for HyperOS blurred header layout decisions.
abstract final class HyperosHeaderDiag {
  static const _tag = '[HyperosHeader]';

  static void log(String event, Map<String, Object?> fields) {
    if (!kDebugMode) {
      return;
    }
    final buffer = StringBuffer('$_tag $event');
    for (final entry in fields.entries) {
      buffer.write(' | ${entry.key}=${entry.value}');
    }
    final message = buffer.toString();
    debugPrint(message);
    developer.log(message, name: 'HyperosHeader');
  }
}
