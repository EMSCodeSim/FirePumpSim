import 'dart:math' as math;

import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Home',
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.home_outlined),
        ),
      ),
      body: const SafeArea(child: CalculatorReferenceView()),
    );
  }
}

/// Opens the FirePumpSim calculator as a modal overlay.
///
/// This preserves the underlying route/widget state (ex: Scenario Player progress)
/// because it does not change routes.
Future<void> showCalculatorOverlay(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (context) => const CalculatorOverlaySheet(),
  );
}

class CalculatorOverlaySheet extends StatelessWidget {
  const CalculatorOverlaySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: FirePumpSimColors.charcoal,
              border: Border(top: BorderSide(color: FirePumpSimColors.red.withValues(alpha: 0.12), width: 1)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24, offset: const Offset(0, -12))],
            ),
            child: SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.92).clamp(520.0, 820.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: FirePumpSimColors.steel.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.close, color: FirePumpSimColors.textHigh),
                          style: IconButton.styleFrom(
                            backgroundColor: FirePumpSimColors.charcoal2,
                            side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: CalculatorReferenceView()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable calculator reference body.
///
/// Used by both the full screen route and the in-scenario modal overlay.
class CalculatorReferenceView extends StatefulWidget {
  const CalculatorReferenceView({super.key});

  @override
  State<CalculatorReferenceView> createState() => _CalculatorReferenceViewState();
}

class _CalculatorReferenceViewState extends State<CalculatorReferenceView> {
  final ValueNotifier<String> _expr = ValueNotifier<String>('');
  final ValueNotifier<String> _result = ValueNotifier<String>('');
  int _tabIndex = 0; // 0 = calc, 1 = helpers

  @override
  void dispose() {
    _expr.dispose();
    _result.dispose();
    super.dispose();
  }

  void _setExpr(String value) {
    _expr.value = value;
    _result.value = _tryEvaluate(value) ?? '';
  }

  void _append(String s) {
    final current = _expr.value;
    _setExpr(current + s);
  }

  void _backspace() {
    final current = _expr.value;
    if (current.isEmpty) return;
    _setExpr(current.substring(0, current.length - 1));
  }

  void _clear() => _setExpr('');

  void _toggleSign() {
    // Toggle the sign of the *last* numeric literal in the expression.
    // Examples:
    //  - "12" => "-12"
    //  - "10+5" => "10-5"
    //  - "10+-5" => "10+5"
    final s = _expr.value;
    final m = RegExp(r'(^|[+\-*/^\(])(-?\d*\.?\d+)$').firstMatch(s);
    if (m == null) return;
    final number = double.tryParse(m.group(2) ?? '');
    if (number == null) return;
    final toggled = _formatNumber(-number);
    final prefixLen = (m.group(1) ?? '').length;
    final startNum = m.start + prefixLen;
    final endNum = m.end;
    _setExpr(s.substring(0, startNum) + toggled + s.substring(endNum));
  }

  void _equals() {
    final value = _tryEvaluate(_expr.value);
    if (value == null) return;
    _setExpr(value);
  }

  void _copyResult() {
    final text = _result.value.trim().isNotEmpty ? _result.value : _expr.value;
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: FirePumpSimColors.charcoal3,
      ),
    );
  }

  String? _tryEvaluate(String expression) {
    try {
      final v = _evaluateExpression(expression);
      if (v == null) return null;
      return _formatNumber(v);
    } catch (e) {
      debugPrint('Calculator evaluate failed. expression="$expression" error=$e');
      return null;
    }
  }

  String _formatNumber(double v) {
    if (!v.isFinite) return 'ERR';
    // Keep it readable: trim trailing zeros.
    final s = v.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  double? _evaluateExpression(String input) {
    final s = input.replaceAll(' ', '');
    if (s.isEmpty) return null;
    final tokens = _tokenize(s);
    if (tokens.isEmpty) return null;
    final rpn = _toRpn(tokens);
    return _evalRpn(rpn);
  }

  List<String> _tokenize(String s) {
    final tokens = <String>[];
    final buf = StringBuffer();

    bool isOp(String c) => c == '+' || c == '-' || c == '*' || c == '/' || c == '^';
    bool isAlpha(String c) => (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) || (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122);

    for (int i = 0; i < s.length; i++) {
      final c = s[i];

      if ('0123456789.'.contains(c)) {
        buf.write(c);
        continue;
      }

      if (c == '(' || c == ')') {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
        tokens.add(c);
        continue;
      }

      if (isAlpha(c)) {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
        final fn = StringBuffer()..write(c);
        while (i + 1 < s.length && isAlpha(s[i + 1])) {
          i++;
          fn.write(s[i]);
        }
        tokens.add(fn.toString().toLowerCase());
        continue;
      }

      if (isOp(c)) {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
        // Unary minus: if at start or after another operator or after "(".
        if (c == '-' && (tokens.isEmpty || isOp(tokens.last) || tokens.last == '(')) {
          final next = (i + 1) < s.length ? s[i + 1] : '';
          if ('0123456789.'.contains(next)) {
            buf.write('-');
          } else {
            tokens.add('u-');
          }
        } else {
          tokens.add(c);
        }
        continue;
      }
    }

    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }

  int _precedence(String op) {
    if (op == 'sqrt' || op == 'u-') return 5;
    if (op == '^') return 4;
    if (op == '*' || op == '/') return 3;
    if (op == '+' || op == '-') return 2;
    return 0;
  }

  bool _isRightAssociative(String op) => op == '^' || op == 'u-' || op == 'sqrt';

  List<String> _toRpn(List<String> tokens) {
    bool isOp(String t) => t == '+' || t == '-' || t == '*' || t == '/' || t == '^';
    bool isFn(String t) => t == 'sqrt' || t == 'u-';
    final output = <String>[];
    final stack = <String>[];

    for (final t in tokens) {
      if (t == '(') {
        stack.add(t);
        continue;
      }

      if (t == ')') {
        while (stack.isNotEmpty && stack.last != '(') {
          output.add(stack.removeLast());
        }
        if (stack.isNotEmpty && stack.last == '(') stack.removeLast();
        if (stack.isNotEmpty && isFn(stack.last)) output.add(stack.removeLast());
        continue;
      }

      if (isFn(t)) {
        stack.add(t);
        continue;
      }

      if (!isOp(t)) {
        output.add(t);
        continue;
      }

      while (stack.isNotEmpty && (isFn(stack.last) || isOp(stack.last))) {
        final top = stack.last;
        final shouldPop = _isRightAssociative(t)
            ? _precedence(top) > _precedence(t)
            : _precedence(top) >= _precedence(t);
        if (!shouldPop) break;
        output.add(stack.removeLast());
      }
      stack.add(t);
    }
    while (stack.isNotEmpty) {
      output.add(stack.removeLast());
    }
    return output;
  }

  double _evalRpn(List<String> rpn) {
    bool isOp(String t) => t == '+' || t == '-' || t == '*' || t == '/' || t == '^';
    bool isFn(String t) => t == 'sqrt' || t == 'u-';
    final stack = <double>[];

    for (final t in rpn) {
      if (!isOp(t) && !isFn(t)) {
        final v = double.parse(t);
        stack.add(v);
        continue;
      }

      if (isFn(t)) {
        if (stack.isEmpty) throw StateError('Bad expression');
        final a = stack.removeLast();
        final res = switch (t) {
          'sqrt' => math.sqrt(a),
          'u-' => -a,
          _ => throw StateError('Unknown fn'),
        };
        stack.add(res);
        continue;
      }

      if (stack.length < 2) throw StateError('Bad expression');
      final b = stack.removeLast();
      final a = stack.removeLast();
      final res = switch (t) {
        '+' => a + b,
        '-' => a - b,
        '*' => a * b,
        '/' => a / b,
        '^' => math.pow(a, b).toDouble(),
        _ => throw StateError('Unknown op'),
      };
      stack.add(res);
    }

    if (stack.length != 1) throw StateError('Bad expression');
    return stack.single;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 10),
          child: _CalcModeToggle(
            index: _tabIndex,
            onChanged: (v) => setState(() => _tabIndex = v),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: _tabIndex == 0
                ? _CalculatorPad(
                    expr: _expr,
                    result: _result,
                    onKey: _append,
                    onClear: _clear,
                    onBackspace: _backspace,
                    onToggleSign: _toggleSign,
                    onEquals: _equals,
                    onCopy: _copyResult,
                  )
                : _HelperTools(
                    onUseResult: (value) {
                      _setExpr(value);
                      setState(() => _tabIndex = 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Result sent to calculator'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: FirePumpSimColors.charcoal3,
                        ),
                      );
                    },
                    textTheme: textTheme,
                  ),
          ),
        ),
      ],
    );
  }
}

class _CalcModeToggle extends StatelessWidget {
  const _CalcModeToggle({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              selected: index == 0,
              label: 'Calculator',
              onTap: () => onChanged(0),
              textTheme: textTheme,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModeButton(
              selected: index == 1,
              label: 'Helpers',
              onTap: () => onChanged(1),
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.selected, required this.label, required this.onTap, required this.textTheme});
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? FirePumpSimColors.red : FirePumpSimColors.charcoal2;
    final fg = selected ? Colors.white : FirePumpSimColors.textHigh;
    final border = selected ? Colors.transparent : FirePumpSimColors.steel.withValues(alpha: 0.85);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w900, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class _CalculatorPad extends StatelessWidget {
  const _CalculatorPad({
    required this.expr,
    required this.result,
    required this.onKey,
    required this.onClear,
    required this.onBackspace,
    required this.onToggleSign,
    required this.onEquals,
    required this.onCopy,
  });

  final ValueListenable<String> expr;
  final ValueListenable<String> result;
  final ValueChanged<String> onKey;
  final VoidCallback onClear;
  final VoidCallback onBackspace;
  final VoidCallback onToggleSign;
  final VoidCallback onEquals;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      child: Column(
        children: [
          _Display(expr: expr, result: result),
          const SizedBox(height: 10),
          _AdvancedKeysRow(onKey: onKey, textTheme: textTheme),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxHeight < 360;
                final spacing = compact ? 6.0 : 10.0;
                final maxButtonH = compact ? 58.0 : 74.0;
                final buttonH = ((c.maxHeight - spacing * 4) / 5).clamp(40.0, maxButtonH);
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Key(text: 'C', color: FirePumpSimColors.red, onTap: onClear, height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(icon: Icons.backspace_outlined, onTap: onBackspace, height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '±', onTap: onToggleSign, height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '÷', onTap: () => onKey('/'), height: buttonH, textTheme: textTheme)),
                      ],
                    ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Expanded(child: _Key(text: '7', onTap: () => onKey('7'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '8', onTap: () => onKey('8'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '9', onTap: () => onKey('9'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '×', onTap: () => onKey('*'), height: buttonH, textTheme: textTheme)),
                      ],
                    ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Expanded(child: _Key(text: '4', onTap: () => onKey('4'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '5', onTap: () => onKey('5'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '6', onTap: () => onKey('6'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '−', onTap: () => onKey('-'), height: buttonH, textTheme: textTheme)),
                      ],
                    ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Expanded(child: _Key(text: '1', onTap: () => onKey('1'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '2', onTap: () => onKey('2'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '3', onTap: () => onKey('3'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '+', onTap: () => onKey('+'), height: buttonH, textTheme: textTheme)),
                      ],
                    ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _Key(text: '0', onTap: () => onKey('0'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '.', onTap: () => onKey('.'), height: buttonH, textTheme: textTheme)),
                        SizedBox(width: spacing),
                        Expanded(child: _Key(text: '=', color: FirePumpSimColors.red, onTap: onEquals, height: buttonH, textTheme: textTheme)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, color: Colors.white, size: 18),
              label: Text('Copy result', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(
                backgroundColor: FirePumpSimColors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Display extends StatelessWidget {
  const _Display({required this.expr, required this.result});
  final ValueListenable<String> expr;
  final ValueListenable<String> result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ValueListenableBuilder(
            valueListenable: expr,
            builder: (context, value, _) {
              return Text(
                value.isEmpty ? '0' : value,
                textAlign: TextAlign.right,
                style: GoogleFonts.robotoMono(
                  textStyle: (textTheme.headlineSmall ?? const TextStyle(fontSize: 24)).copyWith(
                    color: FirePumpSimColors.textHigh,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: result,
            builder: (context, value, _) {
              if (value.trim().isEmpty) {
                return Text(' ', style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed));
              }
              return Text(
                value,
                style: GoogleFonts.robotoMono(
                  textStyle: (textTheme.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(
                    color: FirePumpSimColors.textMed,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdvancedKeysRow extends StatelessWidget {
  const _AdvancedKeysRow({required this.onKey, required this.textTheme});
  final ValueChanged<String> onKey;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MiniKey(text: '(', onTap: () => onKey('('), textTheme: textTheme)),
        const SizedBox(width: 10),
        Expanded(child: _MiniKey(text: ')', onTap: () => onKey(')'), textTheme: textTheme)),
        const SizedBox(width: 10),
        Expanded(child: _MiniKey(text: '^', onTap: () => onKey('^'), textTheme: textTheme)),
        const SizedBox(width: 10),
        Expanded(child: _MiniKey(text: '√', onTap: () => onKey('sqrt('), textTheme: textTheme)),
      ],
    );
  }
}

class _MiniKey extends StatelessWidget {
  const _MiniKey({required this.text, required this.onTap, required this.textTheme});
  final String text;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Material(
        color: FirePumpSimColors.charcoal2,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.white.withValues(alpha: 0.035),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.7))),
            child: Text(
              text,
              style: GoogleFonts.robotoMono(textStyle: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.text, this.icon, this.color, required this.onTap, required this.height, required this.textTheme}) : assert(text != null || icon != null);
  final String? text;
  final IconData? icon;
  final Color? color;
  final VoidCallback onTap;
  final double height;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? FirePumpSimColors.charcoal3).withValues(alpha: color == null ? 0.75 : 1.0);
    final fg = color == FirePumpSimColors.red ? Colors.white : FirePumpSimColors.textHigh;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: bg,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: fg, size: 20)
                  : Text(
                      text!,
                      style: textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelperTools extends StatelessWidget {
  const _HelperTools({required this.onUseResult, required this.textTheme});
  final ValueChanged<String> onUseResult;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        _HelperCardPumpPressure(onUseResult: onUseResult),
        const SizedBox(height: AppSpacing.md),
        _HelperCardFrictionLoss(onUseResult: onUseResult),
        const SizedBox(height: AppSpacing.md),
        _HelperCardElevation(onUseResult: onUseResult),
        const SizedBox(height: AppSpacing.md),
        _HelperCardSmoothBoreFlow(onUseResult: onUseResult),
        const SizedBox(height: AppSpacing.md),
        _HelperCardNozzleReaction(onUseResult: onUseResult),
        const SizedBox(height: AppSpacing.md),
        _HelperCardRelaySpacing(onUseResult: onUseResult),
        const SizedBox(height: AppSpacing.md),
        _HelperCardTenderShuttle(onUseResult: onUseResult),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: FirePumpSimColors.charcoal2,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.75)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: FirePumpSimColors.red.withValues(alpha: 0.9), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Training helpers only. SOPs, equipment specs, and department charts are the source of truth.',
                  style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Helper types exposed for embedding calculator helpers in other screens.
enum CalculatorHelperKind {
  pumpPressure,
  frictionLoss,
  elevation,
  smoothBoreFlow,
  nozzleReaction,
  relaySpacing,
  tenderShuttle,
}

/// A reusable calculator helper card that can be embedded in other screens.
///
/// If [onUseResult] is provided, the helper exposes a "Use" action.
class CalculatorHelperCard extends StatelessWidget {
  const CalculatorHelperCard({super.key, required this.kind, this.onUseResult});

  final CalculatorHelperKind kind;
  final ValueChanged<String>? onUseResult;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case CalculatorHelperKind.pumpPressure:
        return _HelperCardPumpPressure(onUseResult: onUseResult);
      case CalculatorHelperKind.frictionLoss:
        return _HelperCardFrictionLoss(onUseResult: onUseResult);
      case CalculatorHelperKind.elevation:
        return _HelperCardElevation(onUseResult: onUseResult);
      case CalculatorHelperKind.smoothBoreFlow:
        return _HelperCardSmoothBoreFlow(onUseResult: onUseResult);
      case CalculatorHelperKind.nozzleReaction:
        return _HelperCardNozzleReaction(onUseResult: onUseResult);
      case CalculatorHelperKind.relaySpacing:
        return _HelperCardRelaySpacing(onUseResult: onUseResult);
      case CalculatorHelperKind.tenderShuttle:
        return _HelperCardTenderShuttle(onUseResult: onUseResult);
    }
  }
}

// =============================================================================
// Helper cards
// =============================================================================

class _HelperCardPumpPressure extends StatefulWidget {
  const _HelperCardPumpPressure({this.onUseResult});
  final ValueChanged<String>? onUseResult;

  @override
  State<_HelperCardPumpPressure> createState() => _HelperCardPumpPressureState();
}

class _HelperCardPumpPressureState extends State<_HelperCardPumpPressure> {
  final _np = TextEditingController();
  final _fl = TextEditingController();
  final _ep = TextEditingController();
  final _al = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _np.dispose();
    _fl.dispose();
    _ep.dispose();
    _al.dispose();
    super.dispose();
  }

  void _calc() {
    final np = double.tryParse(_np.text.trim()) ?? 0;
    final fl = double.tryParse(_fl.text.trim()) ?? 0;
    final ep = double.tryParse(_ep.text.trim()) ?? 0;
    final al = double.tryParse(_al.text.trim()) ?? 0;
    final pp = np + fl + ep + al;
    setState(() => _out = pp.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return _HelperCardShell(
      title: 'Pump Pressure',
      subtitle: 'PP/PDP = NP + FL ± EP + AL',
      children: [
        _Row4(
          a: _NumField(label: 'NP', controller: _np, suffix: 'psi'),
          b: _NumField(label: 'FL', controller: _fl, suffix: 'psi'),
          c: _NumField(label: 'EP', controller: _ep, suffix: 'psi'),
          d: _NumField(label: 'AL', controller: _al, suffix: 'psi'),
        ),
        const SizedBox(height: 10),
        _ComputeRow(
          output: _out.isEmpty ? '—' : '${_out} psi',
          onCompute: _calc,
          onUse: (_out.isEmpty || widget.onUseResult == null) ? null : () => widget.onUseResult!.call(_out),
        ),
      ],
    );
  }
}

class _HelperCardFrictionLoss extends StatefulWidget {
  const _HelperCardFrictionLoss({this.onUseResult});
  final ValueChanged<String>? onUseResult;

  @override
  State<_HelperCardFrictionLoss> createState() => _HelperCardFrictionLossState();
}

class _HelperCardFrictionLossState extends State<_HelperCardFrictionLoss> {
  final _c = TextEditingController();
  final _gpm = TextEditingController();
  final _len = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _c.dispose();
    _gpm.dispose();
    _len.dispose();
    super.dispose();
  }

  void _calc() {
    final c = double.tryParse(_c.text.trim()) ?? 0;
    final gpm = double.tryParse(_gpm.text.trim()) ?? 0;
    final len = double.tryParse(_len.text.trim()) ?? 0;
    final q = gpm / 100.0;
    final l = len / 100.0;
    final fl = c * q * q * l;
    setState(() => _out = fl.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return _HelperCardShell(
      title: 'Friction Loss',
      subtitle: 'FL = C × (GPM/100)² × (ft/100)',
      children: [
        _ResponsiveFieldRow(
          children: [
            _NumField(label: 'C', controller: _c),
            _NumField(label: 'GPM', controller: _gpm),
            _NumField(label: 'Length', controller: _len, suffix: 'ft'),
          ],
        ),
        const SizedBox(height: 10),
        _ComputeRow(
          output: _out.isEmpty ? '—' : '${_out} psi',
          onCompute: _calc,
          onUse: (_out.isEmpty || widget.onUseResult == null) ? null : () => widget.onUseResult!.call(_out),
        ),
      ],
    );
  }
}

class _HelperCardElevation extends StatefulWidget {
  const _HelperCardElevation({this.onUseResult});
  final ValueChanged<String>? onUseResult;

  @override
  State<_HelperCardElevation> createState() => _HelperCardElevationState();
}

class _HelperCardElevationState extends State<_HelperCardElevation> {
  final _feet = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _feet.dispose();
    super.dispose();
  }

  void _calc() {
    final ft = double.tryParse(_feet.text.trim()) ?? 0;
    final psi = ft * 0.434;
    setState(() => _out = psi.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return _HelperCardShell(
      title: 'Elevation',
      subtitle: 'EP = feet × 0.434 psi/ft (physics)',
      children: [
        _ResponsiveFieldRow(
          children: [
            _NumField(label: 'Feet', controller: _feet, suffix: 'ft'),
            _StaticHint(text: 'Uphill adds, downhill subtracts'),
          ],
        ),
        const SizedBox(height: 10),
        _ComputeRow(
          output: _out.isEmpty ? '—' : '${_out} psi',
          onCompute: _calc,
          onUse: (_out.isEmpty || widget.onUseResult == null) ? null : () => widget.onUseResult!.call(_out),
        ),
      ],
    );
  }
}

class _HelperCardSmoothBoreFlow extends StatefulWidget {
  const _HelperCardSmoothBoreFlow({this.onUseResult});
  final ValueChanged<String>? onUseResult;

  @override
  State<_HelperCardSmoothBoreFlow> createState() => _HelperCardSmoothBoreFlowState();
}

class _HelperCardSmoothBoreFlowState extends State<_HelperCardSmoothBoreFlow> {
  final _diameter = TextEditingController();
  final _np = TextEditingController(text: '50');
  String _out = '';

  @override
  void dispose() {
    _diameter.dispose();
    _np.dispose();
    super.dispose();
  }

  void _calc() {
    final d = double.tryParse(_diameter.text.trim()) ?? 0;
    final np = double.tryParse(_np.text.trim()) ?? 0;
    final gpm = 29.7 * d * d * math.sqrt(np);
    setState(() => _out = gpm.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return _HelperCardShell(
      title: 'Smooth Bore Flow',
      subtitle: 'GPM = 29.7 × d² × √NP',
      children: [
        _ResponsiveFieldRow(
          children: [
            _NumField(label: 'Tip d', controller: _diameter, suffix: 'in'),
            _NumField(label: 'NP', controller: _np, suffix: 'psi'),
          ],
        ),
        const SizedBox(height: 10),
        _ComputeRow(
          output: _out.isEmpty ? '—' : '${_out} GPM',
          onCompute: _calc,
          onUse: (_out.isEmpty || widget.onUseResult == null) ? null : () => widget.onUseResult!.call(_out),
        ),
      ],
    );
  }
}

class _HelperCardNozzleReaction extends StatefulWidget {
  const _HelperCardNozzleReaction({this.onUseResult});
  final ValueChanged<String>? onUseResult;

  @override
  State<_HelperCardNozzleReaction> createState() => _HelperCardNozzleReactionState();
}

class _HelperCardNozzleReactionState extends State<_HelperCardNozzleReaction> {
  int _mode = 0; // 0 = fog, 1 = smooth
  final _gpm = TextEditingController();
  final _np = TextEditingController(text: '100');
  final _diameter = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _gpm.dispose();
    _np.dispose();
    _diameter.dispose();
    super.dispose();
  }

  void _calc() {
    final np = double.tryParse(_np.text.trim()) ?? 0;
    double nr;
    if (_mode == 0) {
      final gpm = double.tryParse(_gpm.text.trim()) ?? 0;
      nr = 0.0505 * gpm * math.sqrt(np);
    } else {
      final d = double.tryParse(_diameter.text.trim()) ?? 0;
      nr = 1.57 * d * d * np;
    }
    setState(() => _out = nr.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return _HelperCardShell(
      title: 'Nozzle Reaction',
      subtitle: _mode == 0 ? 'Fog NR = 0.0505 × GPM × √NP' : 'Smooth bore NR = 1.57 × d² × NP',
      headerTrailing: _TinyToggle(
        left: 'Fog',
        right: 'Smooth',
        index: _mode,
        onChanged: (v) => setState(() => _mode = v),
      ),
      children: [
        if (_mode == 0)
          _ResponsiveFieldRow(
            children: [
              _NumField(label: 'GPM', controller: _gpm),
              _NumField(label: 'NP', controller: _np, suffix: 'psi'),
            ],
          )
        else
          _ResponsiveFieldRow(
            children: [
              _NumField(label: 'Tip d', controller: _diameter, suffix: 'in'),
              _NumField(label: 'NP', controller: _np, suffix: 'psi'),
            ],
          ),
        const SizedBox(height: 10),
        _ComputeRow(
          output: _out.isEmpty ? '—' : '${_out} lb',
          onCompute: _calc,
          onUse: (_out.isEmpty || widget.onUseResult == null) ? null : () => widget.onUseResult!.call(_out),
        ),
      ],
    );
  }
}

class _HelperCardRelaySpacing extends StatefulWidget {
  const _HelperCardRelaySpacing({this.onUseResult});
  final ValueChanged<String>? onUseResult;

  @override
  State<_HelperCardRelaySpacing> createState() => _HelperCardRelaySpacingState();
}

class _HelperCardRelaySpacingState extends State<_HelperCardRelaySpacing> {
  final _usable = TextEditingController();
  final _flPer100 = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _usable.dispose();
    _flPer100.dispose();
    super.dispose();
  }

  void _calc() {
    final usable = double.tryParse(_usable.text.trim()) ?? 0;
    final fl = double.tryParse(_flPer100.text.trim()) ?? 0;
    if (fl <= 0) {
      setState(() => _out = '');
      return;
    }
    final dist = usable / fl * 100;
    setState(() => _out = dist.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return _HelperCardShell(
      title: 'Relay Spacing',
      subtitle: 'Distance = usable pressure ÷ FL/100′ × 100',
      children: [
        _ResponsiveFieldRow(
          children: [
            _NumField(label: 'Usable', controller: _usable, suffix: 'psi'),
            _NumField(label: 'FL/100′', controller: _flPer100, suffix: 'psi'),
          ],
        ),
        const SizedBox(height: 10),
        _ComputeRow(
          output: _out.isEmpty ? '—' : '${_out} ft/engine',
          onCompute: _calc,
          onUse: (_out.isEmpty || widget.onUseResult == null) ? null : () => widget.onUseResult!.call(_out),
        ),
      ],
    );
  }
}

class _HelperCardTenderShuttle extends StatefulWidget {
  const _HelperCardTenderShuttle({this.onUseResult});
  final ValueChanged<String>? onUseResult;

  @override
  State<_HelperCardTenderShuttle> createState() => _HelperCardTenderShuttleState();
}

class _HelperCardTenderShuttleState extends State<_HelperCardTenderShuttle> {
  final _gal = TextEditingController();
  final _cycle = TextEditingController();
  String _out = '';

  @override
  void dispose() {
    _gal.dispose();
    _cycle.dispose();
    super.dispose();
  }

  void _calc() {
    final gal = double.tryParse(_gal.text.trim()) ?? 0;
    final cycle = double.tryParse(_cycle.text.trim()) ?? 0;
    if (cycle <= 0) {
      setState(() => _out = '');
      return;
    }
    final gpm = gal / cycle;
    setState(() => _out = gpm.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    return _HelperCardShell(
      title: 'Tender Shuttle',
      subtitle: 'Shuttle GPM = usable gallons ÷ cycle time (min)',
      children: [
        _ResponsiveFieldRow(
          children: [
            _NumField(label: 'Usable', controller: _gal, suffix: 'gal'),
            _NumField(label: 'Cycle', controller: _cycle, suffix: 'min'),
          ],
        ),
        const SizedBox(height: 10),
        _ComputeRow(
          output: _out.isEmpty ? '—' : '${_out} GPM',
          onCompute: _calc,
          onUse: (_out.isEmpty || widget.onUseResult == null) ? null : () => widget.onUseResult!.call(_out),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared helper UI
// =============================================================================

class _HelperCardShell extends StatelessWidget {
  const _HelperCardShell({required this.title, required this.subtitle, required this.children, this.headerTrailing});
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, cst) {
              final compactHeader = headerTrailing != null && cst.maxWidth < 380;
              final titleText = Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: FirePumpSimColors.textHigh,
                  fontWeight: FontWeight.w900,
                ),
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleText,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: headerTrailing!),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleText),
                  if (headerTrailing != null) ...[
                    const SizedBox(width: 10),
                    Flexible(child: Align(alignment: Alignment.centerRight, child: headerTrailing!)),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cst) {
        final count = children.length;
        final columns = cst.maxWidth >= 620
            ? count
            : cst.maxWidth >= 420
                ? math.min(2, count)
                : 1;
        final spacing = columns == 1 ? 0.0 : 10.0;
        final itemWidth = columns == 1 ? cst.maxWidth : (cst.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: [
            for (final child in children) SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.controller, this.suffix});
  final String label;
  final TextEditingController controller;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: textTheme.titleSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
      cursorColor: FirePumpSimColors.red,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.3),
        ),
      ),
    );
  }
}

class _StaticHint extends StatelessWidget {
  const _StaticHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.55)),
      ),
      child: Text(text, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
    );
  }
}

class _ComputeRow extends StatelessWidget {
  const _ComputeRow({required this.output, required this.onCompute, required this.onUse});
  final String output;
  final VoidCallback onCompute;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget outputBox() {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: FirePumpSimColors.charcoal3.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.55)),
        ),
        child: Text(
          output,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
        ),
      );
    }

    Widget computeButton() {
      return SizedBox(
        height: 46,
        child: FilledButton(
          onPressed: onCompute,
          style: FilledButton.styleFrom(
            backgroundColor: FirePumpSimColors.red,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(96, 46),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
          child: Text('Compute', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      );
    }

    Widget useButton() {
      return SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: onUse,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(76, 46),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
          child: Text('Use', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, cst) {
        if (cst.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              outputBox(),
              const SizedBox(height: 10),
              if (onUse == null)
                computeButton()
              else
                Row(
                  children: [
                    Expanded(child: computeButton()),
                    const SizedBox(width: 10),
                    Expanded(child: useButton()),
                  ],
                ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: outputBox()),
            const SizedBox(width: 10),
            computeButton(),
            if (onUse != null) ...[
              const SizedBox(width: 10),
              useButton(),
            ],
          ],
        );
      },
    );
  }
}

class _Row4 extends StatelessWidget {
  const _Row4({required this.a, required this.b, required this.c, required this.d});
  final Widget a;
  final Widget b;
  final Widget c;
  final Widget d;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveFieldRow(children: [a, b, c, d]);
  }
}

class _TinyToggle extends StatelessWidget {
  const _TinyToggle({required this.left, required this.right, required this.index, required this.onChanged});
  final String left;
  final String right;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.55)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TinyToggleChip(
            selected: index == 0,
            label: left,
            onTap: () => onChanged(0),
            textTheme: textTheme,
          ),
          _TinyToggleChip(
            selected: index == 1,
            label: right,
            onTap: () => onChanged(1),
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _TinyToggleChip extends StatelessWidget {
  const _TinyToggleChip({required this.selected, required this.label, required this.onTap, required this.textTheme});
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? FirePumpSimColors.red : Colors.transparent;
    final fg = selected ? Colors.white : FirePumpSimColors.textMed;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
