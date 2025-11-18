import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to manage double-back-press to exit functionality
///
/// This service handles the timing and state of back button presses
/// to implement the double-tap-to-exit pattern commonly seen in mobile apps.
class DoubleBackPressService {
  static final DoubleBackPressService _instance =
      DoubleBackPressService._internal();

  factory DoubleBackPressService() {
    return _instance;
  }

  DoubleBackPressService._internal();

  DateTime? _lastBackPressTime;
  Timer? _backPressTimer;

  /// Duration window for second back press (default: 2 seconds)
  static const Duration backPressDuration = Duration(seconds: 2);

  /// Check if back press should trigger exit or show warning
  /// Returns true if exit should proceed, false if warning shown
  bool handleBackPress() {
    final now = DateTime.now();

    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > backPressDuration) {
      // First back press or timeout occurred
      _lastBackPressTime = now;
      _resetTimer();
      return false; // Show warning/confirmation
    } else {
      // Second back press within time window - allow exit
      _clearState();
      return true; // Proceed with exit
    }
  }

  /// Reset the timer for back press window
  void _resetTimer() {
    _backPressTimer?.cancel();
    _backPressTimer = Timer(backPressDuration, _clearState);
  }

  /// Clear the state (called after timeout or successful exit)
  void _clearState() {
    _backPressTimer?.cancel();
    _lastBackPressTime = null;
  }

  /// Dispose resources
  void dispose() {
    _backPressTimer?.cancel();
    _lastBackPressTime = null;
  }

  /// Exit the app
  static Future<void> exitApp() async {
    try {
      // Works on Android
      await SystemNavigator.pop();
    } catch (e) {
      debugPrint('Error exiting app: $e');
    }
  }
}
