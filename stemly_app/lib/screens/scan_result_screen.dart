import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../models/scan_history.dart';
import '../presentation/components/components.dart';
import '../presentation/widgets/degraded_banner.dart';
import '../presentation/widgets/shimmer_skeleton.dart';
import '../presentation/widgets/state_views.dart';
import '../quiz/quiz_play_screen.dart';
import '../services/firebase_auth_service.dart';
import '../storage/history_store.dart';
import '../strings.dart';
import '../theme/theme.dart';
import '../visualiser/visualiser_factory.dart';
import '../visualiser/visualiser_models.dart';

/// HIG-compliant Scan Result Screen for STEMLY.
/// Content-first: 4:3 Hero simulation canvas at the top, accessible sliders & stat tiles,
/// rendered equations via MathTexView (zero raw LaTeX), clean AI assistant, and structured notes.
class ScanResultScreen extends StatefulWidget {
  final String topic;
  final List<String> variables;
  final Map<String, dynamic> notesJson;
  final String imagePath;
  final ScanHistory? historyItem;
  final bool isDegraded;
  final List<Map<String, dynamic>> structuredVariables;
  final String? targetQuestion;
  final String? latexFormula;

  const ScanResultScreen({
    super.key,
    required this.topic,
    required this.variables,
    required this.notesJson,
    required this.imagePath,
    this.historyItem,
    this.isDegraded = false,
    this.structuredVariables = const [],
    this.targetQuestion,
    this.latexFormula,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  final Map<String, bool> _notesExpanded = {};

  VisualTemplate? _visualiserTemplate;
  Widget? _visualiserWidget;
  bool _loadingVisualiser = true;
  String? _scanHistoryId;
  Map<String, String> _simulationStats = {};

  // Image Generation Fallback State
  String? _generatedImageUrl;
  bool _generatingImage = false;

  // AI Chat State
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  bool _isSendingChat = false;
  final ScrollController _chatScrollController = ScrollController();

  String get _serverIp => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();

    for (var key in widget.notesJson.keys) {
      _notesExpanded[key] = false;
    }

    _loadingVisualiser = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadVisualiser();
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ==========================================================
  // VISUALISER LOADER (ZERO BUILD-PHASE SETSTATE)
  // ==========================================================
  Future<void> _loadVisualiser() async {
    if (mounted) {
      setState(() => _loadingVisualiser = true);
    } else {
      _loadingVisualiser = true;
    }

    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      if (token == null) {
        if (mounted) setState(() => _loadingVisualiser = false);
        return;
      }

      final response = await http.post(
        Uri.parse("$_serverIp/visualiser/generate"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "topic": widget.topic,
          "variables": widget.variables,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Visualiser API Error: ${response.statusCode}");
        if (mounted) setState(() => _loadingVisualiser = false);
        return;
      }

      final data = jsonDecode(response.body);
      final templateJson = data["template"];
      if (data.containsKey("history_id")) {
        templateJson["history_id"] = data["history_id"];
        _scanHistoryId = data["history_id"];
      }

      final template = VisualTemplate.fromJson(templateJson);

      if (template.historyId != null && widget.historyItem != null) {
        widget.historyItem!.visualiserHistoryId = template.historyId;
        HistoryStore.update();
      }

      if (mounted) {
        setState(() {
          _visualiserTemplate = template;
          _visualiserWidget = VisualiserFactory.create(
            template,
            onSimulationUpdate: (stats) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _simulationStats = stats);
              });
            },
          );
          _loadingVisualiser = false;
        });
      }
    } catch (e) {
      debugPrint("Visualiser error: $e");
      if (mounted) setState(() => _loadingVisualiser = false);
    }
  }

  void _updateWidgetFromTemplate() {
    if (_visualiserTemplate == null) return;
    setState(() {
      _visualiserWidget = VisualiserFactory.create(
        _visualiserTemplate!,
        onSimulationUpdate: (stats) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _simulationStats = stats);
          });
        },
      );
    });
  }

  Future<void> _generateImage() async {
    setState(() => _generatingImage = true);
    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse("$_serverIp/visualiser/generate-image"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"prompt": "${widget.topic} ${widget.variables.join(' ')}"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _generatedImageUrl = data["image_url"]);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate image")),
        );
      }
    } catch (e) {
      debugPrint("Image gen error: $e");
    } finally {
      if (mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _sendChatMessage(String userText) async {
    final text = userText.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({"text": text, "isUser": true});
      _isSendingChat = true;
      _chatController.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      if (_visualiserTemplate == null) {
        setState(() {
          _chatMessages.add({"text": "No active simulation to control.", "isUser": false});
          _isSendingChat = false;
        });
        return;
      }

      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      final params = <String, dynamic>{};
      _visualiserTemplate!.parameters.forEach((k, v) => params[k] = v.value);

      final response = await http.post(
        Uri.parse("$_serverIp/visualiser/update"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "template_id": _visualiserTemplate!.templateId,
          "parameters": params,
          "user_prompt": text,
          "history_id": _scanHistoryId,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result.containsKey("ai_response")) {
          setState(() {
            _chatMessages.add({"text": result["ai_response"], "isUser": false});
          });
        }

        if (result.containsKey("parameters")) {
          final newParams = result["parameters"] as Map<String, dynamic>;
          bool changed = false;
          _visualiserTemplate!.parameters.forEach((key, param) {
            if (newParams.containsKey(key)) {
              param.value = (newParams[key] as num).toDouble();
              changed = true;
            }
          });
          if (changed) {
            _updateWidgetFromTemplate();
          }
        }
      } else {
        setState(() => _chatMessages.add({"text": "Failed to update parameters.", "isUser": false}));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add({"text": "Error: ${e.toString()}", "isUser": false});
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingChat = false);
      }
    }
  }

  // ==========================================================
  // ROOT BUILD WITH HIG TAB BAR
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final surface = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);

    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Visualiser tab hero by default
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: AppStrings.back,
          ),
          title: Text(
            widget.topic,
            style: AppTypography.headline(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(AppRadii.capsule),
              ),
              child: TabBar(
                splashBorderRadius: BorderRadius.circular(AppRadii.capsule),
                splashFactory: InkSparkle.splashFactory,
                indicatorAnimation: TabIndicatorAnimation.elastic,
                overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return AppColors.accentFill(context).withValues(alpha: 0.14);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return AppColors.accentFill(context).withValues(alpha: 0.06);
                  }
                  return Colors.transparent;
                }),
                indicator: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(AppRadii.capsule),
                  border: Border.all(
                    color: AppColors.accentFill(context).withValues(alpha: 0.22),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentFill(context).withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: textPrimary,
                unselectedLabelColor: AppColors.textSecondary(context),
                labelStyle: AppTypography.caption(context).copyWith(fontWeight: FontWeight.bold),
                unselectedLabelStyle: AppTypography.caption(context),
                padding: const EdgeInsets.all(3),
                tabs: const [
                  Tab(
                    text: AppStrings.tabNotes,
                    icon: Icon(Icons.description_outlined, size: 18),
                  ),
                  Tab(
                    text: AppStrings.tabVisualiser,
                    icon: Icon(Icons.play_circle_outline_rounded, size: 18),
                  ),
                  Tab(
                    text: AppStrings.tabQuiz,
                    icon: Icon(Icons.quiz_outlined, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // Simulations capture drag gestures
          children: [
            _buildNotesTab(context),
            _buildVisualiserTab(context),
            _buildQuizSetupTab(context),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TAB 1: NOTES TAB (WITH MATH RENDERER & ACCORDIONS)
  // ==========================================================
  Widget _buildNotesTab(BuildContext context) {
    if (widget.notesJson.containsKey("error")) {
      return ErrorStateView(
        title: "Notes Generation Failed",
        message: widget.notesJson["error"]?.toString() ?? "Could not synthesize notes for this topic.",
      );
    }

    if (widget.notesJson.isEmpty) {
      return const EmptyStateView(
        icon: Icons.notes_rounded,
        title: "No Notes Available",
        message: "Notes could not be synthesized for this topic.",
      );
    }

    final bool isDegraded = widget.isDegraded || (widget.notesJson["degraded"] == true);
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final objectiveCard = _buildProblemObjectiveCard(context);
    final bool hasObjective = objectiveCard is! SizedBox;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Problem Objective & Equation Card
          if (hasObjective) ...[
            objectiveCard,
            const SizedBox(height: AppSpacing.md),
          ],

          if (isDegraded) ...[
            const DegradedModeBanner(),
            const SizedBox(height: AppSpacing.md),
          ],

          // Notes Accordions
          ...widget.notesJson.entries.where((e) => e.key != 'degraded' && e.key != 'error').map((entry) {
            final key = entry.key;
            final isExpanded = _notesExpanded[key] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Material(
                color: surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: divider, width: 1.0),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: ValueKey<String>('expansion_$key'),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (val) {
                        setState(() => _notesExpanded[key] = val);
                      },
                      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      iconColor: textSecondary,
                      collapsedIconColor: textSecondary,
                      shape: const RoundedRectangleBorder(side: BorderSide.none),
                      collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface2(context),
                          borderRadius: BorderRadius.circular(AppRadii.input),
                          border: Border.all(color: divider, width: 0.5),
                        ),
                        child: Icon(
                          _sectionIcon(key),
                          size: 18,
                          color: textPrimary,
                        ),
                      ),
                      title: Text(
                        _formatKey(key),
                        style: AppTypography.headline(context),
                      ),
                      subtitle: _sectionSubtitle(context, key, entry.value),
                      children: [
                        Divider(height: 1, thickness: 0.5, color: divider),
                        const SizedBox(height: AppSpacing.md),
                        _buildNoteContent(context, key, entry.value),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  IconData _sectionIcon(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('example')) return Icons.science_outlined;
    if (lower.contains('formula') || lower.contains('equation')) return Icons.functions_rounded;
    if (lower.contains('variable') || lower.contains('breakdown')) return Icons.tune_rounded;
    if (lower.contains('mistake') || lower.contains('pitfall')) return Icons.warning_amber_rounded;
    if (lower.contains('practice') || lower.contains('question')) return Icons.help_outline_rounded;
    if (lower.contains('summary') || lower.contains('takeaway')) return Icons.checklist_rounded;
    if (lower.contains('resource') || lower.contains('reference')) return Icons.bookmark_border_rounded;
    return Icons.menu_book_rounded;
  }

  Widget? _sectionSubtitle(BuildContext context, String key, dynamic value) {
    String? label;
    final lower = key.toLowerCase();
    if (value is List) {
      label = "${value.length} items";
    } else if (lower.contains('example')) {
      label = "Step-by-step walkthrough";
    } else if (lower.contains('explanation')) {
      label = "Core conceptual guide";
    } else if (value is Map) {
      label = "${value.length} parameters";
    }
    if (label == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }

  Widget _buildNoteContent(BuildContext context, String key, dynamic value) {
    final divider = AppColors.divider(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    // 1. STRING CONTENT (Examples, explanations, prose)
    if (value is String) {
      final stepRegex = RegExp(r'(?:^|\s)(?:\((\d+)\)|(?:Step\s+(\d+)[:.]?)|(\d+)[.)])\s+');
      final matches = stepRegex.allMatches(value).toList();

      // If it contains step markers, render as a high-end stepped walkthrough
      if (matches.length >= 2 || (matches.length == 1 && key.toLowerCase().contains('example'))) {
        return _buildSteppedExample(context, value, matches);
      }

      // If multiple paragraphs, split and space nicely
      final paragraphs = value.split(RegExp(r'\n{2,}|\r\n\r\n'));
      if (paragraphs.length > 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: paragraphs.map((p) {
            final trimmed = p.trim();
            if (trimmed.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _renderMathOrText(context, trimmed),
            );
          }).toList(),
        );
      }

      return _renderMathOrText(context, value);
    }

    // 2. LIST CONTENT (Formulas, Common Mistakes, Practice Questions, Key Points)
    if (value is List) {
      final lowerKey = key.toLowerCase();

      // Dedicated Formula Cards
      if (lowerKey.contains('formula') || lowerKey.contains('equation')) {
        return Column(
          children: value.map((item) {
            final str = item.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface2(context),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.functions_rounded, size: 16, color: textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: MathTexView(
                        formula: str,
                        textStyle: AppTypography.subhead(context).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }

      // Dedicated Common Mistakes / Pitfalls Cards
      if (lowerKey.contains('mistake') || lowerKey.contains('pitfall')) {
        return Column(
          children: value.map((item) {
            final str = item.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface2(context),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: divider, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.accentText(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      str,
                      style: AppTypography.body(context).copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }

      // Dedicated Practice Questions
      if (lowerKey.contains('practice') || lowerKey.contains('question')) {
        return Column(
          children: value.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final str = entry.value.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface2(context),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: divider, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: divider, width: 0.5),
                    ),
                    child: Text(
                      "Q$idx",
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      str,
                      style: AppTypography.body(context).copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }

      // Standard Bulleted List (e.g. Summary, Resources)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.map((item) {
          final str = item.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: str.contains(r'\')
                      ? MathTexView(formula: str, textStyle: AppTypography.body(context))
                      : Text(
                          str,
                          style: AppTypography.body(context).copyWith(height: 1.45),
                        ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // 3. MAP CONTENT (Variable breakdown / Key-Value table)
    if (value is Map) {
      final entriesList = value.entries.toList();
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface2(context),
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: divider, width: 0.5),
        ),
        child: Column(
          children: entriesList.asMap().entries.map((entry) {
            final idx = entry.key;
            final e = entry.value;
            final isLast = idx == entriesList.length - 1;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Monospace / math symbol badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: divider, width: 0.5),
                        ),
                        child: Text(
                          e.key.toString(),
                          style: AppTypography.caption(context).copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Description
                      Expanded(
                        child: Text(
                          e.value.toString(),
                          style: AppTypography.body(context).copyWith(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(height: 1, thickness: 0.5, color: divider),
              ],
            );
          }).toList(),
        ),
      );
    }

    return Text(value.toString(), style: AppTypography.body(context).copyWith(height: 1.45));
  }

  Widget _renderMathOrText(BuildContext context, String text) {
    if (text.contains(r'\') || text.contains('^') || text.contains('_')) {
      return MathTexView(
        formula: text,
        textStyle: AppTypography.body(context),
      );
    }
    return Text(
      text,
      style: AppTypography.body(context).copyWith(height: 1.5),
    );
  }

  Widget _buildSteppedExample(BuildContext context, String rawText, List<RegExpMatch> matches) {
    final divider = AppColors.divider(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    String? preamble;
    if (matches.isNotEmpty && matches.first.start > 0) {
      preamble = rawText.substring(0, matches.first.start).trim();
    }

    String? conclusion;
    final List<_StepItem> steps = [];

    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      final stepNum = m.group(1) ?? m.group(2) ?? m.group(3) ?? "${i + 1}";
      final start = m.end;
      final end = (i + 1 < matches.length) ? matches[i + 1].start : rawText.length;
      String rawStepContent = rawText.substring(start, end).trim();

      if (i == matches.length - 1) {
        final conclusionMatch = RegExp(
          r'(?<=\.)\s+(Thus|Therefore|Hence|In summary|In conclusion|Result:)\s+',
          caseSensitive: false,
        ).firstMatch(rawStepContent);

        if (conclusionMatch != null) {
          conclusion = rawStepContent.substring(conclusionMatch.start).trim();
          rawStepContent = rawStepContent.substring(0, conclusionMatch.start).trim();
        }
      }

      String? title;
      String body = rawStepContent;
      final colonIdx = rawStepContent.indexOf(':');
      if (colonIdx > 0 && colonIdx < 50) {
        title = rawStepContent.substring(0, colonIdx).trim();
        body = rawStepContent.substring(colonIdx + 1).trim();
      }

      steps.add(_StepItem(number: stepNum, title: title, body: body));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preamble / Problem Scenario
        if (preamble != null && preamble.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface2(context),
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(color: divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 16, color: textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      "Problem Scenario",
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  preamble,
                  style: AppTypography.body(context).copyWith(height: 1.45, color: textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Stepped Breakdown
        ...steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          final isLast = idx == steps.length - 1 && (conclusion == null || conclusion.isEmpty);

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Number Circle Badge
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2, right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface2(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: divider, width: 1.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    step.number,
                    style: AppTypography.caption(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),

                // Step Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step.title != null && step.title!.isNotEmpty) ...[
                        Text(
                          step.title!,
                          style: AppTypography.subhead(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface2(context),
                          borderRadius: BorderRadius.circular(AppRadii.input),
                          border: Border.all(color: divider, width: 0.5),
                        ),
                        child: step.body.contains(r'\') || step.body.contains('^') || step.body.contains('_')
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: MathTexView(
                                  formula: step.body,
                                  textStyle: AppTypography.body(context),
                                ),
                              )
                            : Text(
                                step.body,
                                style: AppTypography.body(context).copyWith(height: 1.45, color: textPrimary),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        // Conclusion / Final Result
        if (conclusion != null && conclusion.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface2(context),
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(color: divider, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: AppColors.accentText(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Final Result",
                        style: AppTypography.caption(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentText(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conclusion,
                        style: AppTypography.body(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================
  // TAB 2: VISUALISER TAB (HERO 4:3 CANVAS AT VERY TOP)
  // ==========================================================
  Widget _buildVisualiserTab(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HERO: INTERACTIVE SIMULATION CANVAS (4:3 RATIO, MAX 40% HEIGHT)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: min(350.0, MediaQuery.of(context).size.height * 0.40),
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: _buildSimulationContent(context),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. TELEMETRY STAT TILES (RANGE, MAX HEIGHT, FLIGHT TIME - Whitelist #6: accentText)
          if (_simulationStats.isNotEmpty) ...[
            Row(
              children: _simulationStats.entries.take(3).map((e) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                      border: Border.all(color: divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.key,
                          style: AppTypography.footnote(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.value,
                          style: AppTypography.title2(context).copyWith(
                            color: AppColors.accentText(context),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 3. SIMULATION PARAMETERS (SLIDERS WITH MONOSPACE VALUES & RESET)
          if (_visualiserTemplate != null && _visualiserTemplate!.parameters.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, color: textPrimary, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppStrings.simulationParameters,
                            style: AppTypography.headline(context),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // Reset to defaults
                          _loadVisualiser();
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, AppSpacing.minTouchTarget),
                        ),
                        child: Text(
                          AppStrings.resetCrop,
                          style: AppTypography.footnote(context).copyWith(
                            color: AppColors.accentText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  ..._visualiserTemplate!.parameters.entries.map((e) {
                    final param = e.value;
                    final double val = param.value;
                    final double minVal = param.min;
                    final double maxVal =
                        param.max > param.min ? param.max : (val > 0 ? val * 2 : 100.0);
                    final String label = param.label.isNotEmpty ? param.label : _formatKey(e.key);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: AppTypography.subhead(context)),
                              Text(
                                "${val.toStringAsFixed(1)} ${param.unit}".trim(),
                                style: AppTypography.numeric(context, fontSize: 13),
                              ),
                            ],
                          ),
                          Slider(
                            value: val.clamp(minVal, maxVal),
                            min: minVal,
                            max: maxVal,
                            activeColor: AppColors.primary(context),
                            inactiveColor: AppColors.surface2(context),
                            onChanged: (newVal) {
                              setState(() {
                                param.value = newVal;
                                _updateWidgetFromTemplate();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 4. PROBLEM TARGET & FORMULAS CARD (WITH MATHTEXVIEW)
          _buildProblemObjectiveCard(context),

          const SizedBox(height: AppSpacing.md),

          // 5. AI ASSISTANT CARD (HIG Neutral: black/white user bubble, surface assistant bubble)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: textPrimary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.aiAssistant,
                      style: AppTypography.headline(context),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.aiAssistantPlaceholder,
                  style: AppTypography.footnote(context),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Suggestion chips (neutral surface2)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppChip(
                      label: AppStrings.chipExplainGravity,
                      onTap: () => _sendChatMessage("Explain gravity in this problem"),
                    ),
                    AppChip(
                      label: AppStrings.chipSetVelocity,
                      onTap: () => _sendChatMessage("Set velocity to 50"),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Chat Messages Container
                Container(
                  height: 180,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(AppRadii.input),
                  ),
                  child: _chatMessages.isEmpty
                      ? Center(
                          child: Text(
                            "Type a question to explore this concept.",
                            style: AppTypography.footnote(context),
                          ),
                        )
                      : ListView.builder(
                          controller: _chatScrollController,
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, idx) {
                            final msg = _chatMessages[idx];
                            final isUser = msg["isUser"] == true;
                            final isDark = AppColors.isDark(context);
                            final bubbleBg = isUser
                                ? (isDark ? Colors.white : Colors.black)
                                : surface;
                            final bubbleFg = isUser
                                ? (isDark ? Colors.black : Colors.white)
                                : textPrimary;

                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                                ),
                                decoration: BoxDecoration(
                                  color: bubbleBg,
                                  borderRadius: BorderRadius.circular(AppRadii.button),
                                  border: isUser ? null : Border.all(color: divider),
                                ),
                                child: Text(
                                  msg["text"] ?? "",
                                  style: AppTypography.subhead(context).copyWith(
                                    color: bubbleFg,
                                    fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Glass AI Composer
                GlassComposer(
                  controller: _chatController,
                  isSending: _isSendingChat,
                  onSend: () => _sendChatMessage(_chatController.text),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSimulationContent(BuildContext context) {
    if (_loadingVisualiser) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary(context),
              strokeWidth: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Preparing interactive simulation...",
              style: AppTypography.subhead(context),
            ),
          ],
        ),
      );
    }

    if (_visualiserWidget != null) {
      return _visualiserWidget!;
    }

    // Fallback if no simulation available
    if (_generatedImageUrl != null) {
      return Image.network(
        _generatedImageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textSecondary(context)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Could not load diagram",
                style: AppTypography.subhead(context),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 48, color: AppColors.textSecondary(context)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Interactive simulation unavailable for this topic.",
              style: AppTypography.subhead(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_generatingImage)
              const CircularProgressIndicator(strokeWidth: 2.5)
            else
              SecondaryButton(
                label: "Generate diagram",
                icon: const Icon(Icons.auto_awesome, size: 18),
                onPressed: _generateImage,
                width: 200,
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PROBLEM OBJECTIVE & FORMULAS (ZERO EMOJIS, WITH MATHTEXVIEW)
  // ==========================================================
  Widget _buildProblemObjectiveCard(BuildContext context) {
    final target = widget.targetQuestion ?? widget.historyItem?.targetQuestion;
    final formula = widget.latexFormula ?? widget.historyItem?.latexFormula;
    final structured = widget.structuredVariables.isNotEmpty
        ? widget.structuredVariables
        : (widget.historyItem?.structuredVariables ?? []);

    if (target == null && formula == null && structured.isEmpty && widget.variables.isEmpty) {
      return const SizedBox.shrink();
    }

    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);
    final textPrimary = AppColors.textPrimary(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Target Objective (Calm neutral surface2 with divider)
          if (target != null && target.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface2(context),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    color: textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.targetObjective,
                          style: AppTypography.footnote(context).copyWith(
                            color: AppColors.textSecondary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          target,
                          style: AppTypography.subhead(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Governing Formula Card with MathTexView (NO raw LaTeX!)
          if (formula != null && formula.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.functions_rounded, size: 16, color: textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.governingEquation,
                        style: AppTypography.caption(context).copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: MathTexView(
                      formula: formula,
                      textStyle: AppTypography.subhead(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Extracted Physical Variables (HIG surface2 badges, subtle border for "to find")
          if (structured.isNotEmpty) ...[
            Text(
              AppStrings.physicalVariables,
              style: AppTypography.subhead(context).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: structured.map((v) {
                final symbol = v["symbol"]?.toString() ?? "";
                final name = v["name"]?.toString() ?? symbol;
                final val = v["value"];
                final unit = v["unit"]?.toString() ?? "";
                final isTarget = v["is_target"] == true;

                final displayVal = val != null ? "$val $unit".trim() : AppStrings.toFind;
                final label = symbol.isNotEmpty && symbol != name
                    ? "$symbol ($name): $displayVal"
                    : "$name: $displayVal";

                return AppChip(
                  label: label,
                  isToFind: isTarget,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // TAB 3: QUIZ SETUP TAB
  // ==========================================================
  double _quizQuestionCount = 5;
  int _selectedDifficulty = 1; // 0: Easy, 1: Medium, 2: Hard

  Widget _buildQuizSetupTab(BuildContext context) {
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);
    final textPrimary = AppColors.textPrimary(context);

    return StatefulBuilder(
      builder: (context, setQuizState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // Header Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: divider),
                ),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: AppColors.primary(context)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "${AppStrings.quizSetupHeader}${widget.topic}",
                      style: AppTypography.title2(context).copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.quizDisclaimer,
                      style: AppTypography.caption(context),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Settings Section
              GroupedSection(
                title: "Quiz configuration",
                children: [
                  GroupedRow(
                    leading: Icon(Icons.format_list_numbered_rounded, color: textPrimary, size: 22),
                    title: AppStrings.questionCount,
                    trailing: Text(
                      "${_quizQuestionCount.toInt()}",
                      style: AppTypography.headline(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    child: Slider(
                      min: 3,
                      max: 10,
                      divisions: 7,
                      value: _quizQuestionCount,
                      activeColor: AppColors.primary(context),
                      inactiveColor: AppColors.surface2(context),
                      onChanged: (v) => setQuizState(() => _quizQuestionCount = v),
                    ),
                  ),
                  GroupedRow(
                    leading: Icon(Icons.speed_rounded, color: textPrimary, size: 22),
                    title: AppStrings.difficulty,
                    trailing: AppSegmentedControl<int>(
                      children: const {
                        0: AppStrings.difficultyEasy,
                        1: AppStrings.difficultyMedium,
                        2: AppStrings.difficultyHard,
                      },
                      groupValue: _selectedDifficulty,
                      onValueChanged: (val) => setQuizState(() => _selectedDifficulty = val),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Generate Quiz Button
              PrimaryButton(
                label: AppStrings.generateQuiz,
                icon: const Icon(Icons.auto_awesome, size: 20),
                onPressed: () => _startQuiz(_quizQuestionCount.toInt()),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startQuiz(int count) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: const QuizSkeleton(),
      ),
    );

    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      if (token == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showQuizError("Authentication required. Please sign in again.");
        return;
      }

      final response = await http.get(
        Uri.parse("$_serverIp/quiz/generate?topic=${widget.topic}&count=$count"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 45));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode != 200) {
        _showQuizError("Quiz generation failed (status ${response.statusCode}).");
        return;
      }

      final data = jsonDecode(response.body);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuizPlayScreen(quizData: data)),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showQuizError("Unable to connect to server: $e");
    }
  }

  void _showQuizError(String message) {
    if (!mounted) return;
    AppDialogs.confirm(
      context: context,
      title: "Quiz Error",
      message: message,
      confirmLabel: AppStrings.ok,
    );
  }

  String _formatKey(String raw) {
    if (raw.isEmpty) return "";
    return raw
        .replaceAll("_", " ")
        .trim()
        .replaceFirst(raw[0], raw[0].toUpperCase());
  }
}

class _StepItem {
  final String number;
  final String? title;
  final String body;

  const _StepItem({
    required this.number,
    this.title,
    required this.body,
  });
}

