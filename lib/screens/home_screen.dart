import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_helper.dart';
import '../widgets/custom_app_bar.dart';

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
              // ========== CUSTOM APP BAR ==========
              SliverToBoxAdapter(
                child: CustomAppBar(
                  title: 'EarnPlay',
                  showBackButton: false, // Home screen is the root of its tab
                  actions: [
                    IconButton(
                      icon: const Icon(Iconsax.user),
                      onPressed: () {
                        // Note: Profile is accessible via bottom nav (Profile tab)
                        // No need to navigate here
                      },
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.setting_2),
                      onPressed: () {
                        // Note: Settings are in Profile tab (accessible via bottom nav)
                        // No need to navigate here
                      },
                    ),
                  ],
                ),
              ),

              // ========== BALANCE CARD (PREMIUM REDESIGN) ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Stack(
                    children: [
                      // Background gradient container
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
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
                              offset: const Offset(0, 12),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Header row: Title + Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Balance',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: colorScheme.onPrimary
                                                .withAlpha(180),
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ready to Withdraw',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onPrimary
                                                .withAlpha(120),
                                          ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.onPrimary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.onPrimary.withAlpha(
                                        60,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '💰 Active',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Main balance display
                            CurrencyDisplay(
                              coins: userProvider.userData!.coins,
                              coinSize: 36,
                              spacing: 12,
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                              showRealCurrency: true,
                            ),
                            const SizedBox(height: 20),
                            // Action buttons row
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async =>
                                        await AppRouter().goToWithdrawal(),
                                    icon: const Icon(Iconsax.arrow_right_1),
                                    label: const Text('Withdraw'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.onPrimary,
                                      foregroundColor: colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ), // Added spacing
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
                            rewardWidget: _buildRewardChip(
                              context,
                              'Varies',
                              colorScheme.tertiary,
                            ),
                            icon: Iconsax.activity,
                            color: colorScheme.tertiary,
                            onTap: () {
                              // Daily Streak is accessible via bottom nav (Streak tab)
                            },
                            boxShadow: BoxShadow(
                              color: colorScheme.tertiary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Watch Ads',
                            subtitle: 'Up to 10/day',
                            rewardWidget: _buildRewardChip(
                              context,
                              '50 coins/day',
                              colorScheme.primary,
                            ),
                            icon: Iconsax.play_circle,
                            color: colorScheme.primary,
                            onTap: () {
                              // Watch Ads is accessible via bottom nav (Earn tab)
                            },
                            boxShadow: BoxShadow(
                              color: colorScheme.primary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Spin & Win',
                            subtitle: '3 free spins/day',
                            rewardWidget: _buildRewardChip(
                              context,
                              '10-50 coins',
                              AppTheme.streakColor,
                            ),
                            icon: Iconsax.star,
                            color: AppTheme.streakColor,
                            onTap: () async => await AppRouter().goToSpinWin(),
                            boxShadow: BoxShadow(
                              color: AppTheme.streakColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.streakColor.withAlpha(12),
                                AppTheme.streakColor.withAlpha(24),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Tic Tac Toe',
                            subtitle: 'Play vs AI',
                            rewardWidget: _buildRewardChip(
                              context,
                              '25 coins/win',
                              colorScheme.secondary,
                            ),
                            icon: Iconsax.game,
                            color: colorScheme.secondary,
                            onTap: () async =>
                                await AppRouter().goToTicTacToe(),
                            boxShadow: BoxShadow(
                              color: colorScheme.secondary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildGameRow(
                            context,
                            colorScheme,
                            title: 'Whack-A-Mole',
                            subtitle: 'Fast reflexes',
                            rewardWidget: _buildRewardChip(
                              context,
                              '50 coins/win',
                              colorScheme.primaryContainer,
                            ),
                            icon: Iconsax.cpu,
                            color: colorScheme.primaryContainer,
                            onTap: () async =>
                                await AppRouter().goToWhackMole(),
                            boxShadow: BoxShadow(
                              color: colorScheme.primaryContainer.withOpacity(
                                0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ), // Added spacing
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
                      SizedBox(
                        height: 120, // Fixed height for horizontal scroll
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildStatBox(
                              context,
                              icon: Iconsax.activity,
                              value: '${userProvider.userData!.totalGamesWon}',
                              label: 'Games Won',
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatBox(
                              context,
                              icon: Iconsax.play,
                              value:
                                  '${userProvider.userData!.totalAdsWatched}',
                              label: 'Ads Watched',
                              color: colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatBox(
                              context,
                              icon: Iconsax.people,
                              value: '${userProvider.userData!.totalReferrals}',
                              label: 'Referrals',
                              color: colorScheme.tertiary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatBox(
                              context,
                              icon: Iconsax.crown,
                              value:
                                  '${userProvider.userData!.dailyStreak.currentStreak}',
                              label: 'Daily Streak',
                              color: AppTheme.streakColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ), // Added spacing
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
                              onTap: () async =>
                                  await AppRouter().goToReferral(),
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
                              onTap: () async =>
                                  await AppRouter().goToGameHistory(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ), // Added spacing
              // ========== BANNER AD ==========
              SliverToBoxAdapter(
                child: _bannerAd != null && _adService.isBannerAdReady
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Container(
                          width: double.infinity,
                          height:
                              60, // Slightly increased height for better visibility
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AdWidget(ad: _bannerAd!),
                        ),
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
      width: 120, // Fixed width for horizontal scroll
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withAlpha(25),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color.withAlpha(180)),
            ),
          ],
        ),
      ),
    );
  }

  /// Build game row widget
  Widget _buildGameRow(
    BuildContext context,
    ColorScheme colorScheme, {
    required String title,
    required String subtitle,
    required Widget rewardWidget, // Changed to Widget
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    BoxShadow? boxShadow,
    Gradient? gradient, // Added gradient parameter
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: gradient == null ? color.withAlpha(12) : null,
        gradient: gradient,
        border: Border.all(color: color.withAlpha(30), width: 1),
        boxShadow: boxShadow != null ? [boxShadow] : null,
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
                rewardWidget, // Use the rewardWidget here
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

  /// Build reward chip widget
  Widget _buildRewardChip(BuildContext context, String reward, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color,
      ),
      child: Text(
        reward,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
