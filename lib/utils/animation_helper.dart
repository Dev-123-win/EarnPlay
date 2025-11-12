import 'package:flutter/material.dart';

/// Animation Helper - Reusable animation builders for all screens
class AnimationHelper {
  /// Fade animation
  static AnimatedBuilder fadeAnimation({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) =>
          Opacity(opacity: animation.value, child: child),
      child: child,
    );
  }

  /// Slide animation from left
  static AnimatedBuilder slideFromLeftAnimation({
    required Animation<double> animation,
    required Widget child,
    required double width,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(-width * (1 - animation.value), 0),
        child: child,
      ),
      child: child,
    );
  }

  /// Slide animation from right
  static AnimatedBuilder slideFromRightAnimation({
    required Animation<double> animation,
    required Widget child,
    required double width,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(width * (1 - animation.value), 0),
        child: child,
      ),
      child: child,
    );
  }

  /// Slide animation from top
  static AnimatedBuilder slideFromTopAnimation({
    required Animation<double> animation,
    required Widget child,
    required double height,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -height * (1 - animation.value)),
        child: child,
      ),
      child: child,
    );
  }

  /// Scale animation
  static AnimatedBuilder scaleAnimation({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) =>
          Transform.scale(scale: animation.value, child: child),
      child: child,
    );
  }

  /// Rotation animation
  static AnimatedBuilder rotationAnimation({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.rotate(
        angle: animation.value * 2 * 3.14159, // Full rotation
        child: child,
      ),
      child: child,
    );
  }

  /// Bounce animation
  static AnimatedBuilder bounceAnimation({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final bounceValue = _bounceInterpolate(animation.value);
        return Transform.translate(
          offset: Offset(0, -bounceValue * 20),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Pulse animation helper for use with AnimatedBuilder
  static Animation<double> createPulseAnimation(
    AnimationController controller,
  ) {
    return Tween(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticInOut));
  }

  /// Shimmer loading animation
  static Widget shimmerAnimation({
    required Widget child,
    Color baseColor = const Color(0xFFE0E0E0),
    Color highlightColor = const Color(0xFFF5F5F5),
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, highlightColor, baseColor],
        ),
      ),
      child: child,
    );
  }

  /// Helper function for bounce interpolation
  static double _bounceInterpolate(double t) {
    if (t < 0.5) {
      return 2 * t;
    } else {
      return 2 * (1 - t);
    }
  }
}

/// Animated transition between pages
class SlidePageRoute extends PageRouteBuilder {
  final Widget page;
  final AxisDirection direction;

  SlidePageRoute({required this.page, this.direction = AxisDirection.right})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          Offset begin;
          switch (direction) {
            case AxisDirection.left:
              begin = const Offset(1, 0);
              break;
            case AxisDirection.right:
              begin = const Offset(-1, 0);
              break;
            case AxisDirection.up:
              begin = const Offset(0, 1);
              break;
            case AxisDirection.down:
              begin = const Offset(0, -1);
              break;
          }

          const end = Offset.zero;
          const curve = Curves.ease;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      );
}

/// Fade page transition
class FadePageRoute extends PageRouteBuilder {
  final Widget page;

  FadePageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}
