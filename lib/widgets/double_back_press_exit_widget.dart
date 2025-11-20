import 'package:flutter/material.dart';
import '../services/double_back_service.dart';

/// Enum for exit confirmation UI styles
enum ExitConfirmationStyle {
  snackbar, // Show a SnackBar message
  dialog, // Show an AlertDialog
  bottomSheet, // Show a BottomSheet
  toast, // Show a toast message (requires third-party package)
}

/// Widget to handle double-back-press to exit functionality
///
/// Wraps the main content and intercepts back button presses.
/// On first back press, shows confirmation message/UI.
/// On second back press within 2 seconds, exits the app.
class DoubleBackPressExitWidget extends StatefulWidget {
  /// The child widget to display
  final Widget child;

  /// Style of confirmation UI to show (default: snackbar)
  final ExitConfirmationStyle confirmationStyle;

  /// Custom message shown on first back press
  final String? customMessage;

  /// Callback when first back press occurs
  final VoidCallback? onFirstBackPress;

  /// Callback when exit is confirmed (second back press)
  final VoidCallback? onExitConfirmed;

  const DoubleBackPressExitWidget({
    super.key,
    required this.child,
    this.confirmationStyle = ExitConfirmationStyle.snackbar,
    this.customMessage,
    this.onFirstBackPress,
    this.onExitConfirmed,
  });

  @override
  State<DoubleBackPressExitWidget> createState() =>
      _DoubleBackPressExitWidgetState();
}

class _DoubleBackPressExitWidgetState extends State<DoubleBackPressExitWidget> {
  final DoubleBackPressService _backPressService = DoubleBackPressService();

  String get _exitMessage => widget.customMessage ?? 'Press back again to exit';

  Future<bool> _handleWillPop() async {
    if (_backPressService.handleBackPress()) {
      // Second back press - exit confirmed
      widget.onExitConfirmed?.call();

      // Small delay to ensure UI closes properly before exit
      await Future.delayed(const Duration(milliseconds: 300));
      await DoubleBackPressService.exitApp();
      return false;
    }

    // First back press - show confirmation UI
    widget.onFirstBackPress?.call();
    _showConfirmation();
    return false; // Prevent navigation
  }

  /// Show confirmation UI based on selected style
  void _showConfirmation() {
    switch (widget.confirmationStyle) {
      case ExitConfirmationStyle.snackbar:
        _showSnackBar();
        break;
      case ExitConfirmationStyle.dialog:
        _showDialog();
        break;
      case ExitConfirmationStyle.bottomSheet:
        _showBottomSheet();
        break;
      case ExitConfirmationStyle.toast:
        _showToast();
        break;
    }
  }

  /// Show SnackBar confirmation
  void _showSnackBar() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_exitMessage),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 6,
        action: SnackBarAction(
          label: 'OK',
          textColor: Theme.of(context).colorScheme.onPrimary,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show Dialog confirmation
  void _showDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: Text(_exitMessage),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              DoubleBackPressService.exitApp();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  /// Show BottomSheet confirmation
  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(bottom: 16),
            ),
            Icon(
              Icons.exit_to_app,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Exit App',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _exitMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      DoubleBackPressService.exitApp();
                    },
                    child: const Text('Exit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show Toast confirmation (basic implementation)
  void _showToast() {
    // Toast implementation - shows a temporary message
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_exitMessage),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(200),
        elevation: 6,
        dismissDirection: DismissDirection.down,
      ),
    );
  }

  @override
  void dispose() {
    _backPressService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleWillPop();
      },
      child: widget.child,
    );
  }
}
