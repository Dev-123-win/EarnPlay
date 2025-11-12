import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  void _copyReferralCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Referral code copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareReferralCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Referral Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your friends:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'They\'ll earn 25 coins when they sign up with your code!',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              _copyReferralCode(context, code);
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Program'),
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
          final referralCode = userProvider.userData?.referralCode ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // How It Works
                Text(
                  'How It Works',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildHowItWorksStep(
                          number: 1,
                          title: 'Share Your Code',
                          description:
                              'Share your unique referral code with friends',
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildHowItWorksStep(
                          number: 2,
                          title: 'They Sign Up',
                          description:
                              'Your friends sign up using your referral code',
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildHowItWorksStep(
                          number: 3,
                          title: 'Earn Rewards',
                          description:
                              'You both earn 25 coins when they sign up',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Your Referral Code
                Text(
                  'Your Referral Code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple, width: 2),
                          ),
                          child: SelectableText(
                            referralCode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _copyReferralCode(context, referralCode),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _shareReferralCode(context, referralCode),
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Referral History
                Text(
                  'Your Referrals',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                const Text('Total Referrals'),
                                Text(
                                  '0',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ],
                            ),
                            Container(width: 1, height: 60, color: Colors.grey),
                            Column(
                              children: [
                                const Text('Earnings'),
                                Text(
                                  '0 coins',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: Colors.orange),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Referral history coming soon!',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Bonus Info
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          'Unlimited Earnings',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'There\'s no limit to how many friends you can refer. Keep sharing and earning!',
                          textAlign: TextAlign.center,
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

  Widget _buildHowItWorksStep({
    required int number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.purple,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
