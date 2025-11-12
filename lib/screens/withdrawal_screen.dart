import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  static const int minimumWithdrawal = 100;
  static const Map<String, double> exchangeRates = {
    'UPI': 1.0,
    'Bank Transfer': 1.0,
    'PayPal': 1.1,
  };

  String selectedMethod = 'UPI';
  final TextEditingController amountController = TextEditingController();
  final TextEditingController paymentIdController = TextEditingController();
  bool isProcessing = false;

  @override
  void dispose() {
    amountController.dispose();
    paymentIdController.dispose();
    super.dispose();
  }

  double get selectedExchangeRate => exchangeRates[selectedMethod] ?? 1.0;

  Future<void> _processWithdrawal(UserProvider userProvider) async {
    final amount = int.tryParse(amountController.text);
    final paymentId = paymentIdController.text;

    if (amount == null || amount < minimumWithdrawal) {
      _showError('Minimum withdrawal is $minimumWithdrawal coins');
      return;
    }

    if (paymentId.isEmpty) {
      _showError('Please enter your $selectedMethod ID');
      return;
    }

    final userCoins = userProvider.userData?.coins ?? 0;
    if (amount > userCoins) {
      _showError('Insufficient coins');
      return;
    }

    setState(() => isProcessing = true);

    try {
      // Show processing dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Processing Withdrawal...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Amount: $amount coins'),
                Text('Method: $selectedMethod'),
              ],
            ),
          ),
        );
      }

      // Simulate processing
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.pop(context);
      }

      // Deduct coins
      try {
        await userProvider.updateCoins(-amount);
        if (mounted && userProvider.userData?.uid != null) {
          await userProvider.loadUserData(userProvider.userData!.uid);
        }
      } catch (e) {
        debugPrint('Error updating coins: $e');
      }

      if (mounted) {
        amountController.clear();
        paymentIdController.clear();
        _showSuccess(
          'Withdrawal request submitted! You\'ll receive $amount coins in 1-2 business days.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error processing withdrawal: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal'),
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
          final userCoins = userProvider.userData?.coins ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Available Balance
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Available Balance'),
                        const SizedBox(height: 12),
                        Text(
                          '$userCoins coins',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info Box
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(height: 8),
                        Text(
                          'Minimum withdrawal is 100 coins',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Withdrawals are processed within 1-2 business days',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Withdrawal Amount
                Text(
                  'Withdrawal Amount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Enter amount in coins',
                    prefixIcon: const Icon(Icons.monetization_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Method
                Text(
                  'Payment Method',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String>(
                      value: selectedMethod,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: exchangeRates.keys
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedMethod = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment ID Input
                Text(
                  '$selectedMethod ID',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paymentIdController,
                  decoration: InputDecoration(
                    hintText: selectedMethod == 'UPI'
                        ? 'Enter your UPI ID (name@bank)'
                        : selectedMethod == 'Bank Transfer'
                        ? 'Enter your Bank Account Number'
                        : 'Enter your PayPal Email',
                    prefixIcon: Icon(_getPaymentIcon()),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Summary
                Card(
                  color: Colors.purple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Amount:'),
                            Text(
                              '${amountController.text.isEmpty ? '0' : amountController.text} coins',
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Exchange Rate:'),
                            Text(
                              '1:${selectedExchangeRate.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isProcessing || userCoins < minimumWithdrawal
                        ? null
                        : () => _processWithdrawal(userProvider),
                    icon: const Icon(Icons.send),
                    label: const Text('Request Withdrawal'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Help Text
                Text(
                  'Please ensure all details are correct before submitting.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getPaymentIcon() {
    switch (selectedMethod) {
      case 'UPI':
        return Icons.qr_code;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'PayPal':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }
}
