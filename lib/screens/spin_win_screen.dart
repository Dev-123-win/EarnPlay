import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import '../services/worker_service.dart';
import 'package:uuid/uuid.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../services/ad_service.dart';
import '../services/navigation_service.dart';
import '../widgets/custom_app_bar.dart';

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

    // Ask server to perform spin (server-controlled RNG)
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await WorkerService().verifySpin();

      if (mounted) Navigator.of(context).pop();

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        int? serverIndex;
        if (data.containsKey('index')) {
          serverIndex = (data['index'] as num).toInt();
        }

        // Fallback to server reward mapping if index not provided
        if (serverIndex == null && data.containsKey('reward')) {
          final reward = (data['reward'] as num).toInt();
          serverIndex = rewards.indexOf(reward);
        }

        // If server didn't return an index/reward, fallback to client RNG
        serverIndex ??= _random.nextInt(rewards.length);

        _lastReward = serverIndex;
        _selectedItem.add(_lastReward!);
      } else {
        // Server failed - fallback to client RNG but inform user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Spin failed, try again')),
          );
        }
        setState(() => _isSpinning = false);
      }
    } catch (e) {
      try {
        if (mounted) Navigator.of(context).pop();
      } catch (_) {}
      // Fallback to local RNG
      _lastReward = _random.nextInt(rewards.length);
      _selectedItem.add(_lastReward!);
    }
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
      builder: (context) => PopScope(
        canPop: false,
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
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.play_circle,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Watch an ad to double your reward!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onPrimaryContainer,
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
                // Base reward already credited by server spin; refresh local data
                try {
                  final uid = userProvider.userData?.uid;
                  if (uid != null) {
                    await userProvider.loadUserData(uid);
                  }
                  if (mounted) {
                    AppRouter().goBack();
                    SnackbarHelper.showSuccess(context, '✅ Reward credited!');
                  }
                } catch (e) {
                  if (mounted) SnackbarHelper.showError(context, 'Error: $e');
                }
              },
              child: Text('OK', style: TextStyle(color: colorScheme.primary)),
            ),
            FilledButton.icon(
              onPressed: () async {
                // Double reward by watching an ad — send SPIN_DOUBLE event to worker
                try {
                  final uid = userProvider.userData?.uid;
                  if (uid == null) throw Exception('User not loaded');

                  // Prepare event to award extra coins equal to base reward
                  final eventId = const Uuid().v4();
                  final event = {
                    'id': eventId,
                    'type': 'SPIN_DOUBLE',
                    'coins': rewardAmount,
                    'metadata': {'spinIndex': _lastReward},
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                    'idempotencyKey': '${uid}_$eventId',
                  };

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final res = await WorkerService().batchEvents(
                    userId: uid,
                    events: [event],
                  );

                  if (mounted) Navigator.of(context).pop();

                  if (res['success'] == true) {
                    // Refresh local user data
                    await userProvider.loadUserData(uid);
                    if (mounted) {
                      AppRouter().goBack();
                      SnackbarHelper.showSuccess(context, '🎉 Reward doubled!');
                    }
                  } else {
                    if (mounted) {
                      SnackbarHelper.showError(
                        context,
                        'Failed to award doubled reward',
                      );
                    }
                  }
                } catch (e) {
                  try {
                    if (mounted) Navigator.of(context).pop();
                  } catch (_) {}
                  if (mounted) SnackbarHelper.showError(context, 'Error: $e');
                }
              },
              icon: const Icon(Iconsax.play_circle),
              label: const Text('Watch Ad'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
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
      appBar: const CustomAppBar(title: 'Spin & Win', showBackButton: true),
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
                        'Spins Remaining Today',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              spinsPerDay,
                              (index) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  index < spinsRemaining
                                      ? Iconsax.heart5
                                      : Iconsax.heart,
                                  color: index < spinsRemaining
                                      ? colorScheme.error
                                      : colorScheme.outline.withAlpha(100),
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Countdown to next reset at 04:30
                          StreamBuilder<DateTime>(
                            stream: Stream.periodic(const Duration(seconds: 1), (_) {
                              final now = DateTime.now();
                              var next = DateTime(now.year, now.month, now.day, 4, 30);
                              if (!next.isAfter(now)) {
                                // move to next day
                                next = next.add(const Duration(days: 1));
                              }
                              return next;
                            }),
                            builder: (context, snap) {
                              final target = snap.data ?? DateTime.now();
                              final remaining = target.difference(DateTime.now());
                              final twoDigits = (int n) => n.toString().padLeft(2, '0');
                              final hours = twoDigits(remaining.inHours.remainder(24));
                              final minutes = twoDigits(remaining.inMinutes.remainder(60));
                              final seconds = twoDigits(remaining.inSeconds.remainder(60));
                              return Text(
                                'Resets in $hours:$minutes:$seconds',
                                style: Theme.of(context).textTheme.labelSmall,
                              );
                            },
                          ),
                        ],
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
                          'You get 3 free spins daily.\nSpins reset at 04:30 AM.',
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
            color: colorScheme.error,
            width: 25,
            height: 35,
            elevation: 8,
          ),
        ),
      ],
    );
  }
}
