import 'dart:ui';

/// Represents a formatted number with its display color.
class NumberItem {
  const NumberItem({
    required this.value,
    required this.color,
  });

  /// The zero-padded number string.
  final String value;

  /// The color to display this number with.
  final Color color;

  @override
  String toString() => 'NumberItem(value: $value, color: $color)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NumberItem &&
        other.value == value &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(value, color);
}
