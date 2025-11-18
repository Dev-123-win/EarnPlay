import 'package:flutter/material.dart';

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
/// 3. Tab navigation: Handled internally by AppShell (NOT via AppRouter)
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

  // ============ POP NAVIGATION ============
  // Go back from current screen

  void goBack<T>([T? result]) {
    navigatorKey.currentState?.pop(result);
  }

  bool canGoBack() {
    return navigatorKey.currentState?.canPop() ?? false;
  }
}
