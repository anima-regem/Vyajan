import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  const AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> logEssentialEvent(
    String name, {
    Map<String, Object>? parameters,
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> logProductivityEvent(
    String name, {
    required bool insightsOptIn,
    Map<String, Object>? parameters,
  }) {
    if (!insightsOptIn) {
      return Future<void>.value();
    }

    return _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUserId(String? userId) => _analytics.setUserId(id: userId);

  Future<void> setInsightsConsent(bool optedIn) {
    return _analytics.setUserProperty(
      name: 'insights_opt_in',
      value: optedIn ? 'true' : 'false',
    );
  }
}
