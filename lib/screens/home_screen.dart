import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/models/daily_challenge_models.dart';
import 'package:firepumpsim/services/app_review_service.dart';
import 'package:firepumpsim/services/daily_challenge_storage.dart';
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
  final _dailyStorage = DailyChallengeStorage();
  DailyChallengeStats _dailyStats = DailyChallengeStats.empty;
  bool _dailyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDaily();

    // Safe place to prompt for ratings: only after the user reaches home.
    // Schedule after first frame so we never block initial render.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        AppReviewService.instance.onHomeScreenShown();
      });
    });
  }

  Future<void> _loadDaily() async {
    try {
      final s = await _dailyStorage.loadStats();
      if (!mounted) return;
      setState(() {
        _dailyStats = s;
        _dailyLoaded = true;
      });
    } catch (e) {
      debugPrint('Home daily stats load failed: $e');
      if (!mounted) return;
      setState(() => _dailyLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isTight = screenHeight < 720;
    // The branded banner artwork is a 2:1 image. Size the header close to
    // that aspect ratio so the image ends cleanly instead of leaving a large
    // charcoal/black dead area under the banner.
    final double heroTopInset = isTight ? 6 : 8;
    final double heroHeight = ((screenWidth / 2.0) + heroTopInset).clamp(182.0, 260.0);
    final double cardHeight = isTight ? 62 : 68;
    const double cardGap = 12;

    return Scaffold(
      backgroundColor: FirePumpSimColors.charcoal,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Add breathing room above the hero so the artwork never feels clipped
            // against the very top edge (even on devices with small safe areas).
            const SizedBox(height: 4),
            // Edge-to-edge branded header: no side padding, no outer card styling.
            _HeroHeader(height: heroHeight, topInset: heroTopInset),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel('TRAINING'),
                    const SizedBox(height: 6),
                    _MainMenuCard(
                      height: cardHeight,
                      title: 'Practice Scenarios',
                      description: 'Free Starter Pack + unlocked packs',
                      icon: Icons.safety_check,
                      onTap: () => context.go(AppRoutes.practiceScenarios),
                    ),
                    const SizedBox(height: cardGap),
                    _MainMenuCard(
                      height: cardHeight,
                      title: 'Daily Challenge',
                      description: _dailyLoaded
                          ? (_dailyStats.currentStreak > 0
                              ? 'One question per day • Streak ${_dailyStats.currentStreak}d'
                              : 'One question per day')
                          : 'Loading…',
                      icon: Icons.calendar_today,
                      indicator: const _TodayPill(),
                      onTap: () => context.go(AppRoutes.dailyChallenge),
                    ),
                    const SizedBox(height: cardGap),
                    _MainMenuCard(
                      height: cardHeight,
                      title: 'Scenario Library',
                      description: 'Unlock more practice packs',
                      icon: Icons.auto_stories,
                      onTap: () => context.go(AppRoutes.scenarioLibrary),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('TOOLS'),
                    const SizedBox(height: 10),
                    _MainMenuCard(
                      height: cardHeight,
                      title: 'Printable Scenarios',
                      description: 'Worksheets and answer keys',
                      icon: Icons.print,
                      onTap: () => context.go(AppRoutes.printableScenarios),
                    ),
                    const SizedBox(height: cardGap),
                    _MainMenuCard(
                      height: cardHeight,
                      title: 'How To',
                      description: 'Step-by-step calculations',
                      icon: Icons.school,
                      onTap: () => context.go(AppRoutes.howTo),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _SafetyPrivacyCard(),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Intentionally left without a "coming soon" snackbar: the Scenario Library
  // now navigates to a dedicated page.
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.height, required this.topInset});

  final double height;
  final double topInset;

  static const String _brandingBannerAssetPath = 'assets/images/firepumpsim_brand_banner.jpg';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: FirePumpSimColors.charcoal,
            child: Padding(
              // Creates a small "dead zone" at the very top so the banner content isn't visually cut off.
              padding: EdgeInsets.only(top: topInset),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BrandBannerImage(
                    assetPath: _brandingBannerAssetPath,
                    fallbackLeft: 'assets/images/fire_engine_side_view_night_training_photo_black_1778511209771.jpg',
                    fallbackRight: 'assets/images/fire_truck_pump_panel_close_up_gauges_valves_photo_black_1778511210715.jpg',
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.transparent,
                          FirePumpSimColors.charcoal.withValues(alpha: 0.42),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return ColoredBox(
      color: FirePumpSimColors.charcoal,
      child: Image.asset(
        assetPath,
        // Prefer to fill the full width (no side letterboxing). Header height is
        // sized to the asset so the top doesn't look clipped.
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Brand banner failed to load ($assetPath): $error');
          return Row(
            children: [
              Expanded(child: _HeaderImage(assetPath: fallbackLeft, alignment: const Alignment(-1, 0.18))),
              Expanded(child: _HeaderImage(assetPath: fallbackRight, alignment: const Alignment(1, 0.18))),
            ],
          );
        },
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

class _SafetyPrivacyCard extends StatelessWidget {
  const _SafetyPrivacyCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: FirePumpSimColors.textMed.withValues(alpha: 0.95), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Training reference only. FirePumpSim uses local device storage, does not require an account, and should be checked against department SOPs and manufacturer data before operational use.',
              style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.4),
            ),
          ),
        ],
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
