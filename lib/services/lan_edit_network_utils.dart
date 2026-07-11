import 'dart:io';

/// Picks the most likely LAN IPv4 address for showing to the user.
Future<String?> findPreferredLanIPv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    final candidates = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final host = address.address;
        if (host == '127.0.0.1' || host.startsWith('169.254.')) {
          continue;
        }
        candidates.add(host);
      }
    }
    if (candidates.isEmpty) {
      return null;
    }

    int score(String host) {
      if (host.startsWith('192.168.')) return 3;
      if (host.startsWith('10.')) return 2;
      final parts = host.split('.');
      if (parts.length == 4) {
        final second = int.tryParse(parts[1]) ?? -1;
        if (parts[0] == '172' && second >= 16 && second <= 31) {
          return 2;
        }
      }
      return 1;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    return candidates.first;
  } catch (_) {
    return null;
  }
}

/// Client IP for rate limiting. Uses the TCP peer only.
///
/// Do not trust `X-Forwarded-For`: LAN Edit binds a direct [HttpServer]
/// with no reverse-proxy allowlist, so clients can forge XFF and bypass
/// per-IP PIN attempt limits.
String clientIpFromRequest(HttpRequest request) {
  return request.connectionInfo?.remoteAddress.address ?? 'unknown';
}
