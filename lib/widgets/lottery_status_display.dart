import 'package:flutter/material.dart';

class LotteryStatusDisplay extends StatelessWidget {
  const LotteryStatusDisplay({
    super.key,
    this.errorMessage,
    this.statusMessage,
    this.resultMessage,
    this.attempts,
  });

  final String? errorMessage;
  final String? statusMessage;
  final String? resultMessage;
  final int? attempts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errorMessage != null)
          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
        if (statusMessage != null)
          Text(statusMessage!, style: const TextStyle(color: Colors.blueGrey)),
        if (resultMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              resultMessage!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        if (attempts != null && attempts! > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('已完成尝试次数：$attempts'),
          ),
      ],
    );
  }
}
