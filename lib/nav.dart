import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:firepumpsim/screens/calculator_screen.dart';
import 'package:firepumpsim/screens/formulas_screen.dart';
import 'package:firepumpsim/screens/home_screen.dart';
import 'package:firepumpsim/screens/how_to_screen.dart';
import 'package:firepumpsim/screens/practice_scenarios_screen.dart';
import 'package:firepumpsim/screens/pump_card_screen.dart';
import 'package:firepumpsim/screens/scenario_player_screen.dart';
import 'package:firepumpsim/theme.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (context, state) => AppRoutes.home,
      ),

      // Persistent reference launcher bar: visible on all routes.
      // Calculator / Formulas / Pump Card open as modal overlays so users can
      // close them and return to the exact same scenario state.
      ShellRoute(
        builder: (context, state, child) => _AppShell(state: state, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.practiceScenarios,
            name: 'practiceScenarios',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const PracticeScenariosScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: AppRoutes.scenarioPlayer,
            name: 'scenarioPlayer',
            pageBuilder: (context, state) {
              final problemId = state.uri.queryParameters['problemId'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: ScenarioPlayerScreen(problemId: problemId),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: AppRoutes.howTo,
            name: 'howTo',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const HowToScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
                      child: child,
                    ),
                  );
                },
              );
            },
          ),

          // Keep these as normal routes for deep links / standalone browsing.
          GoRoute(
            path: AppRoutes.calculator,
            name: 'calculator',
            pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const CalculatorScreen()),
          ),
          GoRoute(
            path: AppRoutes.formulas,
            name: 'formulas',
            pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const FormulasScreen()),
          ),
          GoRoute(
            path: AppRoutes.pumpCard,
            name: 'pumpCard',
            pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const PumpCardScreen()),
          ),
        ],
      ),
    ],
  );
}

class AppRoutes {
  static const String root = '/';
  static const String calculator = '/calculator';
  static const String home = '/home';
  static const String formulas = '/formulas';
  static const String pumpCard = '/pump-card';
  static const String howTo = '/how-to';
  static const String practiceScenarios = '/practice-scenarios';
  static const String scenarioPlayer = '/scenario-player';
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const SafeArea(top: false, child: _ReferenceLauncherBar()),
    );
  }
}

class _ReferenceLauncherBar extends StatelessWidget {
  const _ReferenceLauncherBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FirePumpSimColors.charcoal2,
          border: Border(top: BorderSide(color: FirePumpSimColors.red.withValues(alpha: 0.10), width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 18, offset: const Offset(0, -10)),
            BoxShadow(color: FirePumpSimColors.red.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, -10)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: _ReferenceLauncherButton(
                  icon: Icons.calculate_outlined,
                  label: 'Calculator',
                  onTap: () => showCalculatorOverlay(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReferenceLauncherButton(
                  icon: Icons.functions_outlined,
                  label: 'Formulas',
                  onTap: () => showFormulasOverlay(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReferenceLauncherButton(
                  icon: Icons.credit_card_outlined,
                  label: 'Pump Card',
                  onTap: () => showPumpCardOverlay(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceLauncherButton extends StatefulWidget {
  const _ReferenceLauncherButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ReferenceLauncherButton> createState() => _ReferenceLauncherButtonState();
}

class _ReferenceLauncherButtonState extends State<_ReferenceLauncherButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fg = FirePumpSimColors.textHigh;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.98 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: FirePumpSimColors.charcoal3.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.55)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: FirePumpSimColors.red, size: 22),
              const SizedBox(height: 4),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (textTheme.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
