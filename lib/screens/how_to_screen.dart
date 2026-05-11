import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static const _items = <_HowToItem>[
    _HowToItem(title: 'Friction Loss Basics', subtitle: 'Rules of thumb and common hose sizes', icon: Icons.water_drop),
    _HowToItem(title: 'Standpipe Calculations', subtitle: 'Floor loss, nozzle pressure, and total PDP', icon: Icons.apartment),
    _HowToItem(title: 'Relay Pumping', subtitle: 'Spacing, intake targets, and safety checks', icon: Icons.swap_horiz),
    _HowToItem(title: 'Master Streams', subtitle: 'Big-water setup with appliances and loss', icon: Icons.fire_hydrant_alt),
    _HowToItem(title: 'Nozzle Reaction', subtitle: 'Fog vs smooth bore reaction formulas', icon: Icons.bolt),
    _HowToItem(title: 'Elevation and Appliance Loss', subtitle: 'Head pressure + common appliance loss', icon: Icons.trending_up),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      foregroundColor: FirePumpSimColors.textHigh,
                    ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'How To',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Step-by-step pump calculations and quick references.',
                style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _HowToTile(
                      item: item,
                      onTap: () {
                        debugPrint('How To item tapped: ${item.title}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Opening "${item.title}" (coming soon).'),
                            backgroundColor: FirePumpSimColors.charcoal3,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToItem {
  const _HowToItem({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
}

class _HowToTile extends StatelessWidget {
  const _HowToTile({required this.item, required this.onTap});

  final _HowToItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const accent = FirePumpSimColors.red;

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: accent.withValues(alpha: 0.28)),
                    ),
                    child: Center(child: Icon(item.icon, size: 22, color: accent)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
