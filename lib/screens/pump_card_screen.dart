import 'package:firepumpsim/theme.dart';
import 'package:flutter/material.dart';

class PumpCardScreen extends StatelessWidget {
  const PumpCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pump Card')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: FirePumpSimColors.charcoal2,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
          ),
          child: Text(
            'Your department pump chart / quick-reference card goes here.',
            style: textTheme.bodyLarge?.copyWith(color: FirePumpSimColors.textMed, height: 1.5),
          ),
        ),
      ),
    );
  }
}
