import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';

class DailyStreakScreen extends StatefulWidget {
  const DailyStreakScreen({super.key});

  @override
  State<DailyStreakScreen> createState() => _DailyStreakScreenState();
}

class _DailyStreakScreenState extends State<DailyStreakScreen> {
  Future<void> _claimStreak() async {
    try {
      // Simulate claiming streak
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        SnackbarHelper.showSuccess(context, '✅ Streak claimed! ₹50 earned');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
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
                        // Progress bar with segment markers and glow effect
                        Column(
                          children: [
                            Stack(
                              children: [
                                // Glow effect background
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.primary.withValues(
                                            alpha: 102,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: (streak.currentStreak / 7).clamp(
                                      0,
                                      1,
                                    ),
                                    minHeight: 8,
                                    backgroundColor: colorScheme.primary
                                        .withValues(alpha: 51),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Segment markers
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final day = index + 1;
                                final isCompleted =
                                    index < streak.currentStreak;
                                final isToday = index == streak.currentStreak;

                                return Column(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCompleted
                                            ? const Color(0xFF1DD1A1)
                                            : (isToday
                                                  ? colorScheme.primary
                                                  : colorScheme.surfaceDim),
                                        border: isToday
                                            ? Border.all(
                                                color: colorScheme.primary,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: Center(
                                        child: isCompleted
                                            ? Icon(
                                                Iconsax.tick_circle,
                                                size: 18,
                                                color: Colors.white,
                                              )
                                            : Text(
                                                '$day',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isToday
                                                      ? Colors.white
                                                      : colorScheme.onSurface,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'D$day',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 128,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
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

                  return _buildDayCard(
                    context,
                    colorScheme,
                    day: day,
                    reward: reward,
                    isClaimed: isClaimed,
                    isToday: isToday,
                    isLocked: isLocked,
                    onClaim: isToday ? _claimStreak : null,
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
                    Text(
                      '₹$reward',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isClaimed || isToday || isLocked)
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
}
