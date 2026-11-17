// lib/visualiser/equation_plotter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:function_tree/function_tree.dart';

class EquationPlotterWidget extends StatefulWidget {
  final String equation;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color plotColor;

  const EquationPlotterWidget({
    super.key,
    required this.equation,
    this.minX = -10,
    this.maxX = 10,
    this.minY = -10,
    this.maxY = 10,
    this.plotColor = const Color(0xFF1976D2),
  });

  @override
  State<EquationPlotterWidget> createState() => _EquationPlotterWidgetState();
}

class _EquationPlotterWidgetState extends State<EquationPlotterWidget> {
  List<List<FlSpot>> _segments = [];
  bool _hasError = false;
  String _errorMessage = "";

  double get _safeMinX =>
      widget.minX < widget.maxX ? widget.minX : widget.maxX - 1.0;
  double get _safeMaxX =>
      widget.maxX > widget.minX ? widget.maxX : widget.minX + 1.0;
  double get _safeMinY =>
      widget.minY < widget.maxY ? widget.minY : widget.maxY - 1.0;
  double get _safeMaxY =>
      widget.maxY > widget.minY ? widget.maxY : widget.minY + 1.0;

  @override
  void initState() {
    super.initState();
    _calculateSegments();
  }

  @override
  void didUpdateWidget(covariant EquationPlotterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.equation != widget.equation ||
        oldWidget.minX != widget.minX ||
        oldWidget.maxX != widget.maxX ||
        oldWidget.minY != widget.minY ||
        oldWidget.maxY != widget.maxY) {
      _calculateSegments();
    }
  }

  void _calculateSegments() {
    _segments = [];
    _hasError = false;
    _errorMessage = "";

    final rawEq = widget.equation.trim();
    if (rawEq.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = "Empty equation";
      });
      return;
    }

    // Clean common shorthand: "y = x^2" -> "x^2", "f(x) = sin(x)" -> "sin(x)"
    String cleanEq = rawEq;
    if (cleanEq.contains('=')) {
      cleanEq = cleanEq.split('=').last.trim();
    }

    // Parse expression AST once outside evaluation loop (never eval)
    num Function(num) f;
    try {
      final parsedFn = cleanEq.toSingleVariableFunction('x');
      f = parsedFn.call;
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = "Syntax error in expression: $cleanEq";
      });
      return;
    }

    final minX = _safeMinX;
    final maxX = _safeMaxX;
    final minY = _safeMinY;
    final maxY = _safeMaxY;
    final yRange = maxY - minY;

    // Discontinuity threshold: steep sign-flip jumping across asymptote
    final discontinuityThreshold = max(10.0, yRange * 0.45);

    const int totalSteps = 200; // High resolution sampling
    final step = (maxX - minX) / totalSteps;

    List<FlSpot> currentSegment = [];
    double? lastY;

    for (int i = 0; i <= totalSteps; i++) {
      final x = minX + i * step;

      num rawY;
      try {
        rawY = f(x);
      } catch (_) {
        // Domain error (e.g. sqrt(-1), ln(0)) -> break continuous segment
        if (currentSegment.isNotEmpty) {
          _segments.add(currentSegment);
          currentSegment = [];
        }
        lastY = null;
        continue;
      }

      final y = rawY.toDouble();

      // Check for undefined, NaN, or infinite values
      if (!y.isFinite || y.isNaN) {
        if (currentSegment.isNotEmpty) {
          _segments.add(currentSegment);
          currentSegment = [];
        }
        lastY = null;
        continue;
      }

      // Detect asymptote discontinuity (e.g., 1/x or tan(x) flipping from +100 to -100)
      if (lastY != null) {
        final deltaY = (y - lastY).abs();
        final signFlip = (y * lastY) < 0;
        if (deltaY > discontinuityThreshold && signFlip) {
          if (currentSegment.isNotEmpty) {
            _segments.add(currentSegment);
            currentSegment = [];
          }
          lastY = null;
          continue;
        }
      }

      // Viewport bounds clipping
      if (y >= (minY - yRange * 0.2) && y <= (maxY + yRange * 0.2)) {
        currentSegment.add(FlSpot(x, y.clamp(minY - 2.0, maxY + 2.0)));
        lastY = y;
      } else {
        // Out of viewport range -> break segment so it doesn't draw a cross-canvas line
        if (currentSegment.isNotEmpty) {
          _segments.add(currentSegment);
          currentSegment = [];
        }
        lastY = null;
      }
    }

    if (currentSegment.isNotEmpty) {
      _segments.add(currentSegment);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 36,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final barDataList = _segments.map((segment) {
      return LineChartBarData(
        spots: segment,
        isCurved:
            false, // Straight segments prevent cubic-spline overshoot across sharp derivatives
        color: widget.plotColor,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: widget.plotColor.withValues(alpha: 0.12),
        ),
      );
    }).toList();

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1.45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.22),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.22),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      );
                    },
                    interval: max(1.0, (_safeMaxX - _safeMinX) / 5.0),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      );
                    },
                    interval: max(1.0, (_safeMaxY - _safeMinY) / 5.0),
                    reservedSize: 32,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
              ),
              minX: _safeMinX,
              maxX: _safeMaxX,
              minY: _safeMinY,
              maxY: _safeMaxY,
              lineBarsData: barDataList,
            ),
          ),
        ),
      ),
    );
  }
}
