import 'package:flutter/foundation.dart';

import '../../logging/app_debug_log.dart';

/// Debug-only diagnostics for HyperOS blurred header layout decisions.
///
/// Per-build events (`page_build`, `shell_build`) are omitted — they fired on
/// every rebuild and drowned out transition/capture signals.
abstract final class HyperosHeaderDiag {
  static const _tag = 'HyperosHeader';

  static void log(String event, Map<String, Object?> fields) {
    if (!kDebugMode) {
      return;
    }
    appDebugLog(
      _tag,
      '$event ${fields.entries.map((e) => '${e.key}=${e.value}').join(' | ')}',
    );
  }
}
