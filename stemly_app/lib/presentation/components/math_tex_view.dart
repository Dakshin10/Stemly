import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../theme/app_typography.dart';

/// Renders mathematical LaTeX expressions cleanly with horizontal scrolling and accessible fallback.
class MathTexView extends StatelessWidget {
  final String formula;
  final TextStyle? textStyle;
  final String? semanticLabel;

  const MathTexView({
    super.key,
    required this.formula,
    this.textStyle,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cleanFormula = formula.trim();
    if (cleanFormula.isEmpty) {
      return const SizedBox.shrink();
    }

    final effectiveStyle = textStyle ?? AppTypography.body(context);
    final fallbackString = _buildReadableFallback(cleanFormula);
    final accessibleLabel = semanticLabel ?? fallbackString;

    return Semantics(
      label: accessibleLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Math.tex(
          cleanFormula,
          textStyle: effectiveStyle,
          onErrorFallback: (err) {
            // Safe readable Unicode fallback instead of raw code or crash
            return Text(
              fallbackString,
              style: effectiveStyle.copyWith(fontFamily: 'monospace'),
            );
          },
        ),
      ),
    );
  }

  /// Converts common LaTeX tokens into readable Unicode text for accessibility and fallback.
  static String _buildReadableFallback(String tex) {
    return tex
        .replaceAll(r'\frac', '')
        .replaceAll(r'\sin', 'sin')
        .replaceAll(r'\cos', 'cos')
        .replaceAll(r'\tan', 'tan')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\quad', ' ')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\le', '≤')
        .replaceAll(r'\ge', '≥')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\sqrt', '√')
        .replaceAll(r'\Delta', 'Δ')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('^2', '²')
        .replaceAll('^3', '³')
        .replaceAll(r'\', '')
        .trim();
  }
}
