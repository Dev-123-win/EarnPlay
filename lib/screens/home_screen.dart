import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AdService _adService;
  BannerAd? _bannerAd;

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
                    'Failed to load user data',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userProvider.error ?? 'Please try again',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      final user = FirebaseService().currentUser;
                      if (user != null) {
                        context.read<UserProvider>().loadUserData(user.uid);
                      }
                    },
                    icon: const Icon(Iconsax.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // ========== SIMPLE, CLEAN APP BAR ==========
              SliverAppBar(
                elevation: 0,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                centerTitle: true,
                title: Text(
                  'EarnPlay',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Iconsax.user),
                  onPressed: () => Navigator.of(context).pushNamed('/profile'),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Iconsax.setting_2),
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/profile'),
                  ),
                ],
              ),

              // ========== BALANCE CARD (SIMPLIFIED) ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Balance',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colorScheme.onPrimary.withAlpha(200),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CurrencyDisplay(
                                amount: '${userProvider.userData!.coins}',
                                coinSize: 32,
                                spacing: 10,
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed('/withdrawal'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.onPrimary,
                                ),
                                child: Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ========== STATS SECTION (FIXED 4-COLUMN GRID) ==========
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
                        'Your Stats',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.9,
                        children: [
                          _buildStatBox(
                            context,
                            icon: Iconsax.activity,
                            value: '${userProvider.userData!.totalGamesWon}',
                            label: 'Games',
                            color: colorScheme.primary,
                          ),
                          _buildStatBox(
                            context,
                            icon: Iconsax.play,
                            value: '${userProvider.userData!.totalAdsWatched}',
                            label: 'Ads',
                            color: colorScheme.secondary,
                          ),
                          _buildStatBox(
                            context,
                            icon: Iconsax.people,
                            value: '${userProvider.userData!.totalReferrals}',
                            label: 'Refs',
                            color: colorScheme.tertiary,
                          ),
                          _buildStatBox(
                            context,
                            icon: Iconsax.crown,
                            value:
                                '${userProvider.userData!.dailyStreak.currentStreak}',
                            label: 'Streak',
                            color: AppTheme.streakColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ========== GAMES SECTION ==========
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
                        'Play & Earn',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Daily Streak',
                            subtitle: 'Check in daily',
                            reward: 'Varies',
                            icon: Iconsax.activity,
                            color: colorScheme.tertiary,
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/daily_streak'),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Watch Ads',
                            subtitle: 'Up to 10/day',
                            reward: '50 coins/day',
                            icon: Iconsax.play_circle,
                            color: colorScheme.primary,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/watch_earn'),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Spin & Win',
                            subtitle: '3 free spins/day',
                            reward: '10-50 coins',
                            icon: Iconsax.star,
                            color: AppTheme.streakColor,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/spin_win'),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Tic Tac Toe',
                            subtitle: 'Play vs AI',
                            reward: '25 coins/win',
                            icon: Iconsax.game,
                            color: colorScheme.secondary,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/tictactoe'),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Whack-A-Mole',
                            subtitle: 'Fast reflexes',
                            reward: '50 coins/win',
                            icon: Iconsax.cpu,
                            color: const Color(0xFFFF6B9D),
                            onTap: () =>
                                Navigator.of(context).pushNamed('/whack_mole'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ========== REFERRAL & ACTION CARDS ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              context,
                              colorScheme,
                              icon: Iconsax.share,
                              title: 'Referral',
                              subtitle: 'Earn 500/friend',
                              backgroundColor: colorScheme.secondaryContainer,
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/referral'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              context,
                              colorScheme,
                              icon: Iconsax.clock,
                              title: 'History',
                              subtitle: 'View stats',
                              backgroundColor: colorScheme.tertiaryContainer,
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/game_history'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ========== BANNER AD ==========
              SliverToBoxAdapter(
                child: _bannerAd != null && _adService.isBannerAdReady
                    ? Container(
                        width: double.infinity,
                        height: 50,
                        color: Theme.of(context).colorScheme.surfaceDim,
                        child: AdWidget(ad: _bannerAd!),
                      )
                    : const SizedBox.shrink(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  /// Build stat box widget
  Widget _buildStatBox(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withAlpha(25),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color.withAlpha(150),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// Build game row widget
  Widget _buildGameRow(
    BuildContext context,
    ColorScheme colorScheme, {
    required String title,
    required String subtitle,
    required String reward,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withAlpha(12),
        border: Border.all(color: color.withAlpha(30), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(40),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.labelSmall?.color?.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: color,
                  ),
                  child: Text(
                    reward,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
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

  /// Build action card widget
  Widget _buildActionCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: backgroundColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor.withAlpha(80),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
