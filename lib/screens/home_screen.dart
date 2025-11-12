import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/user_provider.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';

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
      context.read<UserProvider>().loadUserData(user.uid);
    }
  }

  Future<void> _handleLogout() async {
    await FirebaseService().signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _adService.disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EarnPlay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(child: const Text('Profile'), onTap: () {}),
              PopupMenuItem(onTap: _handleLogout, child: const Text('Logout')),
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
            return const Center(child: Text('Failed to load user data'));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Coin Balance Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${userProvider.userData!.coins} Coins',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Feature Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _buildFeatureCard(
                            'Daily Streak',
                            Icons.calendar_today,
                            Colors.blue,
                            () {},
                          ),
                          _buildFeatureCard(
                            'Watch & Earn',
                            Icons.play_circle,
                            Colors.green,
                            () {},
                          ),
                          _buildFeatureCard(
                            'Spin & Win',
                            Icons.casino,
                            Colors.orange,
                            () {},
                          ),
                          _buildFeatureCard(
                            'Tic-Tac-Toe',
                            Icons.grid_3x3,
                            Colors.purple,
                            () {},
                          ),
                          _buildFeatureCard(
                            'Whack-a-Mole',
                            Icons.touch_app,
                            Colors.red,
                            () {},
                          ),
                          _buildFeatureCard(
                            'Referral',
                            Icons.share,
                            Colors.teal,
                            () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Banner Ad at bottom
              if (_bannerAd != null && _adService.isBannerAdReady)
                Container(
                  width: double.infinity,
                  height: 50,
                  color: Colors.grey.shade100,
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.home), onPressed: () {}),
            IconButton(icon: const Icon(Icons.person), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
