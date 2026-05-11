import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:firepumpsim/screens/formulas_screen.dart';
import 'package:firepumpsim/screens/home_screen.dart';
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

      GoRoute(
        path: AppRoutes.practiceScenarios,
        name: 'practiceScenarios',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const PracticeScenariosScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );

              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),

      ShellRoute(
        builder: (context, state, child) {
          return _AppShell(
            state: state,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) {
              return NoTransitionPage(
                key: state.pageKey,
                child: const HomeScreen(),
              );
            },
          ),

          GoRoute(
            path: AppRoutes.formulas,
            name: 'formulas',
            pageBuilder: (context, state) {
              return NoTransitionPage(
                key: state.pageKey,
                child: const FormulasScreen(),
              );
            },
          ),

          GoRoute(
            path: AppRoutes.pumpCard,
            name: 'pumpCard',
            pageBuilder: (context, state) {
              return NoTransitionPage(
                key: state.pageKey,
                child: const PumpCardScreen(),
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
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );

                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    ],
  );
}

class AppRoutes {
  static const String root = '/';
  static const String home = '/home';
  static const String formulas = '/formulas';
  static const String pumpCard = '/pump-card';
  static const String practiceScenarios = '/practice-scenarios';
  static const String scenarioPlayer = '/scenario-player';
}

class _AppShell extends StatelessWidget {
  const _AppShell({
    required this.state,
    required this.child,
  });

  final GoRouterState state;
  final Widget child;

  int _locationToIndex(String location) {
    if (location.startsWith(AppRoutes.formulas)) return 1;
    if (location.startsWith(AppRoutes.pumpCard)) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        return;
      case 1:
        context.go(AppRoutes.formulas);
        return;
      case 2:
        context.go(AppRoutes.pumpCard);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _locationToIndex(state.uri.toString());

    return Scaffold(
      body: child,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: NavigationBar(
            height: 68,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onTap(context, index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: 'Formulas',
              ),
              NavigationDestination(
                icon: Icon(Icons.credit_card_outlined),
                selectedIcon: Icon(Icons.credit_card),
                label: 'Pump Card',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
