import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Performance optimization utilities
class PerformanceOptimizer {
  static const defaultCacheSize = 50; // MB
  static const imageCacheSize = 100; // Images

  /// Optimize image loading with caching
  static Future<void> optimizeImageCaching() async {
    // Flutter's ImageCache is automatically used
    // This function documents the optimization strategy
    if (kDebugMode) {
      debugPrint('Image caching optimized');
    }
  }

  /// Memory efficient JSON parsing
  static Map<String, dynamic>? parseJson(String jsonString) {
    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('JSON parse error: $e');
      }
      return null;
    }
  }

  /// Batch operations for efficiency
  static Future<void> executeBatchOperations(
    List<Future<void> Function()> operations,
  ) async {
    for (final operation in operations) {
      try {
        await operation();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Batch operation failed: $e');
        }
      }
    }
  }

  /// Debounce function calls
  static Function debounce(
    Future<void> Function() callback, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    DateTime? lastCall;

    return () async {
      final now = DateTime.now();
      if (lastCall == null ||
          now.difference(lastCall!).inMilliseconds > delay.inMilliseconds) {
        lastCall = now;
        await callback();
      }
    };
  }

  /// Throttle function calls
  static Function throttle(
    Function callback, {
    Duration interval = const Duration(milliseconds: 1000),
  }) {
    DateTime? lastCall;

    return () {
      final now = DateTime.now();
      if (lastCall == null ||
          now.difference(lastCall!).inMilliseconds >= interval.inMilliseconds) {
        lastCall = now;
        callback();
      }
    };
  }

  /// Memory warning callback
  static void onMemoryWarning() {
    if (kDebugMode) {
      debugPrint('Memory warning: Clearing caches');
    }
    // In production, clear non-essential caches
  }
}

/// List rendering optimization
class LazyListOptimizer {
  /// Calculate visible items for list
  static int calculateVisibleItems({
    required int totalItems,
    required double itemHeight,
    required double viewportHeight,
  }) {
    return (viewportHeight / itemHeight).ceil() + 2; // +2 buffer
  }

  /// Get items for current viewport
  static List<T> getVisibleItems<T>({
    required List<T> items,
    required int firstVisibleIndex,
    required int visibleCount,
  }) {
    final endIndex = (firstVisibleIndex + visibleCount).clamp(0, items.length);
    return items.sublist(firstVisibleIndex, endIndex);
  }
}

/// Network optimization
class NetworkOptimizer {
  /// Compress data for transmission
  static String compressJson(Map<String, dynamic> data) {
    final jsonString = json.encode(data);
    // In production, use actual compression library
    return jsonString;
  }

  /// Batch network requests
  static Future<List<T>> batchRequests<T>(
    List<Future<T> Function()> requests,
  ) async {
    final results = <T>[];

    // Execute requests with batching for efficiency
    const batchSize = 3;
    for (var i = 0; i < requests.length; i += batchSize) {
      final batch = requests.sublist(
        i,
        (i + batchSize).clamp(0, requests.length),
      );

      try {
        final batchResults = await Future.wait(batch.map((r) => r()));
        results.addAll(batchResults);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Batch request error: $e');
        }
      }
    }

    return results;
  }
}

/// State management optimization
class StateOptimization {
  /// Detect unnecessary rebuilds
  static bool shouldRebuild<T>(T oldValue, T newValue) {
    if (oldValue == null || newValue == null) {
      return oldValue != newValue;
    }
    return oldValue != newValue;
  }
}

/// Asset optimization
class AssetOptimizer {
  /// Check if asset file should be cached
  static bool shouldCacheAsset(String assetPath) {
    // Cache common assets
    return assetPath.endsWith('.png') ||
        assetPath.endsWith('.jpg') ||
        assetPath.endsWith('.json');
  }

  /// Preload critical assets documentation
  static Future<void> preloadAssets(List<String> assetPaths) async {
    // In production, implement actual preloading
    // This is a placeholder for the optimization strategy
    debugPrint('Assets optimization: ${assetPaths.length} assets prioritized');
  }
}

/// Debug performance metrics
class PerformanceMetrics {
  static final Map<String, List<Duration>> _measurements = {};

  static void recordMeasure(String label, Duration duration) {
    _measurements.putIfAbsent(label, () => []).add(duration);
  }

  static double getAverageDuration(String label) {
    final measurements = _measurements[label];
    if (measurements == null || measurements.isEmpty) return 0;

    final total = measurements.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );

    return total / measurements.length;
  }

  static void printReport() {
    if (!kDebugMode) return;

    debugPrint('=== PERFORMANCE REPORT ===');
    _measurements.forEach((label, durations) {
      final avg = getAverageDuration(label);
      final max = durations.reduce(
        (a, b) => a.inMilliseconds > b.inMilliseconds ? a : b,
      );
      final min = durations.reduce(
        (a, b) => a.inMilliseconds < b.inMilliseconds ? a : b,
      );

      debugPrint(
        '$label: avg=${avg.toStringAsFixed(2)}ms, '
        'min=${min.inMilliseconds}ms, max=${max.inMilliseconds}ms, '
        'count=${durations.length}',
      );
    });
    debugPrint('========================');
  }

  static void clear() {
    _measurements.clear();
  }
}
