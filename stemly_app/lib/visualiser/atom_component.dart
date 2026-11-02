// lib/visualiser/atom_component.dart
import 'dart:math';
import 'package:flutter/material.dart';

class AtomWidget extends StatefulWidget {
  final double protons;
  final double neutrons;

  const AtomWidget({
    super.key,
    required this.protons,
    required this.neutrons,
  });

  @override
  State<AtomWidget> createState() => _AtomWidgetState();
}

class _AtomWidgetState extends State<AtomWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  int get _safeProtons => widget.protons.toInt().clamp(1, 118);
  int get _safeNeutrons => max(0, widget.neutrons.toInt());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: AtomPainter(
              protons: _safeProtons,
              neutrons: _safeNeutrons,
              animationValue: _controller.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class AtomPainter extends CustomPainter {
  final int protons;
  final int neutrons;
  final double animationValue;

  // Cached Paint objects to prevent allocations during 60 FPS rotation
  static final Paint _bgPaint = Paint()..color = const Color(0xFFFAFAFA);
  static final Paint _nucleusPaint = Paint()..color = const Color(0xFFE53935);
  static final Paint _shellPaint = Paint()
    ..color = const Color(0x3D9E9E9E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _electronPaint = Paint()
    ..color = const Color(0xFF1976D2)
    ..style = PaintingStyle.fill;
  static final Paint _electronGlowPaint = Paint()
    ..color = const Color(0x4D2196F3)
    ..style = PaintingStyle.fill;
  static final Paint _panelBgPaint = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..style = PaintingStyle.fill;
  static final Paint _panelBorderPaint = Paint()
    ..color = const Color(0x1F000000)
    ..style = PaintingStyle.stroke;

  static final TextPainter _cachedTextPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  static const List<String> _elementSymbols = [
    "n", "H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne",
    "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca",
    "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn",
    "Ga", "Ge", "As", "Se", "Br", "Kr", "Rb", "Sr", "Y", "Zr",
    "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn",
    "Sb", "Te", "I", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd",
    "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
    "Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg",
    "Tl", "Pb", "Bi", "Po", "At", "Rn", "Fr", "Ra", "Ac", "Th",
    "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm",
    "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds",
    "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og"
  ];

  AtomPainter({
    required this.protons,
    required this.neutrons,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    // Background element watermark
    final symbol = _getElementSymbol(protons);
    _drawText(
      canvas,
      symbol,
      24,
      16,
      size: 54,
      bold: true,
      color: const Color(0x1A000000),
    );

    // Compute shell count to determine dynamic scaling
    int remainingElectrons = protons;
    int shellCount = 0;
    while (remainingElectrons > 0) {
      shellCount++;
      final capacity = 2 * shellCount * shellCount;
      remainingElectrons -= min(remainingElectrons, capacity);
    }
    shellCount = max(1, shellCount);

    // Dynamic shell spacing to always fit canvas
    final maxRadius = min(size.width, size.height) * 0.44;
    final nucleusRadius = 14.0;
    final shellSpacing = (maxRadius - nucleusRadius - 10.0) / shellCount;

    // Draw Electron Shells & Electrons
    remainingElectrons = protons;
    int shellIndex = 1;

    while (remainingElectrons > 0) {
      final capacity = 2 * shellIndex * shellIndex;
      final electronsInShell = min(remainingElectrons, capacity);
      final radius = nucleusRadius + 10.0 + (shellIndex * shellSpacing);

      // Orbital shell track
      canvas.drawCircle(center, radius, _shellPaint);

      // Orbital rotation angle with alternating directions per shell
      final direction = (shellIndex % 2 == 0) ? -1.0 : 1.0;
      final baseSpeed = (1.0 / sqrt(shellIndex.toDouble()));
      final shellAngleOffset = direction * animationValue * 2.0 * pi * baseSpeed;

      // Draw Electrons on this shell
      for (int i = 0; i < electronsInShell; i++) {
        final angle = (2.0 * pi / electronsInShell) * i + shellAngleOffset;
        final ex = center.dx + radius * cos(angle);
        final ey = center.dy + radius * sin(angle);

        // Glow halo
        canvas.drawCircle(Offset(ex, ey), 6.5, _electronGlowPaint);
        // Electron core
        canvas.drawCircle(Offset(ex, ey), 4.0, _electronPaint);
      }

      remainingElectrons -= electronsInShell;
      shellIndex++;
    }

    // Nucleus
    canvas.drawCircle(center, nucleusRadius, _nucleusPaint);
    _drawText(
      canvas,
      '${protons}p',
      center.dx - 9,
      center.dy - 6,
      color: Colors.white,
      bold: true,
      size: 10,
    );

    // Info panel
    _drawInfoPanel(canvas, symbol, shellCount);
  }

  void _drawInfoPanel(Canvas canvas, String symbol, int shells) {
    final rect = Rect.fromLTWH(12, 12, 185, 90);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, _panelBgPaint);
    canvas.drawRRect(rrect, _panelBorderPaint);

    _drawText(canvas, 'Bohr Atom Model', 20, 20, size: 12, bold: true, color: const Color(0xFF1565C0));
    _drawText(canvas, 'Element: $symbol (Z = $protons)', 20, 38, size: 11);
    _drawText(canvas, 'Neutrons: $neutrons', 20, 54, size: 11);
    _drawText(canvas, 'Electron Shells: $shells', 20, 70, size: 11, color: Colors.grey.shade700);
  }

  String _getElementSymbol(int z) {
    if (z >= 0 && z < _elementSymbols.length) return _elementSymbols[z];
    return "?";
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double size = 11,
    bool bold = false,
    Color color = Colors.black87,
  }) {
    _cachedTextPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    _cachedTextPainter.layout();
    _cachedTextPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant AtomPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.protons != protons ||
        oldDelegate.neutrons != neutrons;
  }
}
