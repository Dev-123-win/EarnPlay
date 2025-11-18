import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';
import '../utils/currency_helper.dart';
import '../widgets/custom_app_bar.dart'; // Import CustomAppBar

class WatchEarnScreen extends StatefulWidget {
  const WatchEarnScreen({super.key});

  @override
  State<WatchEarnScreen> createState() => _WatchEarnScreenState();
}

class _WatchEarnScreenState extends State<WatchEarnScreen> {
  static const int maxAdsPerDay = 10;
  static const int coinsPerAd = 5;

  late AdService _adService;
  final Map<int, NativeAd?> _nativeAds = {};

  @override
  void initState() {
    super.initState();
    _adService = AdService();
    _adService.loadRewardedAd();
  }

  @override
  void dispose() {
    for (var ad in _nativeAds.values) {
      if (ad != null) {
        _adService.disposeNativeAd(ad);
      }
    }
    super.dispose();
  }

  Future<void> _watchAd(int adIndex, ColorScheme colorScheme) async {
    final userProvider = context.read<UserProvider>();
    final watched = userProvider.userData?.watchedAdsToday ?? 0;

    if (watched >= maxAdsPerDay) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Daily limit reached. Come back tomorrow!',
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
            backgroundColor: colorScheme.secondaryContainer,
          ),
        );
      }
      return;
    }

    try {
      bool rewardGiven = await _adService.showRewardedAd(
        onUserEarnedReward: (RewardItem reward) async {
          try {
            // ✅ Phase 1: Pass adUnitId to worker
            await userProvider.incrementWatchedAds(
              coinsPerAd,
              adUnitId: AdService.rewardedAdId, // Pass the ad unit ID
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Earned $coinsPerAd coins!',
                        style: TextStyle(
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: colorScheme.tertiaryContainer,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error: $e',
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                  backgroundColor: colorScheme.errorContainer,
                ),
              );
            }
          }
        },
      );

      if (!rewardGiven && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ad not ready. Try again in a moment.',
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
            backgroundColor: colorScheme.secondaryContainer,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            backgroundColor: colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Watch Ads', showBackButton: true),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final watched = userProvider.userData?.watchedAdsToday ?? 0;
          final remaining = maxAdsPerDay - watched;

          return CustomScrollView(
            slivers: [
              // ========== PROGRESS SECTION ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress counter card
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withAlpha(200),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(80),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today\'s Progress',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: colorScheme.onPrimary.withAlpha(
                                        200,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$watched / $maxAdsPerDay Ads',
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      CurrencyDisplay(
                                        coins: watched * coinsPerAd,
                                        coinSize: 16,
                                        spacing: 6,
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        showRealCurrency: true,
                                      ),
                                    ],
                                  ),
                                  // Circular progress indicator
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: CircularProgressIndicator(
                                            value: watched / maxAdsPerDay,
                                            strokeWidth: 6,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  colorScheme.onPrimary,
                                                ),
                                            backgroundColor: colorScheme
                                                .onPrimary
                                                .withAlpha(100),
                                          ),
                                        ),
                                        Text(
                                          '${((watched / maxAdsPerDay) * 100).toStringAsFixed(0)}%',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: colorScheme.onPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ========== ADS LIST ==========
              if (remaining > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Ads',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$remaining remaining today',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color?.withAlpha(150),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (remaining > 0)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final adNumber = watched + index + 1;
                      return Column(
                        children: [
                          _buildAdCard(
                            adNumber: adNumber,
                            onWatch: () => _watchAd(adNumber - 1, colorScheme),
                          ),
                          const SizedBox(height: 12),
                          // Native ad every 3 cards
                          if ((index + 1) % 3 == 0 &&
                              index != remaining - 1) ...[
                            _buildNativeAdContainer(index),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }, childCount: remaining),
                  ),
                )
              else
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primaryContainer,
                            ),
                            child: Icon(
                              Iconsax.tick_circle,
                              size: 40,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Daily Limit Reached! 🎉',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          CurrencyDisplay(
                            coins: watched * coinsPerAd,
                            coinSize: 24,
                            spacing: 8,
                            textStyle: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                            showRealCurrency: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Earned today',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.color
                                      ?.withAlpha(150),
                                ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Come back tomorrow for more ads!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color?.withAlpha(150),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ========== BOTTOM PADDING ==========
              if (remaining > 0)
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  /// Build ad card - minimal, clear CTA
  Widget _buildAdCard({required int adNumber, required VoidCallback onWatch}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.primaryContainer.withAlpha(30),
        border: Border.all(color: colorScheme.primary.withAlpha(50), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onWatch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon only - no large wasted space
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withAlpha(40),
                  ),
                  child: Icon(
                    Iconsax.video,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Info section - ad # and reward CLEAR & PROMINENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ad #$adNumber',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      CurrencyDisplay(
                        coins: coinsPerAd,
                        coinSize: 14,
                        spacing: 4,
                        textStyle: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        showRealCurrency: false,
                      ),
                    ],
                  ),
                ),

                // CTA button - prominent
                FilledButton(
                  onPressed: onWatch,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    'Watch',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build native ad container with smart loading
  Widget _buildNativeAdContainer(int adIndex) {
    if (!_nativeAds.containsKey(adIndex)) {
      _loadNativeAd(adIndex);
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(12),
        height: 100,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final nativeAd = _nativeAds[adIndex];
    if (nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: AdWidget(ad: nativeAd),
    );
  }

  /// Load native ad with error handling
  void _loadNativeAd(int adIndex) {
    _adService.loadNativeAd(
      onAdLoaded: (NativeAd ad) {
        if (mounted && !_nativeAds.containsKey(adIndex)) {
          setState(() {
            _nativeAds[adIndex] = ad;
          });
        }
      },
      onAdFailed: (LoadAdError error) {
        // Silently fail - don't show placeholder if ad fails
      },
    );
  }
}
