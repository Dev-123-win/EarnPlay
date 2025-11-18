import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../utils/currency_helper.dart';
import '../widgets/custom_app_bar.dart'; // Import CustomAppBar

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
      await context.read<UserProvider>().processReferral(
        _claimController.text.trim(),
      );
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Referral code claimed! You earned 50',
        );
        _claimController.clear();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: ${e.toString()}');
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
      appBar: const CustomAppBar(
        title: 'Referral & Earn',
        showBackButton: true,
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
                          'Your Referral Code',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colorScheme.onSecondaryContainer
                                    .withAlpha(180),
                              ),
                        ),
                        const SizedBox(height: 16),
                        // Lightweight code display
                        Column(
                          children: [
                            Text(
                              user.referralCode,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: colorScheme.secondary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Share this code with friends',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSecondaryContainer
                                        .withAlpha(150),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Single Copy button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: user.referralCode),
                              );
                              SnackbarHelper.showSuccess(
                                context,
                                'Code copied to clipboard!',
                              );
                            },
                            icon: const Icon(Iconsax.copy),
                            label: const Text('Copy Code'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== REFERRAL STATS ==========
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.tertiaryContainer,
                        colorScheme.tertiaryContainer.withAlpha(153),
                      ],
                    ),
                    border: Border.all(
                      color: colorScheme.tertiary.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Show stats or encouragement based on referrals
                      if (user.totalReferrals > 0)
                        Column(
                          children: [
                            Text(
                              'Referral Stats',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colorScheme.onTertiaryContainer
                                        .withAlpha(180),
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      'Friends',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme
                                                .onTertiaryContainer
                                                .withAlpha(150),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${user.totalReferrals}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            color: colorScheme.tertiary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'Earned',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme
                                                .onTertiaryContainer
                                                .withAlpha(150),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    CurrencyDisplay(
                                      coins: user.totalReferrals * 500,
                                      coinSize: 24,
                                      spacing: 6,
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            color: colorScheme.tertiary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                      showRealCurrency: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Icon(
                              Iconsax.people,
                              size: 48,
                              color: colorScheme.tertiary.withAlpha(150),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No referrals yet',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share your code to earn 500 per friend',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onTertiaryContainer
                                        .withAlpha(150),
                                  ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ========== CLAIM CODE SECTION ==========
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have a referral code?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Inline search-bar style
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _claimController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Enter code',
                              prefixIcon: const Icon(Iconsax.code),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _isLoading ? null : _claimCode,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Claim'),
                        ),
                      ],
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
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.info_circle,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Earn 500 per friend who joins with your code',
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
