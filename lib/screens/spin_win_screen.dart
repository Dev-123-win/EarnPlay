import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';

class SpinWinScreen extends StatefulWidget {
  const SpinWinScreen({super.key});

  @override
  State<SpinWinScreen> createState() => _SpinWinScreenState();
}

class _SpinWinScreenState extends State<SpinWinScreen>
    with SingleTickerProviderStateMixin {
  static const List<int> rewards = [10, 25, 50, 15, 30, 20];
  static const List<String> labels = ['₹10', '₹25', '₹50', '₹15', '₹30', '₹20'];
  static const int spinsPerDay = 3;

  late AnimationController _animationController;
  bool _isSpinning = false;
  int? _lastReward;
  late math.Random _random;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isSpinning = false);
        _showRewardDialog();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    final userProvider = context.read<UserProvider>();
    final spinsRemaining = userProvider.userData?.totalSpins ?? 0;

    if (spinsRemaining <= 0) {
      if (mounted) {
        SnackbarHelper.showError(context, 'No spins remaining today!');
      }
      return;
    }

    setState(() => _isSpinning = true);

    _lastReward = _random.nextInt(rewards.length);

    _animationController.forward(from: 0.0);
  }

  void _showRewardDialog() {
    if (_lastReward == null) return;

    final label = labels[_lastReward!];

    DialogSystem.showGameResultDialog(
      context,
      title: 'Congratulations!',
      emoji: '🎉',
      reward: 'You won $label',
      onPlayAgain: () {
        // Spin again
        _spin();
      },
      onMainMenu: () {
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin & Win'),
        elevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final spinsRemaining = userProvider.userData?.totalSpins ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ========== SPINS REMAINING CARD ==========
                Card(
                  elevation: 0,
                  color: colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Spins Remaining Today',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSecondaryContainer
                                    .withAlpha(178),
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            spinsPerDay,
                            (index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                                child: Icon(
                                Iconsax.heart,
                                color: index < spinsRemaining
                                    ? colorScheme.error
                                    : colorScheme.outline.withAlpha(77),
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ========== SPINNING WHEEL ==========
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Wheel
                      Transform.rotate(
                        angle: _animationController.value * 10 * 2 * math.pi,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withAlpha(77),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: WheelPainter(rewards, labels, colorScheme),
                          ),
                        ),
                      ),
                      // Pointer
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.errorContainer,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.error.withAlpha(102),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Iconsax.arrow_down,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ========== SPIN BUTTON ==========
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSpinning || spinsRemaining <= 0
                        ? null
                        : _spin,
                    icon: const Icon(Iconsax.star),
                    label: const Text('SPIN NOW'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ========== INFO BOX ==========
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.info_circle, color: colorScheme.tertiary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You get 3 free spins daily.\nSpins reset at 22:00 IST.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ========== HOW IT WORKS ==========
                Text(
                  'Prize Breakdown',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (int i = 0; i < labels.length; i++) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                labels[i],
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '1/${rewards.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (i < labels.length - 1) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<int> rewards;
  final List<String> labels;
  final ColorScheme colorScheme;

  WheelPainter(this.rewards, this.labels, this.colorScheme);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final segmentAngle = 2 * math.pi / rewards.length;

    // Define distinct Material 3 colors for each segment
    final segmentColors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
    ];

    for (int i = 0; i < rewards.length; i++) {
      final startAngle = i * segmentAngle - math.pi / 2;
      final paint = Paint()
        ..color = segmentColors[i % segmentColors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white.withAlpha(128)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Draw text
      final textAngle = startAngle + segmentAngle / 2;
      final textX = center.dx + (radius * 0.65) * math.cos(textAngle);
      final textY = center.dy + (radius * 0.65) * math.sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(textX - textPainter.width / 2, textY - textPainter.height / 2),
      );
    }

    // Draw center circle
    final centerPaint = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.2, centerPaint);

    final centerBorderPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius * 0.2, centerBorderPaint);
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) => false;
}
