import 'package:flutter/material.dart';

class ErrorStateScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateScreen({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: colorScheme.error),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Network Error
class NetworkErrorScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorStateScreen(
      title: 'Network Error',
      message: 'Unable to connect. Please check your internet connection.',
      icon: Icons.wifi_off,
      onRetry: onRetry,
    );
  }
}

// Timeout Error
class TimeoutErrorScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const TimeoutErrorScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorStateScreen(
      title: 'Request Timeout',
      message: 'The request took too long. Please try again.',
      icon: Icons.schedule,
      onRetry: onRetry,
    );
  }
}

// Server Error
class ServerErrorScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const ServerErrorScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorStateScreen(
      title: 'Server Error',
      message: 'Something went wrong on our end. Please try again later.',
      icon: Icons.cloud_off,
      onRetry: onRetry,
    );
  }
}

// Not Found Error
class NotFoundErrorScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NotFoundErrorScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorStateScreen(
      title: 'Not Found',
      message: 'The resource you are looking for does not exist.',
      icon: Icons.search_off,
      onRetry: onRetry,
    );
  }
}

// Access Denied Error
class AccessDeniedErrorScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const AccessDeniedErrorScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorStateScreen(
      title: 'Access Denied',
      message: 'You do not have permission to access this resource.',
      icon: Icons.lock_outline,
      onRetry: onRetry,
    );
  }
}
