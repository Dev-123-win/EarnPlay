import 'package:flutter/material.dart';

/// Helper widget to display currency with coin image
class CurrencyDisplay extends StatelessWidget {
  final String amount;
  final TextStyle? textStyle;
  final double coinSize;
  final MainAxisAlignment alignment;
  final CrossAxisAlignment crossAlignment;
  final double spacing;

  const CurrencyDisplay({
    super.key,
    required this.amount,
    this.textStyle,
    this.coinSize = 20,
    this.alignment = MainAxisAlignment.center,
    this.crossAlignment = CrossAxisAlignment.center,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
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
        Text(amount, style: textStyle),
      ],
    );
  }
}

/// Helper widget for inline currency display (compact)
class InlineCurrency extends StatelessWidget {
  final String amount;
  final TextStyle? textStyle;
  final double coinSize;

  const InlineCurrency({
    super.key,
    required this.amount,
    this.textStyle,
    this.coinSize = 16,
  });

  @override
  Widget build(BuildContext context) {
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
        Text(amount, style: textStyle),
      ],
    );
  }
}
