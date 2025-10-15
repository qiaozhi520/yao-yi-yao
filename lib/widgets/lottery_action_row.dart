import 'package:flutter/material.dart';

class LotteryActionRow extends StatelessWidget {
  const LotteryActionRow({
    super.key,
    required this.isRunning,
    required this.onFillRandom,
    required this.onAuto100,
    required this.onAutoConcurrent100,
    required this.onStart,
    required this.onStop,
  });

  final bool isRunning;
  final VoidCallback onFillRandom;
  final VoidCallback onAuto100;
  final VoidCallback onAutoConcurrent100;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isRunning ? null : onFillRandom,
            icon: const Icon(Icons.shuffle),
            label: const Text('随机填充'),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: isRunning ? null : onAuto100,
          child: const Text('自动100组'),
        ),
        const SizedBox(width: 4),
        OutlinedButton(
          onPressed: isRunning ? null : onAutoConcurrent100,
          child: const Text('并发自动100组(4)'),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: isRunning
              ? OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: const Text('取消模拟'),
                )
              : ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始模拟'),
                ),
        ),
      ],
    );
  }
}
