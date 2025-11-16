import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';

class WatchEarnScreen extends StatefulWidget {
  const WatchEarnScreen({super.key});

  @override
  State<WatchEarnScreen> createState() => _WatchEarnScreenState();
}

class _WatchEarnScreenState extends State<WatchEarnScreen> {
  static const int maxAdsPerDay = 10;
  static const int coinsPerAd = 5;

  late AdService _adService;

  @override
  void initState() {
    super.initState();
    _adService = AdService();
    // Preload rewarded ads when screen opens
    _adService.loadRewardedAd();
  }

  Future<void> _watchAd(int adIndex) async {
    final userProvider = context.read<UserProvider>();
    final watched = userProvider.userData?.watchedAdsToday ?? 0;

    if (watched >= maxAdsPerDay) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'ve reached your daily ad limit'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show real rewarded ad
    try {
      bool rewardGiven = await _adService.showRewardedAd(
        onUserEarnedReward: (RewardItem reward) async {
          // Add coins when reward is earned
          try {
            await userProvider.updateCoins(coinsPerAd);

            // Increment watched ads counter
            await userProvider.incrementWatchedAds();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        '🎁 Earned $coinsPerAd coins! Total: ${reward.amount}',
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }

            // Reload user data to refresh UI
            if (mounted && userProvider.userData?.uid != null) {
              await userProvider.loadUserData(userProvider.userData!.uid);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating coins: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      );

      if (!rewardGiven && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not ready yet. Try again in a moment.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing ad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch & Earn'),
        elevation: 0,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Row(
                    children: [
                      Image.asset(
                        'coin.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${userProvider.userData?.coins ?? 0}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final watched = userProvider.userData?.watchedAdsToday ?? 0;
          final remaining = maxAdsPerDay - watched;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          '$watched/$maxAdsPerDay',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        const Text('Ads Watched Today'),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: watched / maxAdsPerDay,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '💰 ${watched * coinsPerAd}/${maxAdsPerDay * coinsPerAd} Coins',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (remaining > 0) ...[
                  Text(
                    'Available Ads ($remaining remaining)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Watch real ads to earn coins!',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(remaining, (index) {
                    final adNumber = watched + index + 1;
                    return _buildAdCard(
                      adNumber: adNumber,
                      onWatch: () => _watchAd(adNumber - 1),
                      isDisabled: false,
                    );
                  }),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Daily Limit Reached! 🎉',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'ve earned ${watched * coinsPerAd} coins today.\nCome back tomorrow for more ads!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdCard({
    required int adNumber,
    required VoidCallback onWatch,
    required bool isDisabled,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey.shade200
                      : Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    isDisabled ? Icons.lock : Icons.video_library,
                    color: isDisabled
                        ? Colors.grey.shade600
                        : Colors.purple.shade700,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ad #$adNumber',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      isDisabled
                          ? 'Daily limit reached'
                          : 'Watch to earn $coinsPerAd coins',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDisabled ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!isDisabled)
                      Text(
                        '🎥 Real ads from advertisers',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: isDisabled ? null : onWatch,
                icon: Icon(isDisabled ? Icons.lock : Icons.play_arrow),
                label: Text(isDisabled ? 'Locked' : 'Watch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
