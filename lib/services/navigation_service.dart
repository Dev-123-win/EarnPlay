import 'package:flutter/material.dart';

/// Tab index constants for AppShell navigation
class TabIndex {
  static const int home = 0;
  static const int dailyStreak = 1;
  static const int watchEarn = 2;
  static const int profile = 3;
}

/// Global callback for tab navigation (set by AppShell)
typedef TabNavigationCallback = void Function(int tabIndex);
TabNavigationCallback? _tabNavigationCallback;

/// Set the tab navigation callback (called by AppShell in initState)
void setTabNavigationCallback(TabNavigationCallback callback) {
  _tabNavigationCallback = callback;
}

/// Single source of truth for all app navigation
/// Eliminates the chaos of mixed navigation patterns:
/// - No more scattered Navigator.push() calls
/// - No more mixing named routes with direct pushes
/// - No more fighting between multiple navigation systems
///
/// Pattern: Always use AppRouter methods instead of Navigator directly
///
/// ARCHITECTURE:
/// 1. Top-level routes (auth, app shell): pushReplacementNamed (replace entire stack)
/// 2. Modal routes (games, modals): pushNamed (overlay on current stack)
/// 3. Tab navigation: Handled internally by AppShell via callbacks
class AppRouter {
  static final AppRouter _instance = AppRouter._internal();
  late final GlobalKey<NavigatorState> navigatorKey;

  AppRouter._internal() {
    navigatorKey = GlobalKey<NavigatorState>();
  }

  factory AppRouter() {
    return _instance;
  }

  // ============ TOP-LEVEL AUTH NAVIGATION ============
  // These REPLACE the current screen (used at app bootstrap, login/logout)

  Future<void> goToHome() async {
    navigatorKey.currentState?.pushReplacementNamed('/home');
  }

  Future<void> goToLogin() async {
    navigatorKey.currentState?.pushReplacementNamed('/login');
  }

  Future<void> goToRegister() async {
    navigatorKey.currentState?.pushNamed('/register');
  }

  Future<void> logout() async {
    navigatorKey.currentState?.pushReplacementNamed('/login');
  }

  // ============ MODAL/OVERLAY NAVIGATION ============
  // For screens that overlay the bottom nav (games, modals, etc.)
  // These use pushNamed so they appear on top of AppShell

  Future<void> goToTicTacToe() async {
    navigatorKey.currentState?.pushNamed('/tictactoe');
  }

  Future<void> goToWhackMole() async {
    navigatorKey.currentState?.pushNamed('/whackmole');
  }

  Future<void> goToWithdrawal() async {
    navigatorKey.currentState?.pushNamed('/withdrawal');
  }

  Future<void> goToGameHistory() async {
    navigatorKey.currentState?.pushNamed('/game-history');
  }

  Future<void> goToReferral() async {
    navigatorKey.currentState?.pushNamed('/referral');
  }

  Future<void> goToSpinWin() async {
    navigatorKey.currentState?.pushNamed('/spin-win');
  }

  Future<void> goToWallet() async {
    // Wallet maps to withdrawal screen in current routing
    navigatorKey.currentState?.pushNamed('/withdrawal');
  }

  // ============ TAB NAVIGATION (within AppShell) ============
  // For navigating to specific tabs in the bottom navigation
  // Uses callbacks registered by AppShell

  Future<void> goToDailyStreak() async {
    _tabNavigationCallback?.call(TabIndex.dailyStreak);
  }

  Future<void> goToWatchEarn() async {
    _tabNavigationCallback?.call(TabIndex.watchEarn);
  }

  Future<void> goToProfile() async {
    _tabNavigationCallback?.call(TabIndex.profile);
  }

  // ============ POP NAVIGATION ============
  // Go back from current screen

  void goBack<T>([T? result]) {
    navigatorKey.currentState?.pop(result);
  }

  bool canGoBack() {
    return navigatorKey.currentState?.canPop() ?? false;
  }
}
