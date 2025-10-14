import 'package:flutter/material.dart';
import '../model/number_item.dart';
import 'circle_value_badge.dart';

class NumberItemsList extends StatelessWidget {
  const NumberItemsList({
    super.key,
    required this.items,
    this.spacing = 12.0,
  });

  final List<NumberItem> items;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            CircleValueBadge(
              value: int.parse(items[i].value),
              color: items[i].color,
            ),
            if (i < items.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}
