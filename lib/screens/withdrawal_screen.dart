import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/user_provider.dart';
import '../utils/dialog_helper.dart';
import '../utils/currency_helper.dart';

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
      // Simulate withdrawal processing
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        DialogSystem.showWithdrawalDialog(
          context,
          status: 'Pending',
          amount: '$amount',
          message:
              'Your withdrawal request has been submitted.\nYou will receive the amount within 24-48 hours.',
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
                // ========== BALANCE CARD ==========
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
                          amount: '${user.coins}',
                          coinSize: 28,
                          spacing: 8,
                          textStyle: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
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
                            'Min. withdrawal: 500',
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
                        // Amount Field
                        Text(
                          'Withdrawal Amount',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amountController,
                          enabled: !_isProcessing,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            prefixIcon: const Icon(Iconsax.coin),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Payment Method Selection
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 12),

                        // UPI Option
                        InkWell(
                          onTap: _isProcessing
                              ? null
                              : () {
                                  setState(() => _selectedMethod = 'upi');
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
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
                                Icon(
                                  Iconsax.mobile,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text('UPI'),
                                      Text(
                                        'Google Pay, PhonePe, etc.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bank Transfer Option
                        InkWell(
                          onTap: _isProcessing
                              ? null
                              : () {
                                  setState(() => _selectedMethod = 'bank');
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedMethod == 'bank'
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Radio.adaptive(
                                  value: 'bank',
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
                                Icon(Iconsax.bank, color: colorScheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text('Bank Transfer'),
                                      Text(
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

                // ========== INFO BOX ==========
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.info_circle,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Processing Time',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.tertiary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  '24-48 hours',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ========== RECENT WITHDRAWALS ==========
                Text(
                  'Recent Withdrawals',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildWithdrawalItem(
                          context,
                          amount: '500',
                          method: 'UPI (yourname@upi)',
                          date: '12 Jan 2025',
                          status: 'Completed',
                          statusColor: colorScheme.tertiary,
                        ),
                        const SizedBox(height: 12),
                        Divider(color: colorScheme.outline.withAlpha(77)),
                        const SizedBox(height: 12),
                        _buildWithdrawalItem(
                          context,
                          amount: '1000',
                          method: 'UPI (yourname@upi)',
                          date: '05 Jan 2025',
                          status: 'Completed',
                          statusColor: colorScheme.tertiary,
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

  Widget _buildWithdrawalItem(
    BuildContext context, {
    required String amount,
    required String method,
    required String date,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              amount,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(method, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(date, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(51),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
