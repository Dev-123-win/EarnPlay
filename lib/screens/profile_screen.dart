import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../services/firebase_service.dart';
import '../utils/dialog_helper.dart';
import '../utils/currency_helper.dart';
import '../widgets/custom_app_bar.dart'; // Import CustomAppBar
import 'auth/login_screen.dart'; // Added import for LoginScreen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  Future<void> _logout(BuildContext context) async {
    final confirm = await DialogSystem.showConfirmationDialog(
      context,
      title: 'Logout?',
      subtitle: 'Are you sure you want to logout?',
      confirmText: 'Yes, Logout',
      cancelText: 'Cancel',
      isDangerous: true,
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseService().signOut();
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        SnackbarHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Profile',
        showBackButton: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.userData;

          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.warning_2, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ========== PROFILE HEADER ==========
                Card(
                  elevation: 0,
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withAlpha(51),
                          ),
                          child: Icon(
                            Iconsax.user,
                            size: 56,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Name
                        Text(
                          user.displayName.isEmpty ? 'User' : user.displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        // Email
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer.withAlpha(
                                  178,
                                ),
                              ),
                        ),
                        const SizedBox(height: 4),
                        // Member Since
                        Text(
                          'Member since ${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== EARNINGS SUMMARY ==========
                Card(
                  elevation: 0,
                  color: colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💰 Earnings Summary',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Total',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                CurrencyDisplay(
                                  coins: user.coins,
                                  coinSize: 20,
                                  spacing: 4,
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  showRealCurrency: true,
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Games',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.totalGamesWon}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Ads',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.totalAdsWatched}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== QUICK STATS ==========
                Text(
                  '📊 Lifetime Stats',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatRow(
                          icon: Iconsax.activity,
                          label: 'Games Won',
                          value: '${user.totalGamesWon}',
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Divider(color: colorScheme.outline.withAlpha(77)),
                        const SizedBox(height: 12),
                        _buildStatRow(
                          icon: Iconsax.play_circle,
                          label: 'Ads Watched',
                          value: '${user.totalAdsWatched}',
                          color: colorScheme.tertiary,
                        ),
                        const SizedBox(height: 12),
                        Divider(color: colorScheme.outline.withAlpha(77)),
                        const SizedBox(height: 12),
                        _buildStatRow(
                          icon: Iconsax.people,
                          label: 'Referrals',
                          value: '${user.totalReferrals}',
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(height: 12),
                        Divider(color: colorScheme.outline.withAlpha(77)),
                        const SizedBox(height: 12),
                        _buildStatRow(
                          icon: Iconsax.activity,
                          label: 'Total Spins',
                          value: '${user.totalSpins}',
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== SETTINGS ==========
                Text(
                  '⚙️ Settings',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Iconsax.notification,
                          color: colorScheme.primary,
                        ),
                        title: const Text('Notifications'),
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                          },
                          activeThumbColor: colorScheme.primary,
                        ),
                      ),
                      Divider(
                        color: colorScheme.outline.withAlpha(77),
                        height: 1,
                        indent: 56,
                      ),
                      ListTile(
                        leading: Icon(
                          Iconsax.volume_high,
                          color: colorScheme.primary,
                        ),
                        title: const Text('Sound Effects'),
                        trailing: Switch(
                          value: _soundEnabled,
                          onChanged: (value) {
                            setState(() => _soundEnabled = value);
                          },
                          activeThumbColor: colorScheme.primary,
                        ),
                      ),
                      Divider(
                        color: colorScheme.outline.withAlpha(77),
                        height: 1,
                        indent: 56,
                      ),
                      ListTile(
                        leading: Icon(
                          Iconsax.global,
                          color: colorScheme.primary,
                        ),
                        title: const Text('Language'),
                        trailing: const Text('English'),
                        onTap: () {},
                      ),
                      Divider(
                        color: colorScheme.outline.withAlpha(77),
                        height: 1,
                        indent: 56,
                      ),
                      ListTile(
                        leading: Icon(
                          Iconsax.info_circle,
                          color: colorScheme.primary,
                        ),
                        title: const Text('About App'),
                        trailing: const Icon(Iconsax.arrow_right),
                        onTap: () {
                          DialogSystem.showInfoDialog(
                            context,
                            title: 'About EarnPlay',
                            content:
                                'EarnPlay v1.0.0\n\nPlay games and earn real rewards!\n\n© 2025 EarnPlay. All rights reserved.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ========== LOGOUT BUTTON ==========
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Iconsax.logout),
                    label: const Text('LOGOUT'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
