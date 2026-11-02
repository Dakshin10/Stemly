// test/visualiser_templates_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stemly_app/visualiser/projectile_motion.dart';
import 'package:stemly_app/visualiser/optics_component.dart';
import 'package:stemly_app/visualiser/shm_component.dart';
import 'package:stemly_app/visualiser/kinematics_component.dart';
import 'package:stemly_app/visualiser/free_fall_component.dart';
import 'package:stemly_app/visualiser/atom_component.dart';
import 'package:stemly_app/visualiser/graph_component.dart';
import 'package:stemly_app/visualiser/equation_plotter.dart';
import 'package:stemly_app/visualiser/phet_visualiser_widget.dart';
import 'package:stemly_app/visualiser/visualiser_factory.dart';
import 'package:stemly_app/visualiser/visualiser_models.dart';

Widget _wrap(Widget child, {Size size = const Size(800, 600)}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: RepaintBoundary(child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('Projectile Motion Template Tests', () {
    testWidgets('renders standard trajectory (U=20, theta=45, g=9.8)', (tester) async {
      await tester.pumpWidget(_wrap(
        const ProjectileMotionWidget(U: 20, theta: 45, g: 9.8),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProjectileMotionWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('handles edge case: launch angle 0 deg (flat horizontal)', (tester) async {
      await tester.pumpWidget(_wrap(
        const ProjectileMotionWidget(U: 25, theta: 0, g: 9.8),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProjectileMotionWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles edge case: launch angle 90 deg (pure vertical)', (tester) async {
      await tester.pumpWidget(_wrap(
        const ProjectileMotionWidget(U: 25, theta: 90, g: 9.8),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProjectileMotionWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles boundary safety: zero velocity and zero gravity', (tester) async {
      await tester.pumpWidget(_wrap(
        const ProjectileMotionWidget(U: 0, theta: 45, g: 0),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProjectileMotionWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Optics Thin Lens Template Tests', () {
    testWidgets('renders real inverted image when u > 2f (u=30, f=10)', (tester) async {
      await tester.pumpWidget(_wrap(
        const OpticsWidget(f: 10, u: 30, ho: 5),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OpticsWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles critical edge case: object at focus f=u (parallel rays to infinity)', (tester) async {
      await tester.pumpWidget(_wrap(
        const OpticsWidget(f: 10, u: 10, ho: 5),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OpticsWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders virtual upright magnified image when u < f (u=5, f=10)', (tester) async {
      await tester.pumpWidget(_wrap(
        const OpticsWidget(f: 10, u: 5, ho: 5),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OpticsWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SHM Oscillator Template Tests', () {
    testWidgets('renders harmonic oscillator (A=2, m=1, k=10)', (tester) async {
      await tester.pumpWidget(_wrap(
        const SHMWidget(A: 2, m: 1, k: 10),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SHMWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles edge cases: zero mass and zero spring constant safely', (tester) async {
      await tester.pumpWidget(_wrap(
        const SHMWidget(A: 2, m: 0, k: 0),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SHMWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Kinematics 1D Motion Template Tests', () {
    testWidgets('renders accelerating motion (u=0, a=5, tMax=10)', (tester) async {
      await tester.pumpWidget(_wrap(
        const KinematicsWidget(u: 0, a: 5, tMax: 10),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KinematicsWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders turning point deceleration (u=20, a=-4, tMax=10)', (tester) async {
      await tester.pumpWidget(_wrap(
        const KinematicsWidget(u: 20, a: -4, tMax: 10),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KinematicsWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Free Fall Template Tests', () {
    testWidgets('renders free fall under gravity (h=50, g=9.8)', (tester) async {
      await tester.pumpWidget(_wrap(
        const FreeFallWidget(h: 50, g: 9.8),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FreeFallWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles boundary safety: zero height and zero gravity', (tester) async {
      await tester.pumpWidget(_wrap(
        const FreeFallWidget(h: 0, g: 0),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FreeFallWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Bohr Atom Model Template Tests', () {
    testWidgets('renders Hydrogen (Z=1, N=0)', (tester) async {
      await tester.pumpWidget(_wrap(
        const AtomWidget(protons: 1, neutrons: 0),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AtomWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Carbon (Z=6, N=6)', (tester) async {
      await tester.pumpWidget(_wrap(
        const AtomWidget(protons: 6, neutrons: 6),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AtomWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Calcium multi-shell (Z=20, N=20)', (tester) async {
      await tester.pumpWidget(_wrap(
        const AtomWidget(protons: 20, neutrons: 20),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AtomWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Quadratic Graph Template Tests', () {
    testWidgets('renders parabola y = x^2 - 4', (tester) async {
      await tester.pumpWidget(_wrap(
        const GraphWidget(a: 1, b: 0, c: -4),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GraphWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Equation Plotter AST & Discontinuity Tests', () {
    testWidgets('plots standard polynomial function x^2', (tester) async {
      await tester.pumpWidget(_wrap(
        const EquationPlotterWidget(equation: "x^2", minX: -10, maxX: 10, minY: -5, maxY: 25),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EquationPlotterWidget), findsOneWidget);
      expect(find.textContaining("Invalid"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles asymptote discontinuity: 1/x without crashing', (tester) async {
      await tester.pumpWidget(_wrap(
        const EquationPlotterWidget(equation: "1/x", minX: -5, maxX: 5, minY: -10, maxY: 10),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EquationPlotterWidget), findsOneWidget);
      expect(find.textContaining("Invalid"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles domain errors: sqrt(x) over negative x domain safely', (tester) async {
      await tester.pumpWidget(_wrap(
        const EquationPlotterWidget(equation: "sqrt(x)", minX: -5, maxX: 10, minY: 0, maxY: 5),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EquationPlotterWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays error widget on invalid mathematical syntax', (tester) async {
      await tester.pumpWidget(_wrap(
        const EquationPlotterWidget(equation: "x ++ * 2"),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining("Syntax error"), findsOneWidget);
    });
  });

  group('PhET Visualiser Security Restrictions Tests', () {
    testWidgets('allows whitelisted phet.colorado.edu simulation URLs', (tester) async {
      expect(
        PhetVisualiserWidget.isAllowedUrl(
          'https://phet.colorado.edu/sims/html/projectile-motion/latest/projectile-motion_en.html',
        ),
        isTrue,
      );
    });

    testWidgets('blocks non-phet domains and insecure schemes', (tester) async {
      expect(PhetVisualiserWidget.isAllowedUrl('http://phet.colorado.edu/sims/html/test.html'), isFalse);
      expect(PhetVisualiserWidget.isAllowedUrl('https://malicious-site.com/exploit.html'), isFalse);
      expect(PhetVisualiserWidget.isAllowedUrl('https://phet.colorado.edu.attacker.com/sims/html/test.html'), isFalse);
    });

    testWidgets('renders security block message for restricted external URLs', (tester) async {
      await tester.pumpWidget(_wrap(
        const PhetVisualiserWidget(url: 'https://evil.com/sim', title: 'Exploit'),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Restricted External Content"), findsOneWidget);
      expect(find.textContaining("Only simulations hosted on phet.colorado.edu are allowed"), findsOneWidget);
    });
  });

  group('VisualiserFactory Template Resolution Tests', () {
    testWidgets('creates ProjectileMotionWidget for projectile template', (tester) async {
      final template = VisualTemplate(
        templateId: 'projectile_motion',
        title: 'Projectile',
        animationType: 'physics_2d',
        description: 'Test',
        parameters: {
          'U': TemplateParameter(name: 'U', label: 'U', value: 20, min: 0, max: 100, unit: 'm/s'),
          'theta': TemplateParameter(name: 'theta', label: 'theta', value: 45, min: 0, max: 90, unit: 'deg'),
          'g': TemplateParameter(name: 'g', label: 'g', value: 9.8, min: 0.1, max: 20, unit: 'm/s²'),
        },
      );

      final widget = VisualiserFactory.create(template);
      await tester.pumpWidget(_wrap(widget));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProjectileMotionWidget), findsOneWidget);
    });

    testWidgets('creates OpticsWidget for optics template', (tester) async {
      final template = VisualTemplate(
        templateId: 'optics_lens',
        title: 'Optics',
        animationType: 'optics',
        description: 'Test',
        parameters: {
          'f': TemplateParameter(name: 'f', label: 'f', value: 10, min: 1, max: 50, unit: 'cm'),
          'u': TemplateParameter(name: 'u', label: 'u', value: 20, min: 1, max: 100, unit: 'cm'),
          'h_o': TemplateParameter(name: 'h_o', label: 'h_o', value: 5, min: 1, max: 20, unit: 'cm'),
        },
      );

      final widget = VisualiserFactory.create(template);
      await tester.pumpWidget(_wrap(widget));
      await tester.pumpAndSettle();

      expect(find.byType(OpticsWidget), findsOneWidget);
    });
  });
}
