import 'package:flutter/services.dart';

import '../models/perc_amount.dart';

/// Limits PERC amount entry to non-negative values with at most 8 decimal places.
class PercAmountInputFormatter extends TextInputFormatter {
  const PercAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final pattern = RegExp(
      r'^\d{0,16}(?:\.\d{0,' + '${PercAmount.decimals}' + r'})?$',
    );
    if (pattern.hasMatch(text)) return newValue;
    return oldValue;
  }
}