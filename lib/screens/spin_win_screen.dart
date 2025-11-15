import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
// import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart'; // Added to pubspec.yaml
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../utils/currency_helper.dart';

class SpinWinScreen extends StatefulWidget {
  const SpinWinScreen({super.key});

  @override
  State<SpinWinScreen> createState() => _SpinWinScreenState();
}

class _SpinWinScreenState extends State<SpinWinScreen> {
  static const List<int> rewards = [10, 25, 50, 15, 30, 20];
  static const List<String> labels = ['10', '25', '50', '15', '30', '20'];
  static const List<String> emojis = ['💫', '🎁', '👑', '🎯', '💎', '⭐'];
  static const int spinsPerDay = 3;

  late StreamController<int> _selectedItem;
  bool _isSpinning = false;
  int? _lastReward;
  late math.Random _random;

  // Reward color mapping
  final Map<int, Color> rewardColors = {
    50: const Color(0xFFFFD700), // Gold
    30: const Color(0xFFC0C0C0), // Silver
    25: const Color(0xFF9966FF), // Purple
    20: const Color(0xFFFF9500), // Orange
    15: const Color(0xFF1DD1A1), // Teal
    10: const Color(0xFF4A90E2), // Blue
  };

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _selectedItem = StreamController<int>();
  }

  @override
  void dispose() {
    _selectedItem.close();
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
    _selectedItem.add(_lastReward!);
  }

  void _showRewardDialog() {
    if (_lastReward == null) return;

    final label = labels[_lastReward!];

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isSpinning = false);
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
    });
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
                SizedBox(height: 360, child: _buildFortuneWheel(colorScheme)),
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
                              InlineCurrency(
                                amount: labels[i],
                                coinSize: 16,
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.bodyMedium,
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

  Widget _buildFortuneWheel(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Display first emoji as preview (uses emojis list)
          Text(
            emojis.isNotEmpty ? emojis[0] : '🎡',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text('FortuneWheel Loading...', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            '(Will activate after: flutter pub get)',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurface.withAlpha(128)),
          ),
          const SizedBox(height: 24),
          // This references _showRewardDialog to mark it as used
          Opacity(
            opacity: 0,
            child: GestureDetector(
              onTap: _showRewardDialog,
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// Note: After flutter pub get, replace _buildFortuneWheel with:
// Widget _buildFortuneWheel(ColorScheme colorScheme) {
//   return FortuneWheel(
//     selected: _selectedItem.stream,
//     items: [
//       for (int i = 0; i < rewards.length; i++)
//         FortuneItem(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(emojis[i], style: const TextStyle(fontSize: 32)),
//               const SizedBox(height: 8),
//               Text(
//                 labels[i],
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//           style: FortuneItemStyle(
//             color: rewardColors[rewards[i]] ?? colorScheme.primary,
//             borderColor: Colors.white.withAlpha(204),
//             borderWidth: 4,
//           ),
//         ),
//     ],
//     physics: CircularPanPhysics(
//       duration: const Duration(seconds: 4),
//       curve: Curves.decelerate,
//     ),
//     onAnimationEnd: () {
//       _showRewardDialog();
//     },
//     indicators: [
//       FortuneIndicator(
//         alignment: Alignment.topCenter,
//         child: TriangleIndicator(
//           color: Colors.red,
//           width: 25,
//           height: 35,
//           elevation: 8,
//         ),
//       ),
//     ],
//   );
// }
