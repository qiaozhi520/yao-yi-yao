import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LotteryInputSection extends StatelessWidget {
  const LotteryInputSection({
    super.key,
    required this.primaryController,
    required this.secondaryController,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.enabled,
    required this.inputFormatters,
  });

  final TextEditingController primaryController;
  final TextEditingController secondaryController;
  final String primaryLabel;
  final String secondaryLabel;
  final bool enabled;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: primaryController,
          enabled: enabled,
          inputFormatters: inputFormatters,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: primaryLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: secondaryController,
          enabled: enabled,
          inputFormatters: inputFormatters,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: secondaryLabel,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
