import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bool isTight = screenHeight < 720;
    final double heroHeight = isTight ? 142 : 156;
    final double cardHeight = isTight ? 62 : 68;
    const double gap = 7;

    final pagePadding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      0,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroHeader(height: heroHeight),
              const SizedBox(height: 10),

              const _SectionLabel('TRAINING'),
              const SizedBox(height: 6),
              _MainMenuCard(
                height: cardHeight,
                title: 'Practice Scenarios',
                description: 'Start pump training',
                icon: Icons.safety_check,
                onTap: () => context.go(AppRoutes.practiceScenarios),
              ),
              const SizedBox(height: gap),
              _MainMenuCard(
                height: cardHeight,
                title: 'Daily Challenge',
                description: 'One new problem daily',
                icon: Icons.calendar_today,
                indicator: const _TodayPill(),
                onTap: () => _comingSoon(context, 'Daily Challenge'),
              ),
              const SizedBox(height: gap),
              _MainMenuCard(
                height: cardHeight,
                title: 'Scenario Library',
                description: 'Browse scenario packs',
                icon: Icons.auto_stories,
                onTap: () => _comingSoon(context, 'Scenario Library'),
              ),

              const SizedBox(height: 10),
              const _SectionLabel('TOOLS'),
              const SizedBox(height: 6),
              _MainMenuCard(
                height: cardHeight,
                title: 'Printable Scenarios',
                description: 'Worksheets and answer keys',
                icon: Icons.print,
                onTap: () => _comingSoon(context, 'Printable Scenarios'),
              ),
              const SizedBox(height: gap),
              _MainMenuCard(
                height: cardHeight,
                title: 'How To',
                description: 'Step-by-step calculations',
                icon: Icons.school,
                onTap: () => context.go(AppRoutes.howTo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String label) {
    debugPrint('$label tapped (coming soon)');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is coming soon.'),
        backgroundColor: FirePumpSimColors.charcoal3,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.height});

  final double height;

  /// TODO: Replace this with the exact filename of your uploaded FirePumpSim
  /// branding artwork (Assets panel → images). Example:
  /// `assets/images/firepumpsim_brand_banner.png`
  static const String _brandingBannerAssetPath = 'assets/images/firepumpsim_brand_banner.png';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.94,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: FirePumpSimColors.red.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 24, offset: const Offset(0, 18)),
            ],
          ),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: FirePumpSimColors.charcoal2,
              border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.90), width: 1),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _BrandBannerImage(
                    assetPath: _brandingBannerAssetPath,
                    fallbackLeft: 'assets/images/fire_engine_side_view_night_training_photo_black_1778511209771.jpg',
                    fallbackRight: 'assets/images/fire_truck_pump_panel_close_up_gauges_valves_photo_black_1778511210715.jpg',
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          FirePumpSimColors.charcoal.withValues(alpha: 0.16),
                          FirePumpSimColors.charcoal.withValues(alpha: 0.55),
                        ],
                        stops: const [0.60, 0.82, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBannerImage extends StatelessWidget {
  const _BrandBannerImage({required this.assetPath, required this.fallbackLeft, required this.fallbackRight});

  final String assetPath;
  final String fallbackLeft;
  final String fallbackRight;

  @override
  Widget build(BuildContext context) {
    // We try to render the branded artwork first. If it isn't present yet (or the
    // filename differs), we gracefully fall back to the previous split-image hero.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Transform.scale(
        scale: 1.04,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Brand banner failed to load ($assetPath): $error');
            return Row(
              children: [
                Expanded(
                  child: _HeaderImage(
                    assetPath: fallbackLeft,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                Expanded(
                  child: _HeaderImage(
                    assetPath: fallbackRight,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ],
            );
          },
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

class _MainMenuCard extends StatelessWidget {
  const _MainMenuCard({required this.title, required this.description, required this.icon, required this.onTap, required this.height, this.indicator});

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final double height;
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const accent = FirePumpSimColors.red;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.white.withValues(alpha: 0.035),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Center(child: Icon(icon, size: 22, color: accent)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.25, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (indicator != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    indicator!,
                  ],
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.chevron_right, size: 26, color: FirePumpSimColors.textMed),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(color: FirePumpSimColors.red.withValues(alpha: 0.62), fontWeight: FontWeight.w800, letterSpacing: 1.2),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FirePumpSimColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.55)),
      ),
      child: Text(
        'TODAY',
        style: style?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 10.5),
      ),
    );
  }
}
