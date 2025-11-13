import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late TextEditingController _claimController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _claimController = TextEditingController();
  }

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  Future<void> _claimCode() async {
    if (_claimController.text.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter a referral code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Referral code claimed!');
        _claimController.clear();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral & Earn'),
        elevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.userData;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ========== YOUR CODE CARD ==========
                Card(
                  elevation: 0,
                  color: colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          '🎁 YOUR REFERRAL CODE',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            user.referralCode,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: user.referralCode),
                                  );
                                  SnackbarHelper.showSuccess(
                                    context,
                                    'Code copied!',
                                  );
                                },
                                icon: const Icon(Iconsax.copy),
                                label: const Text('COPY'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  SnackbarHelper.showInfo(
                                    context,
                                    'Share functionality coming soon!',
                                  );
                                },
                                icon: const Icon(Iconsax.share),
                                label: const Text('SHARE'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== REFERRAL STATS ==========
                Card(
                  elevation: 0,
                  color: colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📊 Referral Stats',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Friends',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.totalReferrals}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: colorScheme.tertiary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Earned',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${user.totalReferrals * 500}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: colorScheme.tertiary,
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

                // ========== CLAIM CODE SECTION ==========
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎁 Claim Referral Code',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _claimController,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: 'Enter code (e.g., ABC123XY)',
                                prefixIcon: const Icon(Iconsax.code),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _claimCode,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text('CLAIM CODE'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ========== INFO MESSAGE ==========
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.info_circle, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Earn ₹500 for each friend who signs up with your code!',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
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
}
