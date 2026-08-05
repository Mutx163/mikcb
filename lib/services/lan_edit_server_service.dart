import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../logging/app_log_messages.dart';
import 'lan_edit_audit_log.dart';
import 'lan_edit_api_handlers.dart';
import 'lan_edit_foreground_service.dart';
import 'lan_edit_host.dart';
import 'lan_edit_session.dart';

typedef LanEditServerStoppedCallback = void Function();

/// Embedded HTTP server for LAN timetable editing.
class LanEditServerService {
  static const String _lanEditContentSecurityPolicy =
      "default-src 'self'; "
      "script-src 'self'; "
      "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
      "font-src 'self' https://cdn.jsdelivr.net; "
      "img-src 'self' data:; "
      "connect-src 'self'; "
      "object-src 'none'; "
      "base-uri 'none'; "
      "frame-ancestors 'none'; "
      "form-action 'self'";

  /// Process-wide instance used by the LAN edit UI so a session can outlive
  /// the settings sub-page when the user enables “keep open after leaving”.
  ///
  /// Tests should construct a fresh [LanEditServerService] instead of this.
  static final LanEditServerService shared = LanEditServerService();

  HttpServer? _server;
  LanEditSession? _session;
  LanEditHost? _host;
  Timer? _idleTimer;
  final List<LanEditServerStoppedCallback> _stoppedListeners =
      <LanEditServerStoppedCallback>[];

  /// When true, [LanEditScreen] dispose must not stop this server.
  ///
  /// Updated from the keep-alive switch / prefs so leave-page decisions do not
  /// race against an unfinished SharedPreferences load.
  bool retainAfterLeave = false;

  bool get isRunning => _server != null;

  int? get port => _server?.port;

  LanEditSession? get session => _session;

  /// Registers a listener for [stop]. Safe to call repeatedly; duplicates ignored.
  void addStoppedListener(LanEditServerStoppedCallback listener) {
    if (!_stoppedListeners.contains(listener)) {
      _stoppedListeners.add(listener);
    }
  }

  void removeStoppedListener(LanEditServerStoppedCallback listener) {
    _stoppedListeners.remove(listener);
  }

  Future<void> start({
    required LanEditHost host,
    required LanEditSession session,
  }) async {
    if (_server != null) {
      throw StateError('LAN edit server is already running');
    }
    _host = host;
    _session = session;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(
      _onRequest,
      onError: (_) {
        unawaited(stop(reason: 'server_error'));
      },
      onDone: () {
        // [stop] already nulls [_server] before close; ignore the close echo.
        if (_server != null) {
          unawaited(stop(reason: 'server_done'));
        }
      },
    );
    _idleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_session?.isExpired ?? true) {
        unawaited(stop(reason: 'idle_timeout'));
      }
    });
    final foregroundStarted = await LanEditForegroundBridge.start();
    if (!foregroundStarted) {
      await stop(reason: 'foreground_start_failed');
      throw StateError(
        'Failed to start foreground service (missing notification or foreground service permission), LAN edit stopped',
      );
    }
    lanEditAuditInfo(
      'lan_edit_session_started',
      AppLogMessages.lanEditSessionStarted,
      extras: {'port': _server!.port},
    );
  }

  Future<void> stop({String reason = 'manual'}) async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final wasRunning = _server != null;
    final port = _server?.port;
    final server = _server;
    _server = null;
    _session = null;
    _host = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {
        // Server may already be closed.
      }
    }
    // Always dismiss the Android notification so UI / status bar stay in sync.
    await LanEditForegroundBridge.stop();
    if (wasRunning) {
      lanEditAuditInfo(
        'lan_edit_session_stopped',
        AppLogMessages.lanEditSessionStopped,
        extras: {'reason': reason, 'port': ?port},
      );
      final listeners = List<LanEditServerStoppedCallback>.from(
        _stoppedListeners,
      );
      for (final listener in listeners) {
        try {
          listener();
        } catch (_) {
          // UI listeners must not break teardown.
        }
      }
    }
  }

  Future<void> _onRequest(HttpRequest request) async {
    try {
      final host = _host;
      final session = _session;
      if (host == null || session == null) {
        request.response.statusCode = 503;
        await request.response.close();
        return;
      }

      final path = request.uri.path;
      if (path.startsWith('/api/')) {
        final handlers = LanEditApiHandlers(host: host, session: session);
        await handlers.handle(request);
        return;
      }

      await _serveStatic(request, path);
    } catch (_) {
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {
        // Client disconnected.
      }
    }
  }

  Future<void> _serveStatic(HttpRequest request, String path) async {
    final assetPath = _mapAssetPath(path);
    if (assetPath == null) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }

    try {
      final data = await rootBundle.load(assetPath);
      request.response.statusCode = 200;
      request.response.headers.contentType = _contentTypeFor(assetPath);
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.set(
        'Content-Security-Policy',
        _lanEditContentSecurityPolicy,
      );
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      request.response.add(data.buffer.asUint8List());
      await request.response.close();
    } catch (_) {
      request.response.statusCode = 404;
      await request.response.close();
    }
  }

  String? _mapAssetPath(String path) {
    if (path == '/' || path == '/index.html') {
      return 'assets/lan_edit/index.html';
    }
    if (path == '/assets/app.js') {
      return 'assets/lan_edit/app.js';
    }
    if (path == '/assets/i18n.js') {
      return 'assets/lan_edit/i18n.js';
    }
    if (path == '/assets/style.css') {
      return 'assets/lan_edit/lan-timetable.css';
    }
    if (path == '/assets/lan-timetable.css') {
      return 'assets/lan_edit/lan-timetable.css';
    }
    // App brand mark for login page + browser tab icon.
    if (path == '/assets/logo.png' || path == '/favicon.ico') {
      return 'assets/branding/launcher_icon.png';
    }
    return null;
  }

  ContentType _contentTypeFor(String assetPath) {
    if (assetPath.endsWith('.html')) {
      return ContentType('text', 'html', charset: 'utf-8');
    }
    if (assetPath.endsWith('.js')) {
      return ContentType('application', 'javascript', charset: 'utf-8');
    }
    if (assetPath.endsWith('.css')) {
      return ContentType('text', 'css', charset: 'utf-8');
    }
    if (assetPath.endsWith('.png')) {
      return ContentType('image', 'png');
    }
    return ContentType.json;
  }
}

String encodeLanEditUrl({
  required String host,
  required int port,
  String? token,
  String? pin,
}) {
  final base = 'http://$host:$port/';
  final params = <String, String>{};
  if (token != null && token.isNotEmpty) {
    params['token'] = token;
  }
  if (pin != null && pin.isNotEmpty) {
    params['pin'] = pin;
  }
  if (params.isEmpty) {
    return base;
  }
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '$base?$query';
}

Map<String, dynamic> decodeRequestJson(String raw) {
  if (raw.trim().isEmpty) {
    return {};
  }
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected JSON object');
  }
  return decoded;
}
