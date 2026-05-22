import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static const _topics = <_HowToTopic>[
    _HowToTopic(
      title: 'Pump Pressure Basics',
      subtitle: 'Use this first for most hose problems',
      icon: Icons.speed,
      formula: 'PDP = NP + FL + Elevation + Appliance Loss',
      steps: [
        'Find the nozzle pressure.',
        'Calculate friction loss for each hose section.',
        'Add elevation pressure if the nozzle is above the pump.',
        'Add appliance/system loss when a wye, FDC, standpipe, or appliance is used.',
        'Round the final pump pressure to the nearest 5 PSI.',
      ],
      example: '200 ft of 1 3/4 in hose flowing 185 GPM with a 50 PSI nozzle: calculate hose FL, then add 50 PSI nozzle pressure.',
      watchOut: [
        'Do not use nozzle pressure by itself as pump pressure.',
        'Do not add friction loss twice.',
        'Only add appliance loss when the setup actually uses that appliance.',
      ],
    ),
    _HowToTopic(
      title: 'Friction Loss',
      subtitle: 'Hose size, flow, and length',
      icon: Icons.water_drop,
      formula: 'FL = C x (GPM / 100)^2 x length in hundreds',
      steps: [
        'Choose the correct hose coefficient for the hose size.',
        'Divide GPM by 100.',
        'Square that number.',
        'Multiply by the hose coefficient.',
        'Multiply by hose length in hundreds of feet.',
      ],
      example: 'For 200 ft, use length = 2. For 150 ft, use length = 1.5.',
      watchOut: [
        'Wrong hose coefficient is one of the most common errors.',
        'Do not forget to square GPM / 100.',
        'Use the flow in that specific hose section, not always total incident flow.',
      ],
    ),
    _HowToTopic(
      title: 'Elevation',
      subtitle: 'Floors and vertical feet',
      icon: Icons.trending_up,
      formula: 'Elevation = 0.5 PSI per foot, or about 5 PSI per floor',
      steps: [
        'Find how far the nozzle is above or below the pump.',
        'If using floors: 1st floor = 0 ft, 2nd = 10 ft, 3rd = 20 ft, 4th = 30 ft.',
        'Add pressure for elevation above the pump.',
        'Subtract pressure for elevation below the pump.',
      ],
      example: 'A 3rd floor attack is 20 ft above the pump by this app rule, so elevation pressure is based on 20 ft.',
      watchOut: [
        'Do not count the first floor as one full floor of elevation.',
        'Elevation is separate from friction loss.',
        'The scenario should give the floor or vertical distance, not the PSI answer.',
      ],
    ),
    _HowToTopic(
      title: 'Standpipe / FDC',
      subtitle: 'Pump to the system plus hose/nozzle needs',
      icon: Icons.apartment,
      formula: 'PDP = Hose FL + NP + Elevation + FDC/standpipe loss',
      steps: [
        'Identify that the setup is using an FDC or standpipe.',
        'Calculate the attack-line friction loss from the outlet to the nozzle.',
        'Add nozzle pressure.',
        'Add elevation based on the floor or vertical rise.',
        'Add the department/system FDC or standpipe loss when directed by policy or scenario rules.',
      ],
      example: 'For a 3rd floor standpipe, calculate the hose stretch from outlet to nozzle, then add nozzle pressure, elevation, and system loss.',
      watchOut: [
        'Do not show “+25” on photo labels; the student should know the FDC rule.',
        'Do not forget the hose from the standpipe outlet to the nozzle.',
        'Do not confuse floor number with elevation feet.',
      ],
    ),
    _HowToTopic(
      title: 'Wye Operations',
      subtitle: 'One line in, two lines out',
      icon: Icons.call_split,
      formula: 'Pump to the highest-pressure branch',
      steps: [
        'Calculate the feeder line friction loss using total flow before the wye.',
        'Calculate Branch A friction loss.',
        'Calculate Branch B friction loss.',
        'Add nozzle pressure for each branch.',
        'Use the branch that needs the higher pressure.',
        'Add wye/appliance loss if used by your rules.',
      ],
      example: 'If Branch B is longer than Branch A, Branch B will often control the pump pressure.',
      watchOut: [
        'A wye should have one inlet and two outlets.',
        'Do not average the two branch pressures.',
        'The line before the wye carries total flow from both branches.',
      ],
    ),
    _HowToTopic(
      title: 'Master Streams',
      subtitle: 'Single-line and dual-line supply',
      icon: Icons.fire_hydrant_alt,
      formula: 'Single line: one hose carries total flow. Dual line: split total flow between equal lines.',
      steps: [
        'Identify total master stream flow and nozzle pressure.',
        'For a single supply line, calculate FL using total flow in that line.',
        'For two equal supply lines, divide total flow by two and calculate FL for one line.',
        'Add master stream nozzle pressure.',
        'Add appliance loss only if the setup includes a siamese, manifold, or other appliance with assigned loss.',
      ],
      example: 'A 500 GPM master stream supplied by two equal lines means each line carries 250 GPM.',
      watchOut: [
        'Do not calculate each dual supply line at total flow.',
        'Do not add the friction loss of parallel equal supply lines together.',
        'Master stream nozzle pressure is usually different from handline nozzle pressure.',
      ],
    ),
    _HowToTopic(
      title: 'Nozzle Reaction',
      subtitle: 'Estimate firefighter/nozzle force',
      icon: Icons.bolt,
      formula: 'Fog NR = 0.0505 x GPM x square root of NP\nSmooth bore NR = 1.57 x diameter^2 x NP',
      steps: [
        'Identify whether the nozzle is fog or smooth bore.',
        'For fog nozzles, use GPM and nozzle pressure.',
        'For smooth bore nozzles, use tip diameter and nozzle pressure.',
        'Round to a practical whole-pound answer.',
      ],
      example: 'A fog nozzle flowing 185 GPM at 50 PSI uses the fog nozzle reaction formula.',
      watchOut: [
        'Do not use pump pressure in place of nozzle pressure.',
        'For smooth bore, remember to square the tip diameter.',
        'The answer is pounds, not PSI.',
      ],
    ),
    _HowToTopic(
      title: 'Smooth Bore Flow',
      subtitle: 'Find GPM from tip size and NP',
      icon: Icons.stream,
      formula: 'GPM = 29.7 x diameter^2 x square root of NP',
      steps: [
        'Find the smooth bore tip diameter.',
        'Square the tip diameter.',
        'Find the square root of nozzle pressure.',
        'Multiply by 29.7.',
        'Round to a practical GPM value.',
      ],
      example: 'A deck gun with a 1 1/2 in tip at 80 PSI is a flow question, not a pump-pressure question.',
      watchOut: [
        'Do not enter the nozzle pressure as the GPM answer.',
        'Use master stream nozzle pressure when calculating deck gun flow.',
        'Confirm whether the question asks for flow or PDP.',
      ],
    ),
    _HowToTopic(
      title: 'Relay Pumping',
      subtitle: 'Supply engine to receiving engine',
      icon: Icons.swap_horiz,
      formula: 'Relay PDP = Relay hose FL + Elevation + receiving intake target',
      steps: [
        'Find the relay flow in GPM.',
        'Calculate friction loss in the relay supply hose.',
        'Add or subtract elevation between engines.',
        'Add the desired receiving-engine intake pressure.',
        'Round the relay PDP to the nearest 5 PSI.',
      ],
      example: 'Engine 181 pumping LDH to a receiving engine must overcome LDH friction loss and still leave intake pressure at the receiving engine.',
      watchOut: [
        'Do not stop at friction loss only.',
        'Do not confuse relay PDP with fire attack PDP.',
        'Make sure the receiving intake target is included.',
      ],
    ),
    _HowToTopic(
      title: 'Hydrant Pressure Drop',
      subtitle: 'Static minus residual',
      icon: Icons.local_fire_department,
      formula: 'Pressure drop = Static pressure - Residual pressure',
      steps: [
        'Read static pressure before flow.',
        'Read residual pressure while flowing.',
        'Subtract residual from static.',
        'Use the drop to judge remaining hydrant capacity.',
      ],
      example: 'Static 70 PSI and residual 50 PSI gives a 20 PSI pressure drop.',
      watchOut: [
        'Do not use pump discharge pressure for hydrant drop.',
        'Do not use flow in the basic pressure-drop subtraction.',
        'Keep at least the department minimum residual pressure.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
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
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'How To',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: FirePumpSimColors.textHigh,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _TopTipCard(textTheme: textTheme),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView.separated(
                  itemCount: _topics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
                    return _HowToTile(
                      topic: topic,
                      onTap: () => _showHowToSheet(context, topic),
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

  static void _showHowToSheet(BuildContext context, _HowToTopic topic) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FirePumpSimColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: FirePumpSimColors.textMed.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      _IconBadge(icon: topic.icon),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.title,
                              style: textTheme.titleLarge?.copyWith(
                                color: FirePumpSimColors.textHigh,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topic.subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: FirePumpSimColors.textMed,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DetailCard(
                    title: 'Formula',
                    child: Text(
                      topic.formula,
                      style: textTheme.titleMedium?.copyWith(
                        color: FirePumpSimColors.textHigh,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailCard(
                    title: 'Steps',
                    child: _BulletList(items: topic.steps),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailCard(
                    title: 'Example',
                    child: Text(
                      topic.example,
                      style: textTheme.bodyMedium?.copyWith(
                        color: FirePumpSimColors.textHigh,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailCard(
                    title: 'Watch Out',
                    child: _BulletList(items: topic.watchOut),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TopTipCard extends StatelessWidget {
  const _TopTipCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fast calculation order',
            style: textTheme.titleMedium?.copyWith(
              color: FirePumpSimColors.textHigh,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '1) Identify the setup.  2) Find flow.  3) Calculate hose FL.  4) Add NP, elevation, and appliance/system loss when used. Training reference only—verify with department SOPs.',
            style: textTheme.bodySmall?.copyWith(
              color: FirePumpSimColors.textMed,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToTopic {
  const _HowToTopic({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.formula,
    required this.steps,
    required this.example,
    required this.watchOut,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String formula;
  final List<String> steps;
  final String example;
  final List<String> watchOut;
}

class _HowToTile extends StatelessWidget {
  const _HowToTile({required this.topic, required this.onTap});

  final _HowToTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.34)),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  _IconBadge(icon: topic.icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: FirePumpSimColors.textHigh,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topic.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: FirePumpSimColors.textMed,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.chevron_right, size: 26, color: FirePumpSimColors.textMed),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: FirePumpSimColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.28)),
      ),
      child: Center(child: Icon(icon, size: 22, color: FirePumpSimColors.red)),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FirePumpSimColors.steel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: textTheme.labelMedium?.copyWith(
              color: FirePumpSimColors.redSoft,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  height: 5,
                  width: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: FirePumpSimColors.red,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item,
                    style: textTheme.bodyMedium?.copyWith(
                      color: FirePumpSimColors.textHigh,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
