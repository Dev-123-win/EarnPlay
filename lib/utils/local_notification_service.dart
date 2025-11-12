import 'dart:async';
import 'package:flutter/material.dart';

/// Local Notification Service for app reminders
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  factory LocalNotificationService() {
    return _instance;
  }

  LocalNotificationService._internal();

  final List<Notification> _notifications = [];
  Timer? _dailyCheckTimer;

  /// Initialize notification service
  Future<void> initialize() async {
    _setupDailyReminder();
  }

  /// Schedule daily streak reminder
  void scheduleDailyStreakReminder({
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0),
  }) {
    _setupDailyReminder(reminderTime);
  }

  /// Show local notification
  void showNotification({
    required String title,
    required String body,
    String? payload,
  }) {
    final notification = Notification(
      id: _notifications.length + 1,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      payload: payload,
    );

    _notifications.add(notification);
    debugPrint('NOTIFICATION: $title - $body');

    // In production, use flutter_local_notifications plugin
    // _flutterLocalNotificationsPlugin.show(...)
  }

  /// Show streak reminder notification
  void showStreakReminder() {
    showNotification(
      title: 'Daily Streak Available! 🔥',
      body: 'Claim your daily coins before midnight.',
      payload: 'streak_reminder',
    );
  }

  /// Show coin milestone notification
  void showCoinMilestone(int coinAmount) {
    showNotification(
      title: 'Milestone Reached! 🎉',
      body: 'You have earned $coinAmount coins!',
      payload: 'coin_milestone',
    );
  }

  /// Show withdrawal approval notification
  void showWithdrawalApproved(int amount, String method) {
    showNotification(
      title: 'Withdrawal Approved! 💰',
      body:
          '₹${(amount * 0.5).toStringAsFixed(0)} will be credited via $method',
      payload: 'withdrawal_approved',
    );
  }

  /// Show referral bonus notification
  void showReferralBonus(int amount) {
    showNotification(
      title: 'Referral Bonus! 👥',
      body: 'You earned $amount coins from a referral!',
      payload: 'referral_bonus',
    );
  }

  /// Show game win notification
  void showGameWin(String gameName, int coinsEarned) {
    showNotification(
      title: '$gameName - Victory! 🎮',
      body: 'You earned $coinsEarned coins!',
      payload: 'game_win',
    );
  }

  /// Show maintenance notification
  void showMaintenance({required String title, required String body}) {
    showNotification(title: title, body: body, payload: 'maintenance');
  }

  /// Cancel daily reminder
  void cancelDailyReminder() {
    _dailyCheckTimer?.cancel();
  }

  /// Get all notifications
  List<Notification> getNotifications() => List.unmodifiable(_notifications);

  /// Clear notifications
  void clearNotifications() {
    _notifications.clear();
  }

  /// Dispose resources
  void dispose() {
    _dailyCheckTimer?.cancel();
  }

  // Private helper methods

  void _setupDailyReminder([TimeOfDay? specificTime]) {
    final now = DateTime.now();
    final reminderTime = specificTime ?? const TimeOfDay(hour: 8, minute: 0);

    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final duration = scheduledTime.difference(now);

    _dailyCheckTimer?.cancel();
    _dailyCheckTimer = Timer.periodic(const Duration(days: 1), (_) {
      showStreakReminder();
    });

    // First reminder after calculated duration
    Timer(duration, () {
      showStreakReminder();
    });
  }
}

/// Model for local notification
class Notification {
  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? payload;
  bool isRead = false;

  Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.payload,
  });

  @override
  String toString() => '$title: $body';
}

/// Notification extensions for convenient access
extension NotificationContext on BuildContext {
  void showNotification({required String title, required String body}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void showSuccessNotification(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade400,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showErrorNotification(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void showWarningNotification(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade400,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
