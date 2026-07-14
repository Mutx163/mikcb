import 'app_localizations.dart';

/// Maps WebDAV / cloud sync error codes to localized user-facing text.
String localizeSyncError(AppLocalizations l10n, String? code) {
  return switch (code) {
    'auth_failed' => l10n.syncErrorAuthFailed,
    'access_denied' => l10n.syncErrorAccessDenied,
    'certificate_error' => l10n.syncErrorCertificateError,
    'connection_timeout' => l10n.syncErrorConnectionTimeout,
    'connection_failed' => l10n.syncErrorConnectionFailed,
    'network_error' => l10n.syncErrorNetworkError,
    'invalid_response' => l10n.syncErrorInvalidResponse,
    'local_changes_pending_sync' => l10n.syncErrorLocalChangesPendingSync,
    'missing_credentials' => l10n.syncErrorMissingCredentials,
    'backup_not_found' => l10n.syncErrorBackupNotFound,
    'missing_backup_snapshot' => l10n.syncErrorMissingBackupSnapshot,
    'cannot_delete_current_backup' => l10n.syncErrorCannotDeleteCurrentBackup,
    'provider_not_ready' => l10n.syncErrorProviderNotReady,
    'insecure_url_blocked' => l10n.syncErrorInsecureUrl,
    null || '' || 'sync_failed' => l10n.syncErrorSyncFailed,
    _ => l10n.syncErrorSyncFailed,
  };
}
