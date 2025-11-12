import 'package:flutter/material.dart';

/// Advanced Error Handler with retry logic and user feedback
class ErrorHandler {
  static const maxRetries = 3;
  static const retryDelayMs = 1000;

  /// Error codes for better error handling
  static const errorCodes = {
    'NO_INTERNET': 'No internet connection. Please check your network.',
    'TIMEOUT': 'Request timed out. Please try again.',
    'AUTH_FAILED': 'Authentication failed. Please login again.',
    'INSUFFICIENT_BALANCE': 'Insufficient coin balance for this action.',
    'INVALID_INPUT': 'Invalid input provided. Please check and try again.',
    'SERVER_ERROR': 'Server error occurred. Please try again later.',
    'PERMISSION_DENIED': 'You don\'t have permission to perform this action.',
    'NOT_FOUND': 'Resource not found.',
    'UNKNOWN': 'An unexpected error occurred. Please try again.',
  };

  /// Parse Firebase error messages to user-friendly text
  static String getErrorMessage(dynamic error) {
    if (error == null) return errorCodes['UNKNOWN']!;

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network')) {
      return errorCodes['NO_INTERNET']!;
    } else if (errorStr.contains('timeout')) {
      return errorCodes['TIMEOUT']!;
    } else if (errorStr.contains('auth') || errorStr.contains('permission')) {
      return errorCodes['AUTH_FAILED']!;
    } else if (errorStr.contains('insufficient')) {
      return errorCodes['INSUFFICIENT_BALANCE']!;
    } else if (errorStr.contains('invalid')) {
      return errorCodes['INVALID_INPUT']!;
    } else if (errorStr.contains('5')) {
      return errorCodes['SERVER_ERROR']!;
    } else if (errorStr.contains('404')) {
      return errorCodes['NOT_FOUND']!;
    }

    return error.toString();
  }

  /// Show error snackbar with optional action
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        action: action,
        duration: duration,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade400,
        duration: duration,
      ),
    );
  }

  /// Show info snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade400,
        duration: duration,
      ),
    );
  }

  /// Show warning dialog
  static void showWarningDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm?.call();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Retry operation with exponential backoff
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    int initialDelayMs = 1000,
  }) async {
    int retryCount = 0;
    int delayMs = initialDelayMs;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;

        if (retryCount >= maxRetries) {
          rethrow;
        }

        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2; // Exponential backoff
      }
    }
  }

  /// Log error to console with context
  static void logError(
    String context,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    debugPrint('ERROR [$context]: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace, label: context);
    }
  }
}

/// Custom exception for app-specific errors
class AppException implements Exception {
  final String code;
  final String message;
  final dynamic originalError;

  AppException({
    required this.code,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'AppException($code): $message';
}
