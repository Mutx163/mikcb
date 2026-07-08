import 'app_localizations.dart';

/// Localizes persisted holiday service log message keys for UI display.
abstract final class HolidayLogLocalizer {
  static String localize(AppLocalizations l10n, String message) {
    final parts = message.split('|');
    final key = parts.first;
    final params = <String, String>{};
    for (final part in parts.skip(1)) {
      final idx = part.indexOf('=');
      if (idx > 0) {
        params[part.substring(0, idx)] = part.substring(idx + 1);
      }
    }

    int intParam(String name, {int fallback = 0}) =>
        int.tryParse(params[name] ?? '') ?? fallback;

    return switch (key) {
      'holiday_log_memory_cache_hit' => l10n.holidayLogMemoryCacheHit(
        intParam('year'),
        intParam('count'),
      ),
      'holiday_log_local_cache_hit' => l10n.holidayLogLocalCacheHit(
        intParam('year'),
        intParam('count'),
      ),
      'holiday_log_no_cache_fetching' => l10n.holidayLogNoCacheFetching(
        intParam('year'),
      ),
      'holiday_log_remote_success' => l10n.holidayLogRemoteSuccess(
        intParam('year'),
        intParam('count'),
      ),
      'holiday_log_remote_failed_builtin' =>
        l10n.holidayLogRemoteFailedBuiltin(intParam('year')),
      'holiday_log_builtin_loaded' => l10n.holidayLogBuiltinLoaded(
        intParam('year'),
        intParam('count'),
      ),
      'holiday_log_background_success' => l10n.holidayLogBackgroundSuccess(
        intParam('year'),
        intParam('count'),
      ),
      'holiday_log_background_no_data' =>
        l10n.holidayLogBackgroundNoData(intParam('year')),
      'holiday_log_primary_api_failed' => l10n.holidayLogPrimaryApiFailed,
      'holiday_log_requesting' => l10n.holidayLogRequesting(
        params['uri'] ?? '',
      ),
      'holiday_log_primary_api_status' => l10n.holidayLogPrimaryApiStatus(
        intParam('statusCode'),
      ),
      'holiday_log_primary_api_error' => l10n.holidayLogPrimaryApiError(
        params['message'] ?? '',
      ),
      'holiday_log_primary_api_exception' => l10n.holidayLogPrimaryApiException(
        params['error'] ?? '',
      ),
      'holiday_log_primary_api_parsing' => l10n.holidayLogPrimaryApiParsing(
        intParam('count'),
      ),
      'holiday_log_no_valid_entries' => l10n.holidayLogNoValidEntries,
      'holiday_log_fallback_api_status' => l10n.holidayLogFallbackApiStatus(
        intParam('statusCode'),
      ),
      'holiday_log_fallback_api_error' => l10n.holidayLogFallbackApiError,
      'holiday_log_fallback_api_parsing' => l10n.holidayLogFallbackApiParsing(
        intParam('count'),
      ),
      'holiday_log_fallback_api_exception' =>
        l10n.holidayLogFallbackApiException(params['error'] ?? ''),
      _ => message,
    };
  }
}
