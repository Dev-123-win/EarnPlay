import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'animation_helper.dart';

/// Dialog system for consistent Material 3 dialogs across the app
class DialogSystem {
  /// Success dialog with icon, title, and action
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    String subtitle = '',
    String actionButtonText = 'OK',
    VoidCallback? onAction,
    Widget? icon,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ScaleFadeAnimation(
        child: AlertDialog(
          icon:
              icon ??
              const Icon(
                Icons.check_circle,
                size: 64,
                color: AppTheme.tertiaryColor,
              ),
          title: Text(title),
          content: subtitle.isNotEmpty ? Text(subtitle) : null,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onAction?.call();
              },
              child: Text(actionButtonText),
            ),
          ],
        ),
      ),
    );
  }

  /// Error dialog with icon, title, and action
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    String subtitle = '',
    String actionButtonText = 'OK',
    VoidCallback? onAction,
    Widget? icon,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ScaleFadeAnimation(
        child: AlertDialog(
          icon:
              icon ??
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
          title: Text(title),
          content: subtitle.isNotEmpty ? Text(subtitle) : null,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onAction?.call();
              },
              child: Text(actionButtonText),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirmation dialog with two actions
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    String subtitle = '',
    required String confirmText,
    required String cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ScaleFadeAnimation(
        child: AlertDialog(
          title: Text(title),
          content: subtitle.isNotEmpty ? Text(subtitle) : null,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context, false);
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
            FilledButton(
              style: isDangerous
                  ? FilledButton.styleFrom(backgroundColor: AppTheme.errorColor)
                  : null,
              onPressed: () {
                Navigator.pop(context, true);
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }

  /// Info dialog
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
    String actionButtonText = 'OK',
    VoidCallback? onAction,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ScaleFadeAnimation(
        child: AlertDialog(
          icon: const Icon(
            Icons.info_outline,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          title: Text(title),
          content: Text(content),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onAction?.call();
              },
              child: Text(actionButtonText),
            ),
          ],
        ),
      ),
    );
  }

  /// Game result dialog (for Tic Tac Toe, Whack-A-Mole, etc.)
  static Future<void> showGameResultDialog(
    BuildContext context, {
    required String title,
    required String emoji,
    String reward = '',
    required VoidCallback onPlayAgain,
    required VoidCallback onMainMenu,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScaleFadeAnimation(
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (reward.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiaryColor.withValues(alpha: 25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reward,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.tertiaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onPlayAgain();
                    },
                    child: const Text('PLAY AGAIN'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onMainMenu();
                    },
                    child: const Text('MAIN MENU'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Withdrawal status dialog
  static Future<void> showWithdrawalDialog(
    BuildContext context, {
    required String status,
    required String amount,
    String? message,
    VoidCallback? onClose,
  }) {
    final isApproved = status.toLowerCase() == 'approved';
    final isPending = status.toLowerCase() == 'pending';

    IconData icon;
    Color iconColor;

    if (isApproved) {
      icon = Icons.check_circle;
      iconColor = AppTheme.tertiaryColor;
    } else if (isPending) {
      icon = Icons.schedule;
      iconColor = AppTheme.secondaryColor;
    } else {
      icon = Icons.cancel;
      iconColor = AppTheme.errorColor;
    }

    return showDialog(
      context: context,
      builder: (context) => ScaleFadeAnimation(
        child: AlertDialog(
          icon: Icon(icon, size: 64, color: iconColor),
          title: Text('Withdrawal $status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Amount: $amount'),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onClose?.call();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  /// Loading dialog
  static Future<void> showLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Input dialog for referral code
  static Future<String?> showReferralCodeDialog(
    BuildContext context, {
    required String title,
    required String hint,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (context) => ScaleFadeAnimation(
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Snackbar helper for quick notifications
class SnackbarHelper {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message,
      icon: Icons.check_circle,
      backgroundColor: AppTheme.tertiaryColor,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message,
      icon: Icons.error_outline,
      backgroundColor: AppTheme.errorColor,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message,
      icon: Icons.info_outline,
      backgroundColor: AppTheme.primaryColor,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
