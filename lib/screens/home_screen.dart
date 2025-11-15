import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../utils/dialog_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AdService _adService;
  BannerAd? _bannerAd;
  int _selectedTab = 0;
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

  Future<void> _handleLogout() async {
    final confirm = await DialogSystem.showConfirmationDialog(
      context,
      title: 'Logout?',
      subtitle: 'Are you sure you want to logout?',
      confirmText: 'Yes, Logout',
      cancelText: 'Cancel',
      isDangerous: true,
    );

    if (confirm == true && mounted) {
      await FirebaseService().signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
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
      appBar: AppBar(
        elevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(
          'EarnPlay',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Iconsax.notification), onPressed: () {}),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Iconsax.user),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
                onTap: () => Navigator.of(context).pushNamed('/profile'),
              ),
              PopupMenuItem(
                onTap: _handleLogout,
                child: const Row(
                  children: [
                    Icon(Iconsax.logout),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ========== BALANCE CARD ==========
                      Card(
                        elevation: 0,
                        color: colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primary.withAlpha(51),
                                ),
                                child: Icon(
                                  Iconsax.coin_1,
                                  size: 32,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Balance',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '₹${userProvider.userData!.coins}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/withdrawal');
                                },
                                icon: const Icon(Iconsax.wallet_2),
                                label: const Text('Withdraw'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ========== QUICK STATS ==========
                      Column(
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
                                  value:
                                      '${userProvider.userData!.totalGamesWon}',
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
                                  value:
                                      '${userProvider.userData!.totalReferrals}',
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
                        ],
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
                                        'Earn ₹500/friend',
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
              if (_bannerAd != null && _adService.isBannerAdReady)
                Container(
                  width: double.infinity,
                  height: 50,
                  color: colorScheme.surfaceDim,
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          setState(() => _selectedTab = index);
          switch (index) {
            case 0:
              break; // Already on home
            case 1:
              Navigator.of(context).pushNamed('/daily_streak');
              break;
            case 2:
              Navigator.of(context).pushNamed('/watch_earn');
              break;
            case 3:
              Navigator.of(context).pushNamed('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Iconsax.home_1), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.activity),
            label: 'Streak',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.play_circle),
            label: 'Earn',
          ),
          BottomNavigationBarItem(icon: Icon(Iconsax.user), label: 'Profile'),
        ],
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
