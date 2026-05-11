import 'dart:ui';

import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _HeroHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.93,
                ),
                delegate: SliverChildListDelegate(
                  [
                    _FeatureCard(
                      title: 'Practice Scenarios',
                      description: 'Build your skills with real-world pump scenarios.',
                      buttonText: 'Start Training',
                      accent: FirePumpSimColors.red,
                      icon: Icons.safety_check,
                      onPressed: () => context.push(AppRoutes.practiceScenarios),
                    ),
                    _FeatureCard(
                      title: 'Daily Challenge',
                      description: 'A new scenario every day. Keep your skills sharp.',
                      buttonText: 'Start Challenge',
                      accent: FirePumpSimColors.challengeBlue,
                      icon: Icons.calendar_today,
                      badgeText: '7',
                      badgeLabel: 'streak',
                      onPressed: () => debugPrint('Start Challenge tapped'),
                    ),
                    _FeatureCard(
                      title: 'Printable Scenarios',
                      description: 'Generate worksheets, answer keys, and randomized tests.',
                      buttonText: 'Open Printables',
                      accent: FirePumpSimColors.printGreen,
                      icon: Icons.print,
                      onPressed: () => debugPrint('Open Printables tapped'),
                    ),
                    _FeatureCard(
                      title: 'Scenario Library',
                      description: 'Browse free scenarios and premium scenario packs.',
                      buttonText: 'Browse Library',
                      accent: FirePumpSimColors.libraryPurple,
                      icon: Icons.auto_stories,
                      onPressed: () => debugPrint('Browse Library tapped'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
              sliver: SliverToBoxAdapter(child: _StatsBar()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          height: 230,
          decoration: BoxDecoration(color: FirePumpSimColors.charcoal2, border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.7))),
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderImage(
                        assetPath: 'assets/images/fire_engine_side_view_night_training_photo_black_1778511209771.jpg',
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    Expanded(
                      child: _HeaderImage(
                        assetPath: 'assets/images/fire_truck_pump_panel_close_up_gauges_valves_photo_black_1778511210715.jpg',
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        FirePumpSimColors.charcoal.withValues(alpha: 0.65),
                        FirePumpSimColors.charcoal.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIREPUMPSIM',
                        style: textTheme.headlineLarge?.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          color: FirePumpSimColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Train • Practice • Perform',
                        style: textTheme.titleMedium?.copyWith(
                          color: FirePumpSimColors.textHigh,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          'Real-world pump scenarios for Driver/Operators',
                          style: textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                            color: FirePumpSimColors.textMed,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: FirePumpSimColors.steel.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.55)),
                              boxShadow: [
                                BoxShadow(
                                  color: FirePumpSimColors.red.withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department, size: 18, color: FirePumpSimColors.red),
                                const SizedBox(width: 6),
                                Text(
                                  'Driver/Operator Training',
                                  style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({required this.assetPath, required this.alignment});

  final String assetPath;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(FirePumpSimColors.charcoal.withValues(alpha: 0.6), BlendMode.darken),
      child: Image.asset(
        assetPath,
        alignment: alignment,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Header image failed to load ($assetPath): $error');
          return const DecoratedBox(decoration: BoxDecoration(color: FirePumpSimColors.charcoal2));
        },
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.accent,
    required this.icon,
    required this.onPressed,
    this.badgeText,
    this.badgeLabel,
  });

  final String title;
  final String description;
  final String buttonText;
  final Color accent;
  final IconData icon;
  final VoidCallback onPressed;
  final String? badgeText;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent.withValues(alpha: 0.45)),
                            ),
                            child: Center(child: Icon(icon, size: 20, color: accent)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800, height: 1.15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          description,
                          style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.4),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: _PillActionButton(text: buttonText, accent: accent, onPressed: onPressed),
                      ),
                    ],
                  ),
                  if (badgeText != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _StreakBadge(accent: accent, value: badgeText!, label: badgeLabel ?? ''),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillActionButton extends StatelessWidget {
  const _PillActionButton({required this.text, required this.accent, required this.onPressed});

  final String text;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(color: accent.withValues(alpha: 0.65)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        foregroundColor: accent,
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
      icon: Icon(Icons.arrow_forward, size: 18, color: accent),
      label: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.accent, required this.value, required this.label});

  final Color accent;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(value, style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: 'Current Rank',
              value: 'Driver/Operator',
              icon: Icons.badge,
              iconColor: FirePumpSimColors.red,
              valueStyle: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800),
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatCell(
              label: 'Completed',
              value: '42',
              icon: Icons.task_alt,
              iconColor: FirePumpSimColors.textMed,
              valueStyle: textTheme.titleLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatCell(
              label: 'Daily Streak',
              value: '7 Days',
              icon: Icons.local_fire_department,
              iconColor: FirePumpSimColors.redSoft,
              valueStyle: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 44,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    color: FirePumpSimColors.steel.withValues(alpha: 0.8),
  );
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle),
      ],
    );
  }
}
