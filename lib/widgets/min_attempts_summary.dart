import 'package:flutter/material.dart';

class MinAttemptsSummary extends StatelessWidget {
  const MinAttemptsSummary({super.key, this.latestAttempts});

  final int? latestAttempts;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Text(
              '历史最小命中次数',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(latestAttempts == null ? '暂无记录' : '最小次数：$latestAttempts'),
          ],
        ),
      ),
    );
  }
}
