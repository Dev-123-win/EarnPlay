import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../services/firebase_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final userProvider = context.read<UserProvider>();
                await FirebaseService().signOut();
                userProvider.clearUserData();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), elevation: 0),
      body: Consumer2<UserProvider, GameProvider>(
        builder: (context, userProvider, gameProvider, _) {
          final user = userProvider.userData;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // User Info Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.purple.shade100,
                          child: Icon(
                            Icons.person,
                            size: 48,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.email,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        // Coins Display
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${user.coins} coins',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Statistics Section
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatRow(
                          icon: Icons.calendar_today,
                          label: 'Daily Streak',
                          value: '${user.dailyStreak.currentStreak} days',
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          icon: Icons.video_library,
                          label: 'Ads Watched Today',
                          value: '${user.watchedAdsToday}',
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          icon: Icons.casino,
                          label: 'Spins Remaining',
                          value: '${user.spinsRemaining}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Game Statistics
                Text(
                  'Game Statistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatRow(
                          icon: Icons.sports_esports,
                          label: 'Tic Tac Toe Wins',
                          value: '${gameProvider.tictactoeWins}',
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          icon: Icons.sports_esports,
                          label: 'Tic Tac Toe Losses',
                          value: '${gameProvider.tictactoeLosses}',
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          icon: Icons.pest_control,
                          label: 'Whack Mole High Score',
                          value: '${gameProvider.whackMoleHighScore}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Account Section
                Text('Account', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Member since ${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
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
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.purple),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
