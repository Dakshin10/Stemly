import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'visualiser_models.dart';

// Components
import 'atom_component.dart';
import 'declarative_physics_component.dart';
import 'free_fall_component.dart';
import 'graph_component.dart';
import 'kinematics_component.dart';
import 'optics_component.dart';
import 'projectile_motion.dart';
import 'shm_component.dart';
import 'equation_plotter.dart';
import 'generic_diagram.dart';
import 'phet_visualiser_widget.dart';
import 'sandbox_visualiser_widget.dart';

class VisualiserFactory {
  /// Creates the appropriate visualiser widget based on the template ID.
  static Widget create(
    VisualTemplate template, {
    Function(Map<String, String>)? onSimulationUpdate,
  }) {
    final id = (template.templateId).toLowerCase().replaceAll("-", "_");
    final p = template.parameters;

    // Helper to safely get values
    double getVal(String key) {
      if (p.containsKey(key)) return p[key]!.value;
      return 0.0;
    }

    if (id.contains("projectile")) {
      return ProjectileMotionWidget(
        U: getVal("U"),
        theta: getVal("theta"),
        g: getVal("g"),
        onSimulationUpdate: onSimulationUpdate,
      );
    }

    if (id.contains("freefall") || id.contains("fall") || id.contains("free")) {
      return FreeFallWidget(h: getVal("h"), g: getVal("g"));
    }

    if (id.contains("shm") || id.contains("harmonic")) {
      return SHMWidget(A: getVal("A"), m: getVal("m"), k: getVal("k"));
    }

    if (id.contains("atom") || id.contains("chemistry")) {
      return AtomWidget(
        protons: getVal("protons"),
        neutrons: getVal("neutrons"),
      );
    }

    if (id.contains("math") ||
        id.contains("graph") ||
        id.contains("quadratic")) {
      return GraphWidget(a: getVal("a"), b: getVal("b"), c: getVal("c"));
    }

    if (id.contains("kinematics")) {
      return KinematicsWidget(
        u: getVal("u"),
        a: getVal("a"),
        tMax: getVal("t_max"),
      );
    }

    if (id.contains("optics") || id.contains("lens")) {
      return OpticsWidget(f: getVal("f"), u: getVal("u"), ho: getVal("h_o"));
    }

    // Declarative 2D Physics Engine (Inclined Plane, Pulley, Collisions, Forces)
    if (id.contains("incline") ||
        id.contains("ramp") ||
        id.contains("pulley") ||
        id.contains("atwood") ||
        id.contains("collision") ||
        id.contains("momentum") ||
        id.contains("mechanics") ||
        id.contains("declarative")) {
      final paramMap = <String, double>{};
      p.forEach((k, v) => paramMap[k] = v.value);
      return DeclarativePhysicsWidget(
        scenario: id,
        parameters: paramMap,
        onSimulationUpdate: onSimulationUpdate,
      );
    }

    // Dynamic Equation Plotter
    if (id.contains("plot") || id.contains("equation")) {
      String equation = "x^2"; // Default

      if (template.metadata.containsKey("equation")) {
        equation = template.metadata["equation"].toString();
      }

      return EquationPlotterWidget(
        equation: equation,
        minX: getVal("min_x") == 0 ? -10 : getVal("min_x"),
        maxX: getVal("max_x") == 0 ? 10 : getVal("max_x"),
        minY: getVal("min_y") == 0 ? -10 : getVal("min_y"),
        maxY: getVal("max_y") == 0 ? 10 : getVal("max_y"),
      );
    }

    // Generic Diagram
    if (id.contains("diagram")) {
      List<Map<String, dynamic>> primitives = [];
      if (template.metadata.containsKey("primitives") &&
          template.metadata["primitives"] is List) {
        primitives = List<Map<String, dynamic>>.from(
          template.metadata["primitives"],
        );
      }
      return GenericDiagramWidget(primitives: primitives);
    }

    // PhET Simulations
    if (id == "phet-webview" ||
        (template.metadata.containsKey("type") &&
            template.metadata["type"] == "phet")) {
      final url = template.metadata["url"]?.toString() ?? "";
      final title = template.metadata["title"]?.toString() ?? "Simulation";
      if (url.isNotEmpty) {
        return PhetVisualiserWidget(url: url, title: title);
      }
    }

    // AI Micro-Simulation Sandbox
    if (id.contains("sandbox") ||
        id.contains("ai_canvas") ||
        id.contains("micro_simulation") ||
        (template.metadata.containsKey("type") &&
            template.metadata["type"] == "sandbox") ||
        (template.metadata.containsKey("html") &&
            template.metadata["html"].toString().isNotEmpty)) {
      final html = template.metadata["html"]?.toString() ?? "";
      final title = template.title.isNotEmpty
          ? template.title
          : "Micro-Simulation";
      if (html.isNotEmpty) {
        return SandboxVisualiserWidget(htmlContent: html, title: title);
      }
    }

    // Default Fallback
    return Builder(
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                size: 40,
                color: AppColors.textSecondary(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Interactive simulation unavailable for this topic",
                style: AppTypography.subhead(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
