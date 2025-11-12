import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class DailyStreakScreen extends StatefulWidget {
  const DailyStreakScreen({super.key});

  @override
  State<DailyStreakScreen> createState() => _DailyStreakScreenState();
}

class _DailyStreakScreenState extends State<DailyStreakScreen> {
  Future<void> _claimStreak() async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.claimDailyStreak();
      await userProvider.updateCoins(10);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Streak claimed! 10 coins earned'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Streak'),
        elevation: 0,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, size: 20),
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
          final streak = userProvider.userData?.dailyStreak;
          if (streak == null) {
            return const Center(child: CircularProgressIndicator());
          }

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
                          '${streak.currentStreak}/7 Days',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: streak.currentStreak / 7,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          streak.currentStreak >= 7
                              ? '🎉 Amazing! You completed the week!'
                              : 'Keep it up! ${7 - streak.currentStreak} more days to go',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Daily Rewards',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ...List.generate(7, (index) {
                  final day = index + 1;
                  final isClaimed = index < streak.currentStreak;
                  final isToday = index == streak.currentStreak;
                  final isLocked = index > streak.currentStreak;
                  final reward = day == 7 ? 100 : 10 + (day * 5);

                  return _buildDayCard(
                    day: day,
                    reward: reward,
                    isClaimed: isClaimed,
                    isToday: isToday,
                    isLocked: isLocked,
                    onClaim: isToday ? _claimStreak : null,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCard({
    required int day,
    required int reward,
    required bool isClaimed,
    required bool isToday,
    required bool isLocked,
    required VoidCallback? onClaim,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day $day${day == 7 ? ' 🏆' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '$reward coins',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isClaimed)
                const Chip(
                  label: Text('✅ Claimed'),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                )
              else if (isToday)
                FilledButton.icon(
                  onPressed: onClaim,
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Claim'),
                )
              else if (isLocked)
                const Chip(
                  label: Text('🔒 Locked'),
                  backgroundColor: Colors.grey,
                  labelStyle: TextStyle(color: Colors.white),
                )
              else
                const Chip(
                  label: Text('Tomorrow'),
                  backgroundColor: Colors.blue,
                  labelStyle: TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
