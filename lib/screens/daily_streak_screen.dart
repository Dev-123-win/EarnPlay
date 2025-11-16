import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../services/ad_service.dart';

class DailyStreakScreen extends StatefulWidget {
  const DailyStreakScreen({super.key});

  @override
  State<DailyStreakScreen> createState() => _DailyStreakScreenState();
}

class _DailyStreakScreenState extends State<DailyStreakScreen> {
  late AdService _adService;

  @override
  void initState() {
    super.initState();
    _adService = AdService();
  }

  Future<void> _claimStreak() async {
    try {
      final userProvider = context.read<UserProvider>();

      // Call the actual claim streak method from provider
      await userProvider.claimDailyStreak();

      if (mounted) {
        final coinsEarned =
            (userProvider.userData?.dailyStreak.currentStreak ?? 0) * 10;
        SnackbarHelper.showSuccess(
          context,
          '✅ Streak claimed! $coinsEarned coins earned',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error claiming streak: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Streak'),
        elevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.userData;
          final streak = user?.dailyStreak;

          if (streak == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ========== STREAK CARD ==========
                Card(
                  elevation: 0,
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Current Streak',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 179),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.star,
                              color: colorScheme.error,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${streak.currentStreak}',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'days',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ========== STEP PROGRESS INDICATOR (Example 8 Style) ==========
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: colorScheme.primary.withAlpha(13),
                            border: Border.all(
                              color: colorScheme.primary.withAlpha(51),
                              width: 1,
                            ),
                          ),
                          child: StepProgressIndicator(
                            totalSteps: 7,
                            currentStep: streak.currentStreak.clamp(0, 7),
                            size: 50,
                            padding: 8,
                            selectedColor: const Color(
                              0xFF1DD1A1,
                            ), // Green for completed
                            unselectedColor: colorScheme.primary.withAlpha(
                              51,
                            ), // Light purple for pending
                            roundedEdges: const Radius.circular(12),
                            customStep: (index, color, _) {
                              final step = index + 1;
                              final isCompleted = index < streak.currentStreak;
                              final isToday = index == streak.currentStreak;

                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isCompleted
                                      ? const Color(0xFF1DD1A1)
                                      : (isToday
                                            ? colorScheme.primary
                                            : colorScheme.primary.withAlpha(
                                                51,
                                              )),
                                  border: isToday
                                      ? Border.all(
                                          color: colorScheme.primary,
                                          width: 2,
                                        )
                                      : null,
                                  boxShadow: isToday
                                      ? [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withAlpha(76),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? Icon(
                                          Iconsax.tick_circle,
                                          size: 24,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          '$step',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isToday
                                                ? colorScheme.onPrimary
                                                : colorScheme.onSurface
                                                      .withAlpha(128),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          streak.currentStreak >= 7
                              ? '🎉 Amazing! You completed the week!'
                              : '${7 - streak.currentStreak} more days to complete the week',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== DAILY REWARDS ==========
                Text(
                  'Daily Rewards',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                ...List.generate(7, (index) {
                  final day = index + 1;
                  final isClaimed = index < streak.currentStreak;
                  final isToday = index == streak.currentStreak;
                  final isLocked = index > streak.currentStreak;
                  final reward = day == 7 ? 500 : 50 + (day * 10);

                  return Column(
                    children: [
                      _buildDayCard(
                        context,
                        colorScheme,
                        day: day,
                        reward: reward,
                        isClaimed: isClaimed,
                        isToday: isToday,
                        isLocked: isLocked,
                        onClaim: isToday ? _claimStreak : null,
                      ),
                      // Show native ad between every 2 cards
                      if ((index + 1) % 2 == 0 && index != 6) ...[
                        const SizedBox(height: 8),
                        _buildNativeAdPlaceholder(),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required int day,
    required int reward,
    required bool isClaimed,
    required bool isToday,
    required bool isLocked,
    required VoidCallback? onClaim,
  }) {
    // Color scheme constants
    const Color claimedColor = Color(0xFF1DD1A1); // Teal/Green
    const Color tomorrowColor = Color(0xFFFF9500); // Soft Orange
    const Color lockedColor = Color(0xFFB0B0B0); // Muted Gray
    const Color day7Gold = Color(0xFFFFD700); // Gold

    late Color statusColor;
    late String statusText;
    late IconData statusIcon;
    bool isDay7 = day == 7;

    if (isClaimed) {
      statusColor = isDay7 ? day7Gold : claimedColor;
      statusText = 'Claimed';
      statusIcon = Iconsax.tick_circle;
    } else if (isToday) {
      statusColor = isDay7 ? day7Gold : colorScheme.primary;
      statusText = 'Claim Today';
      statusIcon = Iconsax.gift;
    } else if (isLocked) {
      statusColor = lockedColor;
      statusText = 'Locked';
      statusIcon = Iconsax.lock;
    } else {
      statusColor = tomorrowColor;
      statusText = 'Tomorrow';
      statusIcon = Iconsax.calendar;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isDay7 && (isClaimed || isToday) ? 4 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDay7 && (isClaimed || isToday)
              ? BorderSide(color: statusColor, width: 2)
              : BorderSide.none,
        ),
        child: Container(
          decoration: isDay7 && (isClaimed || isToday)
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 26),
                      statusColor.withValues(alpha: 13),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Day $day',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDay7 && (isClaimed || isToday)
                                    ? statusColor
                                    : null,
                              ),
                        ),
                        if (isDay7) const SizedBox(width: 8),
                        if (isDay7)
                          Text(
                            '👑',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // ===== COIN DISPLAY WITH IMAGE =====
                    Row(
                      children: [
                        Image.asset(
                          'coin.png',
                          width: 16,
                          height: 16,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$reward coins',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isClaimed || isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: onClaim,
                    icon: const Icon(Iconsax.gift),
                    label: const Text('Claim'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNativeAdPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.local_offer,
              color: Colors.green.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sponsored Offer',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Check special deals for you',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'View',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _adService.disposeBannerAd();
    super.dispose();
  }
}
