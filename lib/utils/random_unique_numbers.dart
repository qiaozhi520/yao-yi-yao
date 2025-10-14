import 'dart:math';
import 'dart:ui';

import '../model/number_item.dart';

/// Returns `count` unique integers within `[start, end]` inclusive.
List<int> generateUniqueNumbersInRange({
  required int start,
  required int end,
  required int count,
}) {
  if (start > end) {
    throw ArgumentError('start must be <= end');
  }

  final available = end - start + 1;
  if (count < 0 || count > available) {
    throw ArgumentError('count must be between 0 and $available');
  }

  final numbers = List<int>.generate(available, (index) => start + index);
  final random = Random();

  // Fisher-Yates shuffle for the first `count` elements
  for (var i = 0; i < count; i++) {
    final j = i + random.nextInt(available - i);
    final temp = numbers[i];
    numbers[i] = numbers[j];
    numbers[j] = temp;
  }

  return numbers.sublist(0, count);
}

/// Produces a list of NumberItems pairing zero-padded numbers with a shared `color`.
List<NumberItem> formatNumbersWithColor({
  required List<int> values,
  required Color color,
  required int maxDigits,
}) {
  if (maxDigits <= 0) {
    throw ArgumentError('maxDigits must be greater than 0');
  }

  // Sort values in ascending order
  final sortedValues = List<int>.from(values)..sort();

  return sortedValues.map((value) {
    final rawString = value.toString();
    if (rawString.length > maxDigits) {
      throw ArgumentError('Value $value exceeds maxDigits $maxDigits');
    }

    final numberString = rawString.padLeft(maxDigits, '0');
    return NumberItem(
      value: numberString,
      color: color,
    );
  }).toList();
}
