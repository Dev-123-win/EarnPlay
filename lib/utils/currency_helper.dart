import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for currency formatting

/// Helper for currency conversion and display
class CurrencyHelper {
  // Define conversion rate: 1000 coins = 1 Rupee
  static const double coinsPerRupee = 350.0; // Made public to be accessible
  static const String _currencySymbol = '₹'; // Rupee symbol

  static String convertCoinsToRealCurrency(int coins) {
    final double rupees = coins / coinsPerRupee;
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'en_IN', // Indian locale for Rupee symbol and formatting
      symbol: _currencySymbol,
      decimalDigits: 2,
    );
    return formatter.format(rupees);
  }
}

/// Helper widget to display currency with coin image and optional real-world value
class CurrencyDisplay extends StatelessWidget {
  final int coins; // Changed from String amount to int coins
  final TextStyle? textStyle;
  final double coinSize;
  final MainAxisAlignment alignment;
  final CrossAxisAlignment crossAlignment;
  final double spacing;
  final bool showRealCurrency; // New parameter to show real currency

  const CurrencyDisplay({
    super.key,
    required this.coins, // Changed to coins
    this.textStyle,
    this.coinSize = 20,
    this.alignment = MainAxisAlignment.center,
    this.crossAlignment = CrossAxisAlignment.center,
    this.spacing = 4,
    this.showRealCurrency = false, // Default to not showing real currency
  });

  @override
  Widget build(BuildContext context) {
    final String coinAmount = NumberFormat.decimalPattern().format(coins);
    final String realCurrencyAmount = CurrencyHelper.convertCoinsToRealCurrency(coins);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: crossAlignment,
      children: [
        Image.asset(
          'coin.png',
          height: coinSize,
          width: coinSize,
          fit: BoxFit.contain,
        ),
        SizedBox(width: spacing),
        Text(
          coinAmount,
          style: textStyle,
        ),
        if (showRealCurrency) ...[
          SizedBox(width: spacing / 2),
          Text(
            '($realCurrencyAmount)',
            style: textStyle?.copyWith(
              fontSize: (textStyle?.fontSize ?? 16) * 0.7, // Smaller font for real currency
              color: textStyle?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }
}

/// Helper widget for inline currency display (compact)
class InlineCurrency extends StatelessWidget {
  final int coins; // Changed from String amount to int coins
  final TextStyle? textStyle;
  final double coinSize;
  final bool showRealCurrency; // New parameter to show real currency

  const InlineCurrency({
    super.key,
    required this.coins, // Changed to coins
    this.textStyle,
    this.coinSize = 16,
    this.showRealCurrency = false, // Default to not showing real currency
  });

  @override
  Widget build(BuildContext context) {
    final String coinAmount = NumberFormat.decimalPattern().format(coins);
    final String realCurrencyAmount = CurrencyHelper.convertCoinsToRealCurrency(coins);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        Image.asset(
          'coin.png',
          height: coinSize,
          width: coinSize,
          fit: BoxFit.contain,
        ),
        Text(coinAmount, style: textStyle),
        if (showRealCurrency)
          Text(
            '($realCurrencyAmount)',
            style: textStyle?.copyWith(
              fontSize: (textStyle?.fontSize ?? 14) * 0.7, // Smaller font for real currency
              color: textStyle?.color?.withOpacity(0.7),
            ),
          ),
      ],
    );
  }
}
