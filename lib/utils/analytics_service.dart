import 'package:flutter/foundation.dart';

/// Analytics Service for tracking user events and performance
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal();

  // Event tracking storage (in production, use Firebase Analytics)
  final List<AnalyticsEvent> _eventLog = [];

  /// Track custom event
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    final event = AnalyticsEvent(
      name: eventName,
      timestamp: DateTime.now(),
      parameters: parameters ?? {},
    );

    _eventLog.add(event);

    if (kDebugMode) {
      debugPrint('EVENT: $eventName | ${event.timestamp}');
      if (parameters != null) {
        debugPrint('  Parameters: $parameters');
      }
    }

    // In production, send to Firebase Analytics
    // FirebaseAnalytics.instance.logEvent(name: eventName, parameters: parameters);
  }

  /// Track screen view
  void trackScreenView(String screenName) {
    trackEvent('screen_view', parameters: {'screen_name': screenName});
  }

  /// Track game played
  void trackGamePlayed(String gameName, {int? score}) {
    trackEvent(
      'game_played',
      parameters: {'game_name': gameName, if (score != null) 'score': score},
    );
  }

  /// Track ad watched
  void trackAdWatched() {
    trackEvent('ad_watched');
  }

  /// Track daily streak claimed
  void trackStreakClaimed(int streamLength) {
    trackEvent('streak_claimed', parameters: {'streak_length': streamLength});
  }

  /// Track spin performed
  void trackSpinPerformed(int reward) {
    trackEvent('spin_performed', parameters: {'reward': reward});
  }

  /// Track coins earned
  void trackCoinsEarned(int amount, String source) {
    trackEvent(
      'coins_earned',
      parameters: {'amount': amount, 'source': source},
    );
  }

  /// Track withdrawal request
  void trackWithdrawalRequest(int amount, String method) {
    trackEvent(
      'withdrawal_requested',
      parameters: {'amount': amount, 'method': method},
    );
  }

  /// Track referral
  void trackReferralShared(String? referralCode) {
    trackEvent(
      'referral_shared',
      parameters: referralCode != null ? {'referral_code': referralCode} : {},
    );
  }

  /// Track user signup
  void trackSignup(String method) {
    trackEvent('user_signup', parameters: {'method': method});
  }

  /// Track user login
  void trackLogin(String method) {
    trackEvent('user_login', parameters: {'method': method});
  }

  /// Track error
  void trackError(String errorCode, String errorMessage) {
    trackEvent(
      'error_occurred',
      parameters: {'error_code': errorCode, 'error_message': errorMessage},
    );
  }

  /// Track feature usage
  void trackFeatureUsage(String featureName) {
    trackEvent('feature_used', parameters: {'feature_name': featureName});
  }

  /// Get all events (for debugging)
  List<AnalyticsEvent> getEventLog() => List.unmodifiable(_eventLog);

  /// Clear event log
  void clearEventLog() {
    _eventLog.clear();
  }

  /// Get event count
  int getEventCount() => _eventLog.length;

  /// Get events by name
  List<AnalyticsEvent> getEventsByName(String eventName) {
    return _eventLog.where((e) => e.name == eventName).toList();
  }

  /// Get summary statistics
  AnalyticsSummary getSummary() {
    return AnalyticsSummary(
      totalEvents: _eventLog.length,
      uniqueEventTypes: _eventLog.map((e) => e.name).toSet().length,
      firstEventTime: _eventLog.isNotEmpty ? _eventLog.first.timestamp : null,
      lastEventTime: _eventLog.isNotEmpty ? _eventLog.last.timestamp : null,
    );
  }
}

/// Model for analytics event
class AnalyticsEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> parameters;

  AnalyticsEvent({
    required this.name,
    required this.timestamp,
    required this.parameters,
  });

  @override
  String toString() => 'AnalyticsEvent($name, $timestamp)';
}

/// Summary of analytics data
class AnalyticsSummary {
  final int totalEvents;
  final int uniqueEventTypes;
  final DateTime? firstEventTime;
  final DateTime? lastEventTime;

  AnalyticsSummary({
    required this.totalEvents,
    required this.uniqueEventTypes,
    required this.firstEventTime,
    required this.lastEventTime,
  });

  @override
  String toString() =>
      '''
AnalyticsSummary(
  totalEvents: $totalEvents,
  uniqueEventTypes: $uniqueEventTypes,
  firstEventTime: $firstEventTime,
  lastEventTime: $lastEventTime
)''';
}

/// Performance tracking
class PerformanceTracker {
  static final Map<String, _PerformanceData> _data = {};

  /// Start measuring performance
  static void startMeasure(String label) {
    _data[label] = _PerformanceData(label: label, startTime: DateTime.now());
  }

  /// End measuring and get duration
  static Duration? endMeasure(String label) {
    final data = _data[label];
    if (data == null) return null;

    final duration = DateTime.now().difference(data.startTime);
    data.duration = duration;

    if (kDebugMode) {
      debugPrint('PERFORMANCE: $label took ${duration.inMilliseconds}ms');
    }

    return duration;
  }

  /// Get all measurements
  static Map<String, Duration?> getAllMeasurements() {
    return {for (var entry in _data.entries) entry.key: entry.value.duration};
  }

  /// Clear measurements
  static void clear() {
    _data.clear();
  }
}

class _PerformanceData {
  final String label;
  final DateTime startTime;
  Duration? duration;

  _PerformanceData({required this.label, required this.startTime});
}
