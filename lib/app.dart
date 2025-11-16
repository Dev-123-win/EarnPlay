import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/app_shell.dart';
import 'screens/daily_streak_screen.dart';
import 'screens/watch_earn_screen.dart';
import 'screens/spin_win_screen.dart';
import 'screens/games/tictactoe_screen.dart';
import 'screens/games/whack_mole_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/withdrawal_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EarnPlay',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const AppShell(),
        '/daily_streak': (context) => const DailyStreakScreen(),
        '/watch_earn': (context) => const WatchEarnScreen(),
        '/spin_win': (context) => const SpinWinScreen(),
        '/tictactoe': (context) => const TicTacToeScreen(),
        '/whack_mole': (context) => const WhackMoleScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/referral': (context) => const ReferralScreen(),
        '/withdrawal': (context) => const WithdrawalScreen(),
      },
    );
  }
}
