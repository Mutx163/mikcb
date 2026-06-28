import 'dart:async';

import 'app_log_service.dart';

void lanEditAuditInfo(
  String category,
  String message, {
  Map<String, Object?> extras = const {},
}) {
  unawaited(
    AppLogService.instance
        .info(category, message, extras: extras)
        .catchError((_) {}),
  );
}
