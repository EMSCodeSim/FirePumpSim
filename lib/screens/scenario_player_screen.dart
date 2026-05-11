import 'package:firepumpsim/models/scenario_models.dart';
import 'package:firepumpsim/services/scenario_repository.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scenario Player.
///
/// Shows one playable scenario problem at a time.
class ScenarioPlayerScreen extends StatefulWidget {
  const ScenarioPlayerScreen({super.key, required this.problemId});

  final String problemId;

  @override
  State<ScenarioPlayerScreen> createState() => _ScenarioPlayerScreenState();
}

class _ScenarioPlayerScreenState extends State<ScenarioPlayerScreen> {
  final ScenarioRepository _repo = ScenarioRepository();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<PlayableScenarioProblem?>(
          future: _repo.findPlayableByProblemId(widget.problemId),
          builder: (context, snapshot) {
            final p = snapshot.data;

            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  color: FirePumpSimColors.red,
                  strokeWidth: 2,
                ),
              );
            }

            if (p == null) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: FirePumpSimColors.textHigh,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: FirePumpSimColors.charcoal2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: FirePumpSimColors.steel.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Scenario not found',
                      style: textTheme.titleLarge?.copyWith(
                        color: FirePumpSimColors.textHigh,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This scenario problem may have been removed or the pack manifest is out of date.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: FirePumpSimColors.textMed,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: FirePumpSimColors.textHigh,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: FirePumpSimColors.charcoal2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: FirePumpSimColors.steel.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.problemTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleLarge?.copyWith(
                                  color: FirePumpSimColors.textHigh,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${p.type} • ${p.difficulty}${p.timedModeAvailable ? ' • Timed' : ''}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: FirePumpSimColors.textMed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FirePumpSimColors.charcoal2,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: FirePumpSimColors.steel.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // IMPORTANT:
                            // Load the actual image path from p.image.
                            // p.scene is scenario description text, not an asset path.
                            _SceneImage(assetPath: p.image),

                            const SizedBox(height: AppSpacing.md),

                            if (p.scene.trim().isNotEmpty) ...[
                              Text(
                                'Scene',
                                style: textTheme.labelLarge?.copyWith(
                                  color: FirePumpSimColors.textHigh,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.scene,
                                style: textTheme.bodySmall?.copyWith(
                                  color: FirePumpSimColors.textMed,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],

                            Text(
                              'Student Prompt',
                              style: textTheme.labelLarge?.copyWith(
                                color: FirePumpSimColors.textHigh,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.studentQuestion,
                              style: textTheme.bodyMedium?.copyWith(
                                color: FirePumpSimColors.textMed,
                                height: 1.55,
                              ),
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: FirePumpSimColors.charcoal3.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(
                                  color: FirePumpSimColors.red.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: FirePumpSimColors.redSoft,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This is the Scenario Player shell. The solving workflow, answer checking, overlays, and formula breakdown can be implemented here next.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: FirePumpSimColors.textMed,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SceneImage extends StatelessWidget {
  const _SceneImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: FirePumpSimColors.steel.withValues(alpha: 0.8),
          ),
          color: FirePumpSimColors.charcoal3,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              FirePumpSimColors.charcoal.withValues(alpha: 0.35),
              BlendMode.darken,
            ),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Scenario image failed to load ($assetPath): $error');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Image not found:\n$assetPath',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FirePumpSimColors.textMed,
                            height: 1.4,
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
