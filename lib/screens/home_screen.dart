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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AdService _adService;
  BannerAd? _bannerAd;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      // Load game stats after user data loads
      if (mounted) {
        await context.read<GameProvider>().loadGameStats(user.uid);
      }
    }
  }

  @override
  void dispose() {
    _adService.disposeBannerAd();
    _tabController.dispose();
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
              // ========== REDESIGNED SLIVER APP BAR WITH ENHANCED VISUAL HIERARCHY ==========
              SliverAppBar(
                expandedHeight: 140,
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
                          colorScheme.secondary.withAlpha(220),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(100),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Background shimmer effect
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.onPrimary.withAlpha(15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.onPrimary.withAlpha(30),
                                border: Border.all(
                                  color: colorScheme.onPrimary.withAlpha(50),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '💰',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'EarnPlay',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: colorScheme.onPrimary,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                          fontSize: 24,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Play & Earn Daily',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onPrimary
                                              .withAlpha(180),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                          letterSpacing: 0.3,
                                        ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  centerTitle: false,
                  collapseMode: CollapseMode.parallax,
                ),
                actions: [
                  // Coin display in AppBar
                  Consumer<UserProvider>(
                    builder: (context, userProvider, _) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withAlpha(28),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.onPrimary.withAlpha(60),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFD700),
                              ),
                              child: Icon(
                                Iconsax.coin_1,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${userProvider.userData?.coins ?? 0}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Notification button
                  Container(
                    margin: const EdgeInsets.only(
                      right: 8,
                      top: 10,
                      bottom: 10,
                    ),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Iconsax.notification,
                            color: colorScheme.onPrimary,
                            size: 24,
                          ),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 6,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.error,
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.error.withAlpha(100),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile button
                  Container(
                    margin: const EdgeInsets.only(
                      right: 12,
                      top: 10,
                      bottom: 10,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.onPrimary.withAlpha(20),
                      border: Border.all(
                        color: colorScheme.onPrimary.withAlpha(50),
                        width: 1.2,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Iconsax.user,
                        color: colorScheme.onPrimary,
                        size: 22,
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/profile'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ),

              // ========== REDESIGNED BALANCE CARD WITH ENHANCED VISUAL HIERARCHY ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withAlpha(210),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(120),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== HEADER SECTION WITH ENHANCED VISUAL HIERARCHY =====
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorScheme.onPrimary.withAlpha(
                                        32,
                                      ),
                                      border: Border.all(
                                        color: colorScheme.onPrimary.withAlpha(
                                          80,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Iconsax.coin_1,
                                      size: 26,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your Balance',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: colorScheme.onPrimary
                                                  .withAlpha(220),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total Earnings',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: colorScheme.onPrimary
                                                  .withAlpha(140),
                                              fontWeight: FontWeight.w400,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.onPrimary.withAlpha(32),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: colorScheme.onPrimary.withAlpha(80),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '⭐',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Premium',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // ===== MAIN BALANCE DISPLAY - PRIMARY HIERARCHY ELEMENT =====
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorScheme.onPrimary.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.onPrimary.withAlpha(40),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Balance',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onPrimary.withAlpha(
                                          180,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: CurrencyDisplay(
                                      amount: '${userProvider.userData!.coins}',
                                      coinSize: 48,
                                      spacing: 14,
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 42,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ===== ACTION BUTTONS WITH ENHANCED STYLING =====
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onPrimary.withAlpha(24),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorScheme.onPrimary.withAlpha(
                                        60,
                                      ),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Navigator.of(
                                        context,
                                      ).pushNamed('/withdrawal'),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Iconsax.arrow_up_1,
                                            size: 20,
                                            color: colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Withdraw',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: colorScheme.onPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: colorScheme.onPrimary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.onPrimary.withAlpha(
                                          120,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Navigator.of(
                                        context,
                                      ).pushNamed('/withdrawal'),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Iconsax.add_circle,
                                            size: 20,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Add Fund',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
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

              // ========== REMAINING CONTENT (SliverToBoxAdapter) ==========
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ Quick Stats',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatChip(
                              icon: Iconsax.activity,
                              label: 'Games',
                              value: '${userProvider.userData!.totalGamesWon}',
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatChip(
                              icon: Iconsax.play,
                              label: 'Ads',
                              value:
                                  '${userProvider.userData!.totalAdsWatched}',
                              color: colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatChip(
                              icon: Iconsax.people,
                              label: 'Referrals',
                              value: '${userProvider.userData!.totalReferrals}',
                              color: colorScheme.tertiary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatChip(
                              icon: Iconsax.crown,
                              label: 'Streak',
                              value:
                                  '${userProvider.userData!.dailyStreak.currentStreak}',
                              color: AppTheme.streakColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ========== FEATURED GAMES ==========
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎮 Featured Games',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.0,
                            children: [
                              _buildGameCard(
                                title: 'Tic Tac Toe',
                                emoji: '⭕',
                                reward: '+25',
                                color: colorScheme.primary,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed('/tictactoe'),
                              ),
                              _buildGameCard(
                                title: 'Whack-A-Mole',
                                emoji: '🔨',
                                reward: '+50',
                                color: colorScheme.secondary,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed('/whack_mole'),
                              ),
                              _buildGameCard(
                                title: 'Daily Streak',
                                emoji: '🔥',
                                reward: '+10',
                                color: colorScheme.tertiary,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed('/daily_streak'),
                              ),
                              _buildGameCard(
                                title: 'Spin & Win',
                                emoji: '🎡',
                                reward: '+?',
                                color: AppTheme.streakColor,
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed('/spin_win'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ========== REFERRAL & WITHDRAWAL CARDS ==========
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 0,
                              color: colorScheme.secondaryContainer,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed('/referral'),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colorScheme.secondary
                                              .withAlpha(51),
                                        ),
                                        child: Icon(
                                          Iconsax.share,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Referral',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Earn 500/friend',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              elevation: 0,
                              color: colorScheme.tertiaryContainer,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.of(
                                  context,
                                ).pushNamed('/watch_earn'),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colorScheme.tertiary.withAlpha(
                                            51,
                                          ),
                                        ),
                                        child: Icon(
                                          Iconsax.play_circle,
                                          color: colorScheme.tertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Watch Ads',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Earn ₹10/ad',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
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
                        color: colorScheme.surfaceDim,
                        child: AdWidget(ad: _bannerAd!),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build stat chip widget
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
      backgroundColor: color.withAlpha(26),
      side: BorderSide.none,
    );
  }

  /// Build game card widget
  Widget _buildGameCard({
    required String title,
    required String emoji,
    required String reward,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reward,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
