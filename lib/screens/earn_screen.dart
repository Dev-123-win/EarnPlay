import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_helper.dart';
import 'package:iconsax/iconsax.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  late AdService _adService;
  BannerAd? _bannerAd;
  bool _expandMoreMethods = false;

  @override
  @override
  void initState() {
    super.initState();
    _adService = AdService();
    _loadUserData();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = _adService.createBannerAd();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseService().currentUser;
    if (user != null && mounted) {
      await context.read<UserProvider>().loadUserData(user.uid);
      if (mounted) {
        await context.read<GameProvider>().loadGameStats(user.uid);
      }
    }
  }

  @override
  void dispose() {
    _adService.disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userProvider.userData == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.warning_2, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load data',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loadUserData,
                    icon: const Icon(Iconsax.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // ========== HEADER: BALANCE CARD (SIMPLE & BOLD) ==========
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.primary,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Balance',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onPrimary.withAlpha(200),
                            ),
                      ),
                      const SizedBox(height: 8),
                      CurrencyDisplay(
                        coins: userProvider.userData!.coins,
                        coinSize: 32,
                        spacing: 10,
                        textStyle: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                        showRealCurrency: true,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () async => await AppRouter().goToWallet(),
                          icon: const Icon(Iconsax.wallet_2),
                          label: const Text('Withdraw'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.onPrimary,
                            foregroundColor: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ========== PRIMARY: DAILY STREAK (MOST IMPORTANT) ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Check-In',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _buildStreakCard(context, userProvider, colorScheme),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ========== SECONDARY: WATCH AD (ALWAYS VISIBLE) ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch & Earn',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _buildAdCard(context, userProvider, colorScheme),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ========== TERTIARY: PREMIUM SPIN ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Spin',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _buildSpinCard(context, userProvider, colorScheme),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ========== COLLAPSIBLE: MORE WAYS TO EARN ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: colorScheme.outline.withAlpha(50),
                            ),
                            bottom: BorderSide(
                              color: colorScheme.outline.withAlpha(50),
                            ),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(
                              () => _expandMoreMethods = !_expandMoreMethods,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    _expandMoreMethods
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'More Ways to Earn',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_expandMoreMethods) ...[
                        const SizedBox(height: 16),
                        _buildGameCard(
                          context,
                          'Tic-Tac-Toe',
                          'Play vs AI',
                          Iconsax.game,
                          colorScheme.secondary,
                          () async => await AppRouter().goToTicTacToe(),
                        ),
                        const SizedBox(height: 12),
                        _buildGameCard(
                          context,
                          'Whack-A-Mole',
                          'Test reflexes',
                          Iconsax.cpu,
                          colorScheme.tertiary,
                          () async => await AppRouter().goToWhackMole(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ========== BANNER AD ==========
              if (_bannerAd != null && _adService.isBannerAdReady)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStreakCard(
    BuildContext context,
    UserProvider provider,
    ColorScheme colorScheme,
  ) {
    final streak = provider.userData?.dailyStreak.currentStreak ?? 0;
    final isEligible =
        (provider.userData?.dailyStreak.lastCheckIn?.day != DateTime.now().day);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.tertiary, colorScheme.tertiary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak Day Streak',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onTertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${streak * 5} coins per day',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onTertiary.withAlpha(200),
                    ),
                  ),
                ],
              ),
              Text('🔥', style: const TextStyle(fontSize: 40)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isEligible
                  ? () async =>
                        await context.read<UserProvider>().claimDailyStreak()
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onTertiary,
                foregroundColor: colorScheme.tertiary,
              ),
              child: Text(isEligible ? 'Claim Now' : 'Already Claimed'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(
    BuildContext context,
    UserProvider provider,
    ColorScheme colorScheme,
  ) {
    final watched = provider.userData?.watchedAdsToday ?? 0;
    final remaining = 3 - watched; // 3 ads/day max

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${remaining > 0 ? remaining : 0} Ads Remaining',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '10-15 coins per ad',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimary.withAlpha(200),
                    ),
                  ),
                ],
              ),
              Text('📺', style: const TextStyle(fontSize: 40)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: remaining > 0
                  ? () async => await AppRouter().goToWatchEarn()
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onPrimary,
                foregroundColor: colorScheme.primary,
              ),
              child: Text(remaining > 0 ? 'Watch Now' : 'Daily Limit Reached'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinCard(
    BuildContext context,
    UserProvider provider,
    ColorScheme colorScheme,
  ) {
    final spins = provider.userData?.totalSpins ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.streakColor, AppTheme.streakColor.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$spins Free Spins',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.surface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '15-25 coins per spin',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.surface.withAlpha(200),
                    ),
                  ),
                ],
              ),
              Text('🎡', style: const TextStyle(fontSize: 40)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: spins > 0
                  ? () async => await AppRouter().goToSpinWin()
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.surface,
                foregroundColor: AppTheme.streakColor,
              ),
              child: Text(spins > 0 ? 'Spin Now' : 'No Spins Left'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(50)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(40),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
