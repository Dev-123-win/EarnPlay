import 'package:flutter/material.dart';

class EmptyStateScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String actionText;
  final IconData icon;

  const EmptyStateScreen({
    super.key,
    required this.title,
    required this.message,
    this.onAction,
    this.actionText = 'Get Started',
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onAction != null)
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText),
              ),
          ],
        ),
      ),
    );
  }
}

// No Games Yet
class NoGamesEmptyState extends StatelessWidget {
  final VoidCallback? onGetStarted;

  const NoGamesEmptyState({super.key, this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      title: 'No Games Played Yet',
      message: 'Start playing games to earn coins and climb the leaderboard!',
      icon: Icons.sports_esports,
      actionText: 'Play Now',
      onAction: onGetStarted,
    );
  }
}

// No Coins
class NoCoinsEmptyState extends StatelessWidget {
  final VoidCallback? onEarn;

  const NoCoinsEmptyState({super.key, this.onEarn});

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      title: 'No Coins Yet',
      message:
          'Watch ads, play games, and earn coins to start earning real money!',
      icon: Icons.monetization_on,
      actionText: 'Start Earning',
      onAction: onEarn,
    );
  }
}

// No Friends
class NoFriendsEmptyState extends StatelessWidget {
  final VoidCallback? onInvite;

  const NoFriendsEmptyState({super.key, this.onInvite});

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      title: 'No Friends Yet',
      message: 'Invite friends using your referral code and earn bonus coins!',
      icon: Icons.people_outline,
      actionText: 'Invite Friends',
      onAction: onInvite,
    );
  }
}

// No Notifications
class NoNotificationsEmptyState extends StatelessWidget {
  const NoNotificationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      title: 'No Notifications',
      message: 'You\'re all caught up! Check back later for new updates.',
      icon: Icons.notifications_off_outlined,
    );
  }
}

// No History
class NoHistoryEmptyState extends StatelessWidget {
  final VoidCallback? onExplore;

  const NoHistoryEmptyState({super.key, this.onExplore});

  @override
  Widget build(BuildContext context) {
    return EmptyStateScreen(
      title: 'No History',
      message: 'Your activity history will appear here after you play games.',
      icon: Icons.history,
      actionText: 'Explore Games',
      onAction: onExplore,
    );
  }
}
