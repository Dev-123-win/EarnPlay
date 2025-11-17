import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../services/ad_service.dart';

class DailyStreakScreen extends StatefulWidget {
  const DailyStreakScreen({super.key});

  @override
  State<DailyStreakScreen> createState() => _DailyStreakScreenState();
}

class _DailyStreakScreenState extends State<DailyStreakScreen>
    with WidgetsBindingObserver {
  late AdService _adService;
  final Map<int, NativeAd?> _nativeAds = {};
  bool _streakResetNotified = false;

  @override
  void initState() {
    super.initState();
    _adService = AdService();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Load native ad with proper error handling
  void _loadNativeAd(int adIndex) {
    // Prevent duplicate loads
    if (_nativeAds.containsKey(adIndex)) return;

    _adService.loadNativeAd(
      onAdLoaded: (NativeAd ad) {
        if (mounted) {
          setState(() {
            _nativeAds[adIndex] = ad;
          });
        }
      },
      onAdFailed: (LoadAdError error) {
        // Silent fail - continue without ad
        if (mounted) {
          setState(() {
            _nativeAds[adIndex] = null;
          });
        }
      },
    );
  }

  /// Claim today's streak reward
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
          '🔥 Streak claimed! +$coinsEarned coins earned',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, '$e');
      }
    }
  }

  /// Auto-reset streak if a day was missed
  Future<void> _checkAndAutoReset() async {
    try {
      final userProvider = context.read<UserProvider>();
      final streak = userProvider.userData?.dailyStreak;

      if (streak == null) return;

      // Check if streak should be reset (missed a day)
      final lastCheckIn = streak.lastCheckIn;
      if (lastCheckIn == null) return;

      final now = DateTime.now();
      final daysSinceCheckIn = now.difference(lastCheckIn).inDays;

      // Auto-reset if more than 1 day has passed
      if (daysSinceCheckIn > 1 && !_streakResetNotified) {
        await userProvider.resetDailyStreak();
        _streakResetNotified = true;

        if (mounted) {
          SnackbarHelper.showInfo(
            context,
            '😢 Streak lost! Missed a day. Starting fresh.',
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.userData;
          final streak = user?.dailyStreak;

          if (streak == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Auto-check for reset on build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndAutoReset();
          });

          return CustomScrollView(
            slivers: [
              // ========== EXPRESSIVE APP BAR WITH GRADIENT ==========
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withAlpha(180),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(100),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🔥 Daily Streak',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Claim daily rewards & build your streak',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colorScheme.onPrimary.withAlpha(200),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  collapseMode: CollapseMode.parallax,
                ),
              ),

              // ========== CONTENT ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ========== STREAK COUNTER CARD WITH SHADOW ==========
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.primaryContainer.withAlpha(150),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.primary.withAlpha(50),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(60),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Current Streak',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withAlpha(180),
                                    letterSpacing: 0.3,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${streak.currentStreak}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'days',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      streak.currentStreak >= 7
                                          ? 'Perfect!'
                                          : 'Keep going!',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.tertiary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ========== 7-DAY PROGRESS TRACKER (NO SCROLL) ==========
                      Text(
                        'Week Progress',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withAlpha(64),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Day numbers row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final day = index + 1;
                                return Text(
                                  'D$day',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface.withAlpha(
                                          128,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            // Progress boxes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final isCompleted =
                                    index < streak.currentStreak;
                                final isToday = index == streak.currentStreak;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: GestureDetector(
                                      onTap: isToday ? _claimStreak : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: isCompleted
                                              ? LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    colorScheme.tertiary,
                                                    colorScheme.tertiary
                                                        .withAlpha(200),
                                                  ],
                                                )
                                              : (isToday
                                                    ? LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                        colors: [
                                                          colorScheme.primary,
                                                          colorScheme.primary
                                                              .withAlpha(180),
                                                        ],
                                                      )
                                                    : LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                        colors: [
                                                          colorScheme.outline
                                                              .withAlpha(38),
                                                          colorScheme.outline
                                                              .withAlpha(26),
                                                        ],
                                                      )),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                        .withAlpha(100),
                                                    blurRadius: 12,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: isCompleted
                                              ? Icon(
                                                  Iconsax.tick_circle,
                                                  color: colorScheme.onTertiary,
                                                  size: 24,
                                                )
                                              : (isToday
                                                    ? Icon(
                                                        Iconsax.star,
                                                        color: colorScheme
                                                            .onPrimary,
                                                        size: 22,
                                                      )
                                                    : Text(
                                                        '${index + 1}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color: colorScheme
                                                                  .onSurface
                                                                  .withAlpha(
                                                                    128,
                                                                  ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      )),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ========== COMPLETION MESSAGE ==========
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: streak.currentStreak >= 7
                                ? colorScheme.tertiaryContainer
                                : colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: streak.currentStreak >= 7
                                  ? colorScheme.tertiary.withAlpha(100)
                                  : colorScheme.secondary.withAlpha(100),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            streak.currentStreak >= 7
                                ? '🎉 Week completed! Awesome work!'
                                : '${7 - streak.currentStreak} more ${7 - streak.currentStreak == 1 ? 'day' : 'days'} to complete the week',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: streak.currentStreak >= 7
                                      ? colorScheme.onTertiaryContainer
                                      : colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ========== DAILY REWARDS SECTION ==========
                      Text(
                        'Daily Rewards',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ========== REWARD CARDS WITH NATIVE ADS ==========
              SliverList.builder(
                itemCount: 7 * 2 - 1, // 7 cards + 3 native ads interspersed
                itemBuilder: (context, index) {
                  // Calculate which card and ad position
                  final cardIndex = index ~/ 2;
                  final isAdPosition = index % 2 == 1;

                  if (isAdPosition) {
                    // Show native ad between every 2 cards (positions 1, 3, 5)
                    if (cardIndex < 3) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildNativeAdContainer(cardIndex),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  // Show reward card
                  final day = cardIndex + 1;
                  final isClaimed = cardIndex < streak.currentStreak;
                  final isToday = cardIndex == streak.currentStreak;
                  final isLocked = cardIndex > streak.currentStreak;
                  final reward = day == 7 ? 500 : 50 + (day * 10);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _buildRewardCard(
                      context,
                      colorScheme,
                      day: day,
                      reward: reward,
                      isClaimed: isClaimed,
                      isToday: isToday,
                      isLocked: isLocked,
                      onClaim: isToday ? _claimStreak : null,
                    ),
                  );
                },
              ),

              // ========== BOTTOM PADDING ==========
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  /// Build reward card for each day
  Widget _buildRewardCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required int day,
    required int reward,
    required bool isClaimed,
    required bool isToday,
    required bool isLocked,
    required VoidCallback? onClaim,
  }) {
    final isDay7 = day == 7;

    // Determine card styling based on state
    late Color accentColor;
    late String statusLabel;
    late IconData statusIcon;

    if (isClaimed) {
      accentColor = isDay7 ? const Color(0xFFFFD700) : colorScheme.tertiary;
      statusLabel = 'Claimed';
      statusIcon = Iconsax.tick_circle;
    } else if (isToday) {
      accentColor = isDay7 ? const Color(0xFFFFD700) : colorScheme.primary;
      statusLabel = 'Claim Today';
      statusIcon = Iconsax.gift;
    } else if (isLocked) {
      accentColor = colorScheme.outline;
      statusLabel = 'Locked';
      statusIcon = Iconsax.lock;
    } else {
      accentColor = const Color(0xFFFF9500);
      statusLabel = 'Tomorrow';
      statusIcon = Iconsax.calendar;
    }

    return Card(
      elevation: isToday ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isToday
            ? BorderSide(color: accentColor, width: 2)
            : BorderSide(color: colorScheme.outline.withAlpha(26), width: 1),
      ),
      child: Container(
        decoration: isToday
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accentColor.withAlpha(20), accentColor.withAlpha(8)],
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ========== DAY NUMBER CIRCLE ==========
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isClaimed
                        ? [
                            colorScheme.tertiary,
                            colorScheme.tertiary.withAlpha(200),
                          ]
                        : (isToday
                              ? [accentColor, accentColor.withAlpha(180)]
                              : [
                                  colorScheme.outline.withAlpha(26),
                                  colorScheme.outline.withAlpha(13),
                                ]),
                  ),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: accentColor.withAlpha(80),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isClaimed
                      ? Icon(
                          Iconsax.tick_circle,
                          color: colorScheme.onTertiary,
                          size: 28,
                        )
                      : Text(
                          '$day',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: isToday
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface.withAlpha(128),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // ========== CONTENT ==========
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Day $day',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                        ),
                        if (isDay7) ...[
                          const SizedBox(width: 8),
                          Text(
                            '👑',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
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
                          '+$reward coins',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ========== STATUS BADGE OR BUTTON ==========
              if (isClaimed || isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withAlpha(60),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: accentColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: onClaim,
                  icon: const Icon(Iconsax.gift, size: 18),
                  label: const Text('Claim'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build native ad container with loading state
  Widget _buildNativeAdContainer(int adIndex) {
    final nativeAd = _nativeAds[adIndex];

    if (nativeAd == null) {
      // Trigger load
      _loadNativeAd(adIndex);

      // Show loading placeholder
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Show real native ad
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AdWidget(ad: nativeAd),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose all native ads
    for (var ad in _nativeAds.values) {
      if (ad != null) {
        ad.dispose();
      }
    }
    _nativeAds.clear();
    super.dispose();
  }
}
