import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';

class AppAnalytics {
  AppAnalytics._();

  static final AppAnalytics instance = AppAnalytics._();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;
  bool _initialized = false;

  bool get _isSupportedPlatform =>
      kReleaseMode &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  List<NavigatorObserver> get navigatorObservers =>
      _observer == null ? const [] : [_observer!];

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _observer = FirebaseAnalyticsObserver(
        analytics: _analytics!,
        routeFilter: (route) => ((route?.settings.name) ?? '').isNotEmpty,
      );
      _initialized = true;
    } catch (error) {
      debugPrint('Failed to initialize Firebase Analytics: $error');
    }
  }

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (_analytics == null) {
      return;
    }

    try {
      await _analytics!.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (error) {
      debugPrint('Failed to log analytics event "$name": $error');
    }
  }

  void logEventLater({
    required String name,
    Map<String, Object>? parameters,
  }) {
    unawaited(logEvent(name: name, parameters: parameters));
  }
}
