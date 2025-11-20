import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../utils/currency_helper.dart';

// ignore_for_file: deprecated_member_use

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  late TextEditingController _upiController;
  late TextEditingController _amountController;
  String _selectedMethod = 'upi';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _upiController = TextEditingController();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal(UserProvider userProvider) async {
    if (_amountController.text.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter withdrawal amount');
      return;
    }

    if (_selectedMethod == 'upi' && _upiController.text.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter UPI ID');
      return;
    }

    final amount = int.tryParse(_amountController.text) ?? 0;
    final user = userProvider.userData;

    if (amount < 500) {
      SnackbarHelper.showError(context, 'Minimum withdrawal is 500');
      return;
    }

    if (user != null && amount > user.coins) {
      SnackbarHelper.showError(context, 'Insufficient balance');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Call UserProvider to process withdrawal via Worker
      await userProvider.requestWithdrawal(
        amount: amount,
        method: _selectedMethod.toUpperCase(),
        paymentId: _upiController.text.trim(),
      );

      if (mounted) {
        DialogSystem.showWithdrawalDialog(
          context,
          status: 'Pending',
          amount: '$amount',
          message:
              'Your withdrawal request has been submitted. Balance debited instantly. Payout is processed within 24-72 hours. You can track the status in Withdrawal History. Contact support if not received.',
          onClose: () {
            _amountController.clear();
            _upiController.clear();
          },
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Earnings'),
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
                // ========== BALANCE CARD WITH CONVERSION RATE ==========
                Card(
                  elevation: 0,
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Available Balance',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer.withAlpha(
                                  178,
                                ),
                              ),
                        ),
                        const SizedBox(height: 8),
                        CurrencyDisplay(
                          coins: user.coins,
                          coinSize: 28,
                          spacing: 8,
                          textStyle: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                          showRealCurrency: true,
                        ),
                        const SizedBox(height: 16),
                        // Conversion rate clearly explained
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.primary.withAlpha(50),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${CurrencyHelper.coinsPerRupee.toInt()} coins',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '=',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: colorScheme.primary),
                                  ),
                                  Text(
                                    CurrencyHelper.convertCoinsToRealCurrency(
                                      CurrencyHelper.coinsPerRupee.toInt(),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You have ${CurrencyHelper.convertCoinsToRealCurrency(user.coins)}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer
                                          .withAlpha(150),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Min. withdrawal: 500 coins (${CurrencyHelper.convertCoinsToRealCurrency(500)})',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== WITHDRAWAL FORM ==========
                Text(
                  'Enter Withdrawal Details',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount Field with validation
                        Text(
                          'Withdrawal Amount (coins)',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amountController,
                          enabled: !_isProcessing,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'Min. 500 coins',
                            prefixIcon: const Icon(Iconsax.coin),
                            suffixText: _amountController.text.isNotEmpty
                                ? '(${CurrencyHelper.convertCoinsToRealCurrency(int.tryParse(_amountController.text) ?? 0)})'
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 20),

                        // Payment Method Selection
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 12),

                        // UPI Option
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedMethod == 'upi'
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Radio.adaptive(
                                value: 'upi',
                                groupValue: _selectedMethod,
                                onChanged: _isProcessing
                                    ? null
                                    : (String? value) {
                                        if (value != null) {
                                          setState(
                                            () => _selectedMethod = value,
                                          );
                                        }
                                      },
                              ),
                              Icon(Iconsax.mobile, color: colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('UPI'),
                                    Text(
                                      'Google Pay, PhonePe, Paytm',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bank Transfer Option - Disabled with "Coming Soon"
                        Opacity(
                          opacity: 0.6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.outline,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Radio.adaptive(
                                  value: 'bank',
                                  groupValue: _selectedMethod,
                                  onChanged: null,
                                ),
                                Icon(Iconsax.bank, color: colorScheme.outline),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Bank Transfer'),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.outlineVariant
                                                  .withAlpha(100),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Coming Soon',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Text(
                                        'Direct to bank account',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // UPI ID Field (conditional)
                        if (_selectedMethod == 'upi') ...[
                          Text(
                            'UPI ID',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _upiController,
                            enabled: !_isProcessing,
                            decoration: InputDecoration(
                              hintText: 'yourname@upi',
                              prefixIcon: const Icon(Iconsax.sms),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Bank Details Placeholder
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Bank details form coming soon',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ========== SUBMIT BUTTON ==========
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _submitWithdrawal(userProvider),
                    icon: const Icon(Iconsax.send_1),
                    label: const Text('REQUEST WITHDRAWAL'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ========== PROCESSING TIME - PROMINENT ==========
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.errorContainer,
                        colorScheme.errorContainer.withAlpha(180),
                      ],
                    ),
                    border: Border.all(
                      color: colorScheme.error.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.clock,
                            color: colorScheme.error,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Processing Time',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: colorScheme.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Balance debited instantly. Payout processed within 24-72 hours.',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // View withdrawal history
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      final uid = userProvider.userData?.uid;
                      if (uid == null) return;
                      Navigator.of(context)
                          .pushNamed('/withdrawal-history', arguments: uid);
                    },
                    child: const Text('View Withdrawal History'),
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
