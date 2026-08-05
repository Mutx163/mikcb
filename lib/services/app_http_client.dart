import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Shared [http.Client] used by app services.
///
/// In debug/profile builds, [setupAppHttpClientForBlackBox] installs a
/// BlackBox-observing client so Network panel can see traffic. In release,
/// [createAppHttpClient] returns a plain [http.Client] owned by the caller.
http.Client? _sharedObservedHttpClient;

/// Installs the BlackBox observing client as the shared default for services.
///
/// Call once from [setupBlackBox] before any service creates its client.
/// No-op in release builds.
void setupAppHttpClientForBlackBox(http.Client observedClient) {
  if (kReleaseMode) {
    return;
  }
  _sharedObservedHttpClient = observedClient;
}

/// Whether [client] is the process-wide BlackBox-observed shared client.
///
/// Shared clients must not be [http.Client.close]d by individual services.
bool isSharedAppHttpClient(http.Client client) {
  final shared = _sharedObservedHttpClient;
  return shared != null && identical(client, shared);
}

/// Clears the shared client reference for test isolation.
@visibleForTesting
void resetAppHttpClientForTesting() {
  _sharedObservedHttpClient = null;
}

/// Default HTTP client for mikcb network services.
///
/// - Debug / profile (after BlackBox setup): shared observing client.
/// - Release, or before setup: a new plain [http.Client] (caller owns it).
http.Client createAppHttpClient() {
  final shared = _sharedObservedHttpClient;
  if (!kReleaseMode && shared != null) {
    return shared;
  }
  return http.Client();
}
