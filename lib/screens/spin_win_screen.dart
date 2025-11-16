import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../services/ad_service.dart';

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
  late AdService _adService;

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
    _adService = AdService();
    _adService.loadRewardedAd();
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

  Future<void> _showRewardDialogWithAd() async {
    if (_lastReward == null) return;

    final userProvider = context.read<UserProvider>();
    final rewardAmount = rewards[_lastReward!];
    final label = labels[_lastReward!];
    final emoji = emojis[_lastReward!];
    final colorScheme = Theme.of(context).colorScheme;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button dismissal
        child: AlertDialog(
          title: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Congratulations!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'You won',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha(179),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('coin.png', width: 24, height: 24),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'coins',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.play_circle,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Watch an ad to double your reward!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await userProvider.claimSpinReward(
                    rewardAmount,
                    watchedAd: false,
                  );
                  if (mounted) {
                    await userProvider.loadUserData(userProvider.userData!.uid);
                    Navigator.pop(context);
                    SnackbarHelper.showSuccess(
                      context,
                      '✅ Claimed $rewardAmount coins!',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    SnackbarHelper.showError(context, 'Error: $e');
                  }
                }
              },
              child: Text(
                'Claim',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  bool rewardGiven = await _adService.showRewardedAd(
                    onUserEarnedReward: (RewardItem reward) async {
                      try {
                        final doubledReward = rewardAmount * 2;
                        await userProvider.claimSpinReward(
                          doubledReward,
                          watchedAd: true,
                        );
                        if (mounted) {
                          await userProvider.loadUserData(
                            userProvider.userData!.uid,
                          );
                          Navigator.pop(context);
                          SnackbarHelper.showSuccess(
                            context,
                            '🎉 Claimed $doubledReward coins (doubled)!',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          SnackbarHelper.showError(context, 'Error: $e');
                        }
                      }
                    },
                  );

                  if (!rewardGiven && mounted) {
                    SnackbarHelper.showError(
                      context,
                      'Ad not ready. Try again later.',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    SnackbarHelper.showError(context, 'Error showing ad: $e');
                  }
                }
              },
              icon: const Icon(Iconsax.play_circle),
              label: const Text('Watch Ad'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
              ),
            ),
          ],
        ),
      ),
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondaryContainer,
                        colorScheme.secondaryContainer.withAlpha(153),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.secondary.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Spins Remaining',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          spinsPerDay,
                          (index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index < spinsRemaining
                                    ? colorScheme.error
                                    : colorScheme.outline.withAlpha(64),
                                boxShadow: index < spinsRemaining
                                    ? [
                                        BoxShadow(
                                          color: colorScheme.error.withAlpha(
                                            102,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Iconsax.heart,
                                color: index < spinsRemaining
                                    ? Colors.white
                                    : colorScheme.outline,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ========== SPINNING WHEEL ==========
                Container(
                  height: 360,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withAlpha(77),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildFortuneWheel(colorScheme),
                  ),
                ),
                const SizedBox(height: 32),

                // ========== SPIN BUTTON ==========
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _isSpinning || spinsRemaining <= 0
                        ? null
                        : _spin,
                    icon: const Icon(Iconsax.star, size: 24),
                    label: Text(
                      'SPIN NOW',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      disabledBackgroundColor: colorScheme.outline.withAlpha(
                        128,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ========== INFO BOX ==========
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withAlpha(128),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.tertiary.withAlpha(102),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Iconsax.info_circle,
                        color: colorScheme.tertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You get 3 free spins daily.\nSpins reset at 22:00 IST.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                height: 1.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ========== PRIZE BREAKDOWN HEADER ==========
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prize Breakdown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '6 Prizes',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ========== PRIZE LIST ==========
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(64),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < labels.length; i++) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  emojis[i],
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Image.asset(
                                          'coin.png',
                                          width: 16,
                                          height: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          labels[i],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Prize #${i + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withAlpha(128),
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: rewardColors[rewards[i]]?.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      rewardColors[rewards[i]]?.withAlpha(
                                        102,
                                      ) ??
                                      colorScheme.primary,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '1/6',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      rewardColors[rewards[i]] ??
                                      colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (i < labels.length - 1) ...[
                          const SizedBox(height: 12),
                          Divider(
                            color: colorScheme.outline.withAlpha(64),
                            height: 1,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
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
    return FortuneWheel(
      selected: _selectedItem.stream,
      items: [
        for (int i = 0; i < rewards.length; i++)
          FortuneItem(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emojis[i], style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  labels[i],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            style: FortuneItemStyle(
              color: rewardColors[rewards[i]] ?? colorScheme.primary,
              borderColor: Colors.white.withAlpha(204),
              borderWidth: 4,
            ),
          ),
      ],
      physics: CircularPanPhysics(
        duration: const Duration(seconds: 4),
        curve: Curves.decelerate,
      ),
      onAnimationEnd: () {
        if (mounted) {
          setState(() => _isSpinning = false);
          _showRewardDialogWithAd();
        }
      },
      indicators: [
        FortuneIndicator(
          alignment: Alignment.topCenter,
          child: TriangleIndicator(
            color: Colors.red,
            width: 25,
            height: 35,
            elevation: 8,
          ),
        ),
      ],
    );
  }
}
