import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/app_shell.dart';
import 'screens/games/tictactoe_screen.dart';
import 'screens/games/whack_mole_screen.dart';
import 'screens/withdrawal_screen.dart';
import 'screens/withdrawal_history_screen.dart';
import 'screens/game_history_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/spin_win_screen.dart';
import 'services/navigation_service.dart';
import 'widgets/double_back_press_exit_widget.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DoubleBackPressExitWidget(
      confirmationStyle: ExitConfirmationStyle.snackbar,
      customMessage: 'Press back again to exit EarnPlay',
      onFirstBackPress: () {
        debugPrint('First back press detected');
      },
      onExitConfirmed: () {
        debugPrint('User confirmed app exit');
      },
      child: MaterialApp(
        title: 'EarnPlay',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
        navigatorKey: AppRouter().navigatorKey,
        routes: {
          // ========== AUTH FLOWS ==========
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const AppShell(),

          // ========== GAME SCREENS ==========
          '/tictactoe': (context) => const TicTacToeScreen(),
          '/whackmole': (context) => const WhackMoleScreen(),

          // ========== MODAL SCREENS ==========
          '/withdrawal': (context) => const WithdrawalScreen(),
          '/withdrawal-history': (context) => const WithdrawalHistoryScreen(),
          '/game-history': (context) => const GameHistoryScreen(),
          '/referral': (context) => const ReferralScreen(),
          '/spin-win': (context) => const SpinWinScreen(),
        },
      ),
    );
  }
}
